#!/bin/bash

# setup-signing.sh
# Helper script for setting up macOS code signing and notarization
# for Transcriber project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "🔐 Transcriber Code Signing Setup"
echo "================================="
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
        echo "   You can manually edit it or delete it and run this script again"
        exit 0
    fi
fi

echo "🔍 Checking for Developer ID certificates..."
echo ""

# List available code signing identities
AVAILABLE_CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID" || true)

if [ -z "$AVAILABLE_CERTS" ]; then
    echo "❌ No Developer ID certificates found in keychain"
    echo ""
    echo "📋 To obtain Developer ID certificates:"
    echo "1. Join the Apple Developer Program (\$99/year)"
    echo "2. Go to https://developer.apple.com/account/resources/certificates"
    echo "3. Create 'Developer ID Application' certificate"
    echo "4. Create 'Developer ID Installer' certificate" 
    echo "5. Download and install both certificates in Keychain Access"
    echo ""
    echo "⚠️  Cannot continue without certificates"
    exit 1
fi

echo "✅ Found Developer ID certificates:"
echo "$AVAILABLE_CERTS"
echo ""

# Extract certificate names
APP_CERTS=$(echo "$AVAILABLE_CERTS" | grep "Developer ID Application" | sed 's/.*) "\(.*\)"/\1/' || true)
INSTALLER_CERTS=$(echo "$AVAILABLE_CERTS" | grep "Developer ID Installer" | sed 's/.*) "\(.*\)"/\1/' || true)

# Select Application certificate
if [ -z "$APP_CERTS" ]; then
    echo "❌ No Developer ID Application certificates found"
    echo "   You need this certificate to sign app binaries"
    exit 1
fi

echo "📱 Select Developer ID Application certificate:"
APP_CERT_ARRAY=()
while IFS= read -r cert; do
    [ -n "$cert" ] && APP_CERT_ARRAY+=("$cert")
done <<< "$APP_CERTS"

