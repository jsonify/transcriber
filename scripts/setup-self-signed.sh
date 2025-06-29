#!/bin/bash

# setup-self-signed.sh
# Create and configure self-signed certificates for macOS code signing
# This provides better signing than ad-hoc but doesn't require Apple Developer account

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "🔐 Transcriber Self-Signed Certificate Setup"
echo "============================================"
echo ""
echo "This script creates self-signed certificates for code signing."
echo "Self-signed certificates provide better security than ad-hoc signing"
echo "but will still show Gatekeeper warnings (users can bypass with instructions)."
echo ""

# Check if .env file exists
if [ -f "$ENV_FILE" ]; then
    echo "📁 Found existing .env file"
    echo "   Location: $ENV_FILE"
    echo ""
    read -p "Do you want to backup and recreate it? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        echo "✅ Backed up existing .env file"
    else
        echo "ℹ️  Keeping existing .env file"
        exit 0
    fi
fi

# Certificate details
CERT_NAME="Transcriber Self-Signed"
APP_CERT_NAME="$CERT_NAME Application"
INSTALLER_CERT_NAME="$CERT_NAME Installer"

echo "🔑 Creating self-signed certificates..."
echo ""

# Check if certificates already exist
if security find-identity -v -p codesigning | grep -q "$APP_CERT_NAME"; then
    echo "📋 Certificate '$APP_CERT_NAME' already exists"
    read -p "Do you want to recreate it? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "ℹ️  Using existing certificate"
        EXISTING_CERT=true
    else
        echo "🗑️  Removing existing certificate..."
        # Find and delete existing certificate
        EXISTING_HASH=$(security find-identity -v -p codesigning | grep "$APP_CERT_NAME" | awk '{print $2}')
        if [ -n "$EXISTING_HASH" ]; then
            security delete-identity -Z "$EXISTING_HASH" -t certificate
            echo "✅ Removed existing certificate"
        fi
        EXISTING_CERT=false
    fi
else
    EXISTING_CERT=false
fi

if [ "$EXISTING_CERT" = false ]; then
    echo "🏗️  Creating self-signed application certificate..."
    
    # Create certificate configuration
    CERT_CONFIG_DIR="/tmp/transcriber-cert-$$"
    mkdir -p "$CERT_CONFIG_DIR"
    
    # Application certificate configuration
    cat > "$CERT_CONFIG_DIR/app-cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = US
stateOrProvinceName = California
localityName = San Francisco
organizationName = Transcriber Development
organizationalUnitName = Software Development
commonName = $APP_CERT_NAME
emailAddress = dev@transcriber.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
extendedKeyUsage = codeSigning

[alt_names]
DNS.1 = transcriber.local
DNS.2 = localhost
EOF

    # Generate private key and certificate
    TEMP_KEY="$CERT_CONFIG_DIR/app-key.pem"
    TEMP_CERT="$CERT_CONFIG_DIR/app-cert.pem"
    
    openssl req -x509 -newkey rsa:4096 -keyout "$TEMP_KEY" -out "$TEMP_CERT" \
        -days 365 -nodes -config "$CERT_CONFIG_DIR/app-cert.conf"
    
    # Convert to PKCS#12 format
    TEMP_P12="$CERT_CONFIG_DIR/app-cert.p12"
    openssl pkcs12 -export -out "$TEMP_P12" -inkey "$TEMP_KEY" -in "$TEMP_CERT" \
        -name "$APP_CERT_NAME" -passout pass:
    
    # Import into keychain (allow all applications to access)
    echo "🔐 Importing certificate into keychain..."
    echo "   You may be prompted to allow access - click 'Always Allow'"
    security import "$TEMP_P12" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/productsign -T /usr/bin/security
    
    # Clean up temporary files
    rm -rf "$CERT_CONFIG_DIR"
    
    echo "✅ Created application certificate: $APP_CERT_NAME"
fi

# Create installer certificate (simpler approach for self-signed)
if ! security find-identity -v -p codesigning | grep -q "$INSTALLER_CERT_NAME"; then
    echo "🏗️  Creating self-signed installer certificate..."
    
    # Use similar process for installer cert
    CERT_CONFIG_DIR="/tmp/transcriber-installer-cert-$$"
    mkdir -p "$CERT_CONFIG_DIR"
    
    cat > "$CERT_CONFIG_DIR/installer-cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = US
