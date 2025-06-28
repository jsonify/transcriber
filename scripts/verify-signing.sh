#!/bin/bash

# verify-signing.sh
# Verification script for macOS code signing and notarization setup
# for Transcriber project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "🔍 Transcriber Code Signing Verification"
echo "========================================"
echo ""

# Load environment variables if .env exists
if [ -f "$ENV_FILE" ]; then
    echo "📁 Loading configuration from .env file..."
    set -a
    source "$ENV_FILE"
    set +a
    echo "✅ Configuration loaded"
else
    echo "⚠️  No .env file found"
    echo "   Run: scripts/setup-signing.sh to create one"
    echo ""
fi

echo ""
echo "📋 Current Configuration:"
echo "========================"
echo "   Developer ID Application: ${DEVELOPER_ID_APPLICATION:-❌ Not set}"
echo "   Developer ID Installer: ${DEVELOPER_ID_INSTALLER:-❌ Not set}"
echo "   Keychain Profile: ${KEYCHAIN_PROFILE:-❌ Not set}"
echo "   Signing Identity: ${SIGNING_IDENTITY:-❌ Not set}"
echo "   Skip Notarization: ${SKIP_NOTARIZATION:-false}"

# Determine signing mode
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    SIGNING_MODE="production"
else
    SIGNING_MODE="development"
fi

echo "   Signing Mode: $SIGNING_MODE"
echo ""

# Check certificate availability
echo "🔐 Certificate Verification:"
echo "============================"

CERT_STATUS=0

if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "🔍 Checking Developer ID Application certificate..."
    if security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID_APPLICATION"; then
        echo "✅ Found: $DEVELOPER_ID_APPLICATION"
    else
        echo "❌ Not found in keychain: $DEVELOPER_ID_APPLICATION"
        CERT_STATUS=1
    fi
else
    echo "⚠️  Developer ID Application not configured"
    echo "   This will use ad-hoc signing (development mode)"
fi

if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "🔍 Checking Developer ID Installer certificate..."
    if security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID_INSTALLER"; then
        echo "✅ Found: $DEVELOPER_ID_INSTALLER"
    else
        echo "❌ Not found in keychain: $DEVELOPER_ID_INSTALLER"
        CERT_STATUS=1
    fi
else
    echo "⚠️  Developer ID Installer not configured"
    echo "   Packages will be unsigned and blocked by Gatekeeper"
fi

echo ""

# Check notarization setup
echo "📤 Notarization Verification:"
echo "============================="

if [ -n "$KEYCHAIN_PROFILE" ]; then
    echo "🔍 Checking keychain profile: $KEYCHAIN_PROFILE"
    if xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
        echo "✅ Keychain profile is valid and accessible"
    else
        echo "❌ Keychain profile test failed"
        echo "   Profile may be invalid or credentials expired"
        CERT_STATUS=1
    fi
else
    echo "⚠️  No keychain profile configured"
    echo "   Packages will not be notarized"
    if [ "$SKIP_NOTARIZATION" = "true" ]; then
        echo "   (Notarization is explicitly disabled)"
    fi
fi

echo ""

# Check build tools
echo "🔨 Build Tools Verification:"
echo "==========================="

echo "🔍 Checking required build tools..."

# Check codesign
if command -v codesign >/dev/null 2>&1; then
    echo "✅ codesign: $(which codesign)"
else
    echo "❌ codesign not found"
    CERT_STATUS=1
fi

# Check productsign
if command -v productsign >/dev/null 2>&1; then
    echo "✅ productsign: $(which productsign)"
else
    echo "❌ productsign not found"
    CERT_STATUS=1
fi

# Check notarytool
if command -v xcrun >/dev/null 2>&1 && xcrun notarytool --help >/dev/null 2>&1; then
    echo "✅ notarytool: Available via xcrun"
else
    echo "❌ notarytool not available"
    echo "   Make sure Xcode Command Line Tools are installed"
    CERT_STATUS=1
fi

# Check swift build
if command -v swift >/dev/null 2>&1; then
    echo "✅ swift: $(swift --version | head -1)"
else
    echo "❌ swift compiler not found"
    CERT_STATUS=1
fi

echo ""

# Test build capability
echo "🏗️  Build System Test:"
echo "======================"

echo "🔍 Testing Makefile targets..."

# Check if we can run make targets
if make -n check-signing-environment >/dev/null 2>&1; then
    echo "✅ Makefile signing targets available"
else
    echo "❌ Makefile signing targets not found"
    echo "   You may be in the wrong directory"
    CERT_STATUS=1
fi

echo ""

# Summary and recommendations
echo "📊 Verification Summary:"
echo "======================="

if [ $CERT_STATUS -eq 0 ]; then
    if [ "$SIGNING_MODE" = "production" ]; then
        echo "✅ All checks passed - ready for production signing!"
        echo ""
        echo "🚀 Recommended next steps:"
        echo "1. Build signed package: make installer-production"
        echo "2. Test package: Double-click the .pkg file"
        echo "3. Verify no Gatekeeper warnings appear"
    else
        echo "⚠️  Development mode - basic functionality verified"
        echo ""
        echo "🔧 To enable production signing:"
        echo "1. Run: scripts/setup-signing.sh"
        echo "2. Configure Developer ID certificates"
        echo "3. Re-run this verification script"
    fi
else
    echo "❌ Some checks failed - see details above"
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "1. Install missing tools (Xcode Command Line Tools)"
    echo "2. Import Developer ID certificates into Keychain"
    echo "3. Verify certificate names match exactly"
    echo "4. Re-run: scripts/setup-signing.sh"
fi

echo ""

# Provide specific configuration guidance
if [ -n "$DEVELOPER_ID_APPLICATION" ] || [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "📖 Available Commands:"
    echo "====================="
    echo "   make check-signing-environment  - Show detailed signing config"
    echo "   make verify-certificates        - Check certificate availability"
    echo "   make installer-production       - Build signed package"
    echo "   make installer                  - Build unsigned package (development)"
    echo ""
fi

echo "📚 Documentation:"
echo "   .env.example       - Environment variable reference"
echo "   make info          - Show all available commands"

# Exit with appropriate code
exit $CERT_STATUS