if [ ${#APP_CERT_ARRAY[@]} -eq 1 ]; then
    SELECTED_APP_CERT="${APP_CERT_ARRAY[0]}"
    echo "   Auto-selected: $SELECTED_APP_CERT"
else
    select SELECTED_APP_CERT in "${APP_CERT_ARRAY[@]}"; do
        if [ -n "$SELECTED_APP_CERT" ]; then
            break
        fi
    done
fi

# Select Installer certificate
if [ -z "$INSTALLER_CERTS" ]; then
    echo "⚠️  No Developer ID Installer certificates found"
    echo "   You need this certificate to sign installer packages"
    echo "   Continuing without installer signing..."
    SELECTED_INSTALLER_CERT=""
else
    echo ""
    echo "📦 Select Developer ID Installer certificate:"
    INSTALLER_CERT_ARRAY=()
    while IFS= read -r cert; do
        [ -n "$cert" ] && INSTALLER_CERT_ARRAY+=("$cert")
    done <<< "$INSTALLER_CERTS"
    
    if [ ${#INSTALLER_CERT_ARRAY[@]} -eq 1 ]; then
        SELECTED_INSTALLER_CERT="${INSTALLER_CERT_ARRAY[0]}"
        echo "   Auto-selected: $SELECTED_INSTALLER_CERT"
    else
        select SELECTED_INSTALLER_CERT in "${INSTALLER_CERT_ARRAY[@]}"; do
            if [ -n "$SELECTED_INSTALLER_CERT" ]; then
                break
            fi
        done
    fi
fi

# Setup notarization
echo ""
echo "📤 Notarization Setup:"
echo "====================="
echo ""
echo "Notarization requires an Apple ID and app-specific password."
echo "This allows your packages to bypass Gatekeeper warnings."
echo ""

read -p "Do you want to set up notarization? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📧 Enter your Apple ID (used for Apple Developer account):"
    read -p "Apple ID: " APPLE_ID
    
    echo ""
    echo "🏷️  Enter your Team ID (found in Apple Developer account):"
    read -p "Team ID: " TEAM_ID
    
    echo ""
    echo "🔑 You need to create an app-specific password:"
    echo "1. Go to https://appleid.apple.com/account/manage"
    echo "2. Sign in with your Apple ID"
    echo "3. Go to 'App-Specific Passwords'"
    echo "4. Generate a new password for 'Transcriber Notarization'"
    echo ""
    read -p "Press Enter when you have your app-specific password ready..."
    
    echo ""
    PROFILE_NAME="transcriber-notarization"
    echo "🔐 Setting up keychain profile: $PROFILE_NAME"
    echo "   You will be prompted for your app-specific password..."
    
    if xcrun notarytool store-credentials "$PROFILE_NAME" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID"; then
        echo "✅ Notarization profile created successfully"
        KEYCHAIN_PROFILE="$PROFILE_NAME"
    else
        echo "❌ Failed to create notarization profile"
        echo "   Continuing without notarization..."
        KEYCHAIN_PROFILE=""
    fi
else
    echo "ℹ️  Skipping notarization setup"
    KEYCHAIN_PROFILE=""
fi

# Create .env file
echo ""
echo "📝 Creating .env file..."

cat > "$ENV_FILE" << EOF
# Transcriber Code Signing Configuration
# Generated by setup-signing.sh on $(date)

# =============================================================================
# DEVELOPER ID CERTIFICATES
# =============================================================================

# Developer ID Application Certificate (for signing app binaries)
DEVELOPER_ID_APPLICATION="$SELECTED_APP_CERT"

# Developer ID Installer Certificate (for signing .pkg packages)
EOF

if [ -n "$SELECTED_INSTALLER_CERT" ]; then
    echo "DEVELOPER_ID_INSTALLER=\"$SELECTED_INSTALLER_CERT\"" >> "$ENV_FILE"
else
    echo "# DEVELOPER_ID_INSTALLER=\"\"  # Not configured - get from Apple Developer portal" >> "$ENV_FILE"
fi

cat >> "$ENV_FILE" << EOF

# =============================================================================
# NOTARIZATION CONFIGURATION
# =============================================================================

EOF

if [ -n "$KEYCHAIN_PROFILE" ]; then
    echo "# Keychain profile for notarization" >> "$ENV_FILE"
    echo "KEYCHAIN_PROFILE=\"$KEYCHAIN_PROFILE\"" >> "$ENV_FILE"
else
    echo "# Keychain profile for notarization (not configured)" >> "$ENV_FILE"
    echo "# KEYCHAIN_PROFILE=\"\"  # Run setup-signing.sh again to configure" >> "$ENV_FILE"
fi

cat >> "$ENV_FILE" << EOF

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

# General signing identity fallback (default: "-" for ad-hoc signing)
SIGNING_IDENTITY="-"

# Skip notarization for faster development builds (default: false)
SKIP_NOTARIZATION="false"
EOF

echo "✅ Created .env file: $ENV_FILE"
echo ""

# Test configuration
echo "🧪 Testing configuration..."
echo ""

# Source the new environment file
set -a
source "$ENV_FILE"
set +a

# Run verification
if "$SCRIPT_DIR/verify-signing.sh"; then
    echo ""
    echo "🎉 Setup completed successfully!"
    echo "================================"
    echo ""
    echo "✅ Code signing is now configured for production"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Test configuration: make check-signing-environment"
    echo "2. Build signed package: make installer-production"
    echo "3. Test installation: Double-click the .pkg file"
    echo ""
    echo "📚 For more information:"
    echo "   - View .env file: cat .env"
    echo "   - Check help: make info"
    echo "   - Troubleshooting: See .env.example"
else
    echo ""
    echo "⚠️  Setup completed with warnings"
    echo "   Check the verification output above for issues"
    echo "   You may need to adjust the .env file manually"
fi