stateOrProvinceName = California
localityName = San Francisco
organizationName = Transcriber Development
organizationalUnitName = Software Development
commonName = $INSTALLER_CERT_NAME
emailAddress = dev@transcriber.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = codeSigning
EOF

    TEMP_KEY="$CERT_CONFIG_DIR/installer-key.pem"
    TEMP_CERT="$CERT_CONFIG_DIR/installer-cert.pem"
    
    openssl req -x509 -newkey rsa:4096 -keyout "$TEMP_KEY" -out "$TEMP_CERT" \
        -days 365 -nodes -config "$CERT_CONFIG_DIR/installer-cert.conf"
    
    TEMP_P12="$CERT_CONFIG_DIR/installer-cert.p12"
    openssl pkcs12 -export -out "$TEMP_P12" -inkey "$TEMP_KEY" -in "$TEMP_CERT" \
        -name "$INSTALLER_CERT_NAME" -passout pass:
    
    echo "🔐 Importing installer certificate into keychain..."
    echo "   You may be prompted to allow access - click 'Always Allow'"
    security import "$TEMP_P12" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/productsign -T /usr/bin/security
    
    rm -rf "$CERT_CONFIG_DIR"
    
    echo "✅ Created installer certificate: $INSTALLER_CERT_NAME"
fi

# Allow codesign to access the certificate without prompting
echo "🔓 Configuring certificate access..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1 || true

echo ""
echo "📝 Creating .env configuration file..."

# Create .env file with self-signed certificates
cat > "$ENV_FILE" << EOF
# Transcriber Self-Signed Code Signing Configuration
# Generated by setup-self-signed.sh on $(date)

# =============================================================================
# SELF-SIGNED CERTIFICATES
# =============================================================================

# Self-signed Application Certificate (for signing app binaries)
DEVELOPER_ID_APPLICATION="$APP_CERT_NAME"

# Self-signed Installer Certificate (for signing .pkg packages)
DEVELOPER_ID_INSTALLER="$INSTALLER_CERT_NAME"

# =============================================================================
# SIGNING CONFIGURATION
# =============================================================================

# General signing identity fallback
SIGNING_IDENTITY="-"

# Skip notarization (self-signed certificates cannot be notarized)
SKIP_NOTARIZATION="true"

# =============================================================================
# NOTES
# =============================================================================

# Self-signed certificates provide better security than ad-hoc signing
# but will still trigger Gatekeeper warnings on macOS.
#
# Users can bypass Gatekeeper with:
#   xattr -d com.apple.quarantine /Applications/Transcriber.app
#   OR right-click → Open → "Open" button
#
# For production distribution without warnings, you need:
#   1. Apple Developer account (\$99/year)
#   2. Developer ID certificates from Apple
#   3. Notarization through Apple
#
# To upgrade to Apple Developer certificates:
#   1. Run: scripts/setup-signing.sh
#   2. Follow the prompts to configure Apple certificates
EOF

echo "✅ Created .env file: $ENV_FILE"
echo ""

# Test the configuration
echo "🧪 Testing self-signed certificate configuration..."
echo ""

# Source the new environment file
set -a
source "$ENV_FILE"
set +a

# Verify certificates are available
APP_FOUND=false
INSTALLER_FOUND=false

if security find-identity -v -p codesigning | grep -q "$APP_CERT_NAME"; then
    echo "✅ Application certificate available"
    APP_FOUND=true
else
    echo "❌ Application certificate not found"
fi

if security find-identity -v -p codesigning | grep -q "$INSTALLER_CERT_NAME"; then
    echo "✅ Installer certificate available"
    INSTALLER_FOUND=true
else
    echo "❌ Installer certificate not found"
fi

echo ""

if [ "$APP_FOUND" = true ] && [ "$INSTALLER_FOUND" = true ]; then
    echo "🎉 Self-signed certificate setup completed successfully!"
    echo "====================================================="
    echo ""
    echo "✅ Self-signed certificates are now configured"
    echo "⚠️  Note: Apps will still show Gatekeeper warnings"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Test configuration: make check-signing-environment"
    echo "2. Build signed package: make installer-production"
    echo "3. Test installation with bypass instructions"
    echo ""
    echo "📋 Users will need to bypass Gatekeeper with:"
    echo "   xattr -d com.apple.quarantine /Applications/Transcriber.app"
    echo "   OR right-click Transcriber.app → Open → 'Open' button"
    echo ""
    echo "🔄 To upgrade to Apple Developer certificates later:"
    echo "   Run: scripts/setup-signing.sh"
else
    echo "❌ Certificate setup failed"
    echo "   Some certificates were not created successfully"
    echo "   Try running the script again or check system permissions"
    exit 1
fi