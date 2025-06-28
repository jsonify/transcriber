#!/bin/bash

# build-production.sh
# Complete production build workflow with code signing and notarization
# for Transcriber project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "🏭 Transcriber Production Build"
echo "==============================="
echo ""

# Check if we're in the right directory
if [ ! -f "$PROJECT_ROOT/Package.swift" ]; then
    echo "❌ Package.swift not found"
    echo "   Run this script from the Transcriber project root"
    exit 1
fi

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    echo "📁 Loading production configuration..."
    set -a
    source "$ENV_FILE"
    set +a
    echo "✅ Configuration loaded from .env"
else
    echo "⚠️  No .env file found"
    echo ""
    echo "🔧 Setting up code signing configuration..."
    if "$SCRIPT_DIR/setup-signing.sh"; then
        echo "✅ Code signing setup completed"
        echo ""
        # Reload the environment
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo "❌ Code signing setup failed"
        exit 1
    fi
fi

echo ""

# Verify configuration
echo "🔍 Verifying production setup..."
if "$SCRIPT_DIR/verify-signing.sh"; then
    echo "✅ Production setup verified"
else
    echo "❌ Production setup verification failed"
    echo "   Fix the issues above before continuing"
    exit 1
fi

echo ""
echo "🚀 Starting production build..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cd "$PROJECT_ROOT"
make clean

# Run tests
echo ""
echo "🧪 Running tests..."
if make test; then
    echo "✅ All tests passed"
else
    echo "❌ Tests failed"
    echo "   Fix test failures before production build"
    exit 1
fi

# Build and sign binaries
echo ""
echo "🔨 Building and signing binaries..."
if make build-release-all sign-all; then
    echo "✅ Binaries built and signed successfully"
else
    echo "❌ Binary build or signing failed"
    exit 1
fi

# Verify signed binaries
echo ""
echo "🔍 Verifying signed binaries..."
if make verify; then
    echo "✅ Binary signatures verified"
else
    echo "❌ Binary signature verification failed"
    exit 1
fi

# Test release binaries
echo ""
echo "🧪 Testing release binaries..."
if make test-release; then
    echo "✅ Release binary tests passed"
else
    echo "❌ Release binary tests failed"
    exit 1
fi

# Create installer
echo ""
echo "📦 Creating signed installer package..."
if make installer-production; then
    echo "✅ Signed installer package created successfully"
else
    echo "❌ Installer package creation failed"
    exit 1
fi

# Final verification
echo ""
echo "🔍 Final package verification..."

# Get the package path
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.1")
PKG_FILE="releases/Transcriber-${VERSION}.pkg"

if [ ! -f "$PKG_FILE" ]; then
    echo "❌ Package file not found: $PKG_FILE"
    exit 1
fi

# Check package signature
echo "🔐 Verifying package signature..."
if pkgutil --check-signature "$PKG_FILE" >/dev/null 2>&1; then
    echo "✅ Package signature valid"
    
    # Show signature details
    echo ""
    echo "📋 Package signature details:"
    pkgutil --check-signature "$PKG_FILE" | head -10
else
    echo "❌ Package signature verification failed"
    exit 1
fi

# Test Gatekeeper assessment if signed
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo ""
    echo "🛡️  Testing Gatekeeper assessment..."
    if spctl --assess --verbose=4 --type install "$PKG_FILE" 2>&1 | grep -q "accepted"; then
        echo "✅ Package passes Gatekeeper assessment"
    else
        echo "⚠️  Package may not pass Gatekeeper assessment"
        echo "   This could indicate notarization is incomplete"
    fi
fi

echo ""
echo "🎉 Production Build Complete!"
echo "============================"
echo ""
echo "📦 Package Information:"
echo "   File: $PKG_FILE"
echo "   Size: $(du -sh "$PKG_FILE" | cut -f1)"
echo "   Signature: $(pkgutil --check-signature "$PKG_FILE" | grep "Status:" | cut -d: -f2 | xargs)"

if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "   Distribution: ✅ Ready for public distribution (signed & notarized)"
    else
        echo "   Distribution: ⚠️  Signed but not notarized (limited distribution)"
    fi
else
    echo "   Distribution: ❌ Unsigned (development only)"
fi

echo ""
echo "🧪 Testing Instructions:"
echo "1. Double-click: $PKG_FILE"
echo "2. Follow installation prompts"
echo "3. Verify no Gatekeeper warnings appear"
echo "4. Test CLI: transcriber --help"
echo "5. Test App: Open Transcriber from Applications"

echo ""
echo "📤 Distribution Options:"
echo "1. Direct download: Share the .pkg file"
echo "2. GitHub release: Upload to GitHub releases"
echo "3. Website hosting: Host on your website"

if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "4. App Store: Consider Mac App Store submission"
    fi
fi

echo ""
echo "✅ Production build workflow completed successfully!"