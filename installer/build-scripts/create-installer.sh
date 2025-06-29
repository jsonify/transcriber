#!/bin/bash

# Create macOS Installer Package for Transcriber
# Generates a .pkg installer that can be distributed and installed on macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER_DIR="$PROJECT_ROOT/installer"

# Get version using shared version determination logic
VERSION=$("$SCRIPT_DIR/get-version.sh")

# Configuration
PRODUCT_NAME="Transcriber"
PACKAGE_ID="com.transcriber.pkg"
CLI_PACKAGE_ID="com.transcriber.cli.pkg"
APP_PACKAGE_ID="com.transcriber.app.pkg"

# Paths
BUILD_DIR="$PROJECT_ROOT/.build/release"
INSTALLER_BUILD_DIR="$INSTALLER_DIR/build"
PKG_OUTPUT_DIR="$PROJECT_ROOT/releases"
FINAL_PKG="$PKG_OUTPUT_DIR/${PRODUCT_NAME}-${VERSION}.pkg"

echo "📦 Creating macOS Installer for $PRODUCT_NAME v$VERSION"
echo "======================================================="

# Clean and create directories
echo "🧹 Preparing build environment..."
rm -rf "$INSTALLER_BUILD_DIR"
mkdir -p "$INSTALLER_BUILD_DIR"
mkdir -p "$PKG_OUTPUT_DIR"

# Build the Swift binaries if needed
echo "🔨 Building Swift binaries..."
cd "$PROJECT_ROOT"
if [ ! -f "$BUILD_DIR/transcriber" ] || [ ! -f "$BUILD_DIR/TranscriberApp" ]; then
    echo "   Building CLI and App binaries..."
    make build-release-all
    make sign-all
fi

# Verify binaries exist
if [ ! -f "$BUILD_DIR/transcriber" ]; then
    echo "❌ CLI binary not found at $BUILD_DIR/transcriber"
    exit 1
fi

if [ ! -f "$BUILD_DIR/TranscriberApp" ]; then
    echo "❌ App binary not found at $BUILD_DIR/TranscriberApp"
    exit 1
fi

# Create app bundle
echo "📱 Creating app bundle..."
"$INSTALLER_DIR/build-scripts/build-app-bundle.sh"

# Verify app bundle was created
APP_BUNDLE_PATH="$INSTALLER_BUILD_DIR/Transcriber.app"
if [ ! -d "$APP_BUNDLE_PATH" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE_PATH"
    exit 1
fi

# Create payload directories for individual packages
APP_PAYLOAD_DIR="$INSTALLER_BUILD_DIR/app-payload"
CLI_PAYLOAD_DIR="$INSTALLER_BUILD_DIR/cli-payload"

echo "📂 Creating package payloads..."

# Create app payload (installs to /Applications)
mkdir -p "$APP_PAYLOAD_DIR/Applications"
cp -R "$APP_BUNDLE_PATH" "$APP_PAYLOAD_DIR/Applications/"

# Create CLI payload (installs to /usr/local/bin)
mkdir -p "$CLI_PAYLOAD_DIR/usr/local/bin"
cp "$BUILD_DIR/transcriber" "$CLI_PAYLOAD_DIR/usr/local/bin/"
chmod +x "$CLI_PAYLOAD_DIR/usr/local/bin/transcriber"

# Create individual component packages
echo "📦 Creating component packages..."

# Create App package
pkgbuild --root "$APP_PAYLOAD_DIR" \
         --identifier "$APP_PACKAGE_ID" \
         --version "$VERSION" \
         --install-location "/" \
         --scripts "$INSTALLER_DIR/scripts" \
         "$INSTALLER_BUILD_DIR/TranscriberApp.pkg"

echo "✅ Created App component package"

# Create CLI package
pkgbuild --root "$CLI_PAYLOAD_DIR" \
         --identifier "$CLI_PACKAGE_ID" \
         --version "$VERSION" \
         --install-location "/" \
         "$INSTALLER_BUILD_DIR/TranscriberCLI.pkg"

echo "✅ Created CLI component package"

# Create installer resources
echo "📄 Creating installer resources..."

# Create welcome.html
cat > "$INSTALLER_DIR/Resources/welcome.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Welcome to Transcriber</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 20px; }
        h1 { color: #1d1d1f; }
        .feature { margin: 10px 0; padding: 8px; background: #f5f5f7; border-radius: 6px; }
    </style>
</head>
<body>
    <h1>Welcome to Transcriber</h1>
    <p>Transcriber is a modern macOS application for converting audio and video files to text transcriptions using Apple's Speech Recognition framework.</p>
    
    <h2>What's Included:</h2>
    <div class="feature"><strong>📱 Transcriber App</strong> - Native macOS application with intuitive interface</div>
    <div class="feature"><strong>⌨️ Command Line Interface</strong> - Powerful CLI tool for automation and scripting</div>
    
    <h2>Features:</h2>
    <ul>
        <li>🎙️ High-quality speech recognition using Apple's frameworks</li>
        <li>🔒 Privacy-focused: On-device processing available</li>
        <li>📁 Support for multiple audio/video formats (MP3, WAV, MP4, MOV, etc.)</li>
        <li>📝 Multiple output formats (TXT, JSON, SRT, VTT)</li>
        <li>🌍 Multi-language support</li>
        <li>⚡ Fast and efficient processing</li>
    </ul>
    
    <p>Click <strong>Continue</strong> to proceed with the installation.</p>
</body>
</html>
EOF

# Create readme.html
cat > "$INSTALLER_DIR/Resources/readme.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Transcriber Installation Guide</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 20px; }
        h1, h2 { color: #1d1d1f; }
        code { background: #f5f5f7; padding: 2px 4px; border-radius: 3px; font-family: 'SF Mono', Monaco, monospace; }
        .tip { background: #e3f2fd; padding: 12px; border-radius: 6px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>Transcriber v$VERSION - Installation Guide</h1>
    
    <h2>System Requirements</h2>
    <ul>
        <li>macOS 13.0 or later</li>
        <li>Speech Recognition permission (will be requested on first use)</li>
    </ul>
    
    <h2>Installation Components</h2>
    <p><strong>Transcriber App:</strong> Installed to <code>/Applications/Transcriber.app</code></p>
    <p><strong>CLI Tool:</strong> Installed to <code>/usr/local/bin/transcriber</code></p>
    
    <h2>Getting Started</h2>
    
    <h3>Using the App</h3>
    <ol>
        <li>Open <strong>Transcriber</strong> from Applications</li>
        <li>Drag audio/video files into the window or use File → Open</li>
        <li>Configure settings if needed</li>
        <li>Click "Start Transcription"</li>
    </ol>
    
    <h3>Using the CLI</h3>
    <p>Open Terminal and run:</p>
    <code>transcriber /path/to/audio.mp3</code>
    
    <p>For help: <code>transcriber --help</code></p>
    
    <div class="tip">
        <strong>💡 Tip:</strong> On first use, macOS will request permission for Speech Recognition. Click "OK" to enable transcription features.
    </div>
    
    <h2>Configuration</h2>
    <p>Both the app and CLI support configuration files:</p>
    <ul>
        <li>Global: <code>~/.transcriber.yaml</code></li>
        <li>Project: <code>./.transcriber.json</code></li>
    </ul>
    
    <h2>Uninstalling</h2>
    <p>To remove Transcriber: <code>sudo uninstall-transcriber</code></p>
    
    <h2>Support</h2>
    <p>For documentation and support, visit the project repository or use the built-in help commands.</p>
</body>
</html>
EOF

# Create a simple license file
cat > "$INSTALLER_DIR/Resources/license.txt" << 'EOF'
Transcriber End User License Agreement

Copyright (c) 2024 Transcriber

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Update Distribution.xml with current version
sed "s/version=\"1\.0\.1\"/version=\"$VERSION\"/g" \
    "$INSTALLER_DIR/Distribution.xml" > "$INSTALLER_BUILD_DIR/Distribution.xml"

# Create the final installer package
echo "🎁 Creating final installer package..."
productbuild --distribution "$INSTALLER_BUILD_DIR/Distribution.xml" \
             --package-path "$INSTALLER_BUILD_DIR" \
             --resources "$INSTALLER_DIR/Resources" \
             "$FINAL_PKG"

# Verify the package was created
if [ ! -f "$FINAL_PKG" ]; then
    echo "❌ Failed to create installer package"
    exit 1
fi

# Package signing and notarization
echo ""
echo "🔐 Code Signing and Notarization:"
echo "=================================="

if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "🔐 Signing package with Developer ID..."
    echo "   Identity: $DEVELOPER_ID_INSTALLER"
    
    # Create signed package path
    SIGNED_PKG="${FINAL_PKG%.pkg}-signed.pkg"
    
    # Sign the package
    if productsign --sign "$DEVELOPER_ID_INSTALLER" "$FINAL_PKG" "$SIGNED_PKG"; then
        echo "✅ Package signed successfully"
        
        # Replace unsigned package with signed one
        mv "$SIGNED_PKG" "$FINAL_PKG"
        
        # Verify signature
        if pkgutil --check-signature "$FINAL_PKG" > /dev/null 2>&1; then
            echo "✅ Package signature verified"
        else
            echo "⚠️  Package signature verification failed"
        fi
        
        # Notarization
        if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
            echo ""
            echo "📤 Submitting for notarization..."
            echo "   Profile: $KEYCHAIN_PROFILE"
            echo "   This may take several minutes..."
            
            if xcrun notarytool submit "$FINAL_PKG" \
                --keychain-profile "$KEYCHAIN_PROFILE" \
                --wait \
                --timeout 30m; then
                echo "✅ Notarization completed successfully"
                echo "✅ Package is ready for distribution"
            else
                echo "❌ Notarization failed"
                echo "   The package is signed but not notarized"
                echo "   Users may see Gatekeeper warnings"
            fi
        else
            if [ "$SKIP_NOTARIZATION" = "true" ]; then
                echo "⏭️  Notarization skipped (SKIP_NOTARIZATION=true)"
            else
                echo "⚠️  No notarization profile configured"
                echo "   Set KEYCHAIN_PROFILE to enable notarization"
            fi
            echo "   Package is signed but not notarized"
            echo "   Users may see reduced Gatekeeper warnings"
        fi
    else
        echo "❌ Package signing failed"
        echo "   Verify Developer ID Installer certificate is available"
        echo "   Package will be unsigned and blocked by Gatekeeper"
    fi
else
    echo "⚠️  No Developer ID Installer certificate configured"
    echo "   Package will be unsigned and blocked by Gatekeeper"
    echo "   Set DEVELOPER_ID_INSTALLER in .env for production signing"
    echo ""
    echo "📋 Current signing configuration:"
    echo "   DEVELOPER_ID_INSTALLER: ${DEVELOPER_ID_INSTALLER:-❌ Not set}"
    echo "   KEYCHAIN_PROFILE: ${KEYCHAIN_PROFILE:-❌ Not set}"
    echo "   SKIP_NOTARIZATION: ${SKIP_NOTARIZATION:-false}"
fi

# Display package information
echo ""
echo "🎉 Installer package created successfully!"
echo "========================================"
echo "   Package: $FINAL_PKG"
echo "   Version: $VERSION"
echo "   Size: $(du -sh "$FINAL_PKG" | cut -f1)"
echo ""

# Show package contents
echo "📦 Package Information:"
pkgutil --payload-files "$FINAL_PKG" | head -20
if [ $(pkgutil --payload-files "$FINAL_PKG" | wc -l) -gt 20 ]; then
    echo "   ... and $(expr $(pkgutil --payload-files "$FINAL_PKG" | wc -l) - 20) more files"
fi

echo ""
echo "🚀 Installation Instructions:"
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "   1. Double-click $FINAL_PKG to install (signed package)"
    echo "   2. Follow the installer prompts"
    echo "   3. Grant Speech Recognition permission when requested"
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "   ✅ Package is signed and notarized - no Gatekeeper warnings"
    else
        echo "   ⚠️  Package is signed but not notarized - may show Gatekeeper warnings"
    fi
else
    echo "   ⚠️  UNSIGNED PACKAGE - Gatekeeper will block installation"
    echo "   1. Right-click $FINAL_PKG and select 'Open'"
    echo "   2. Click 'Open' in the security dialog"
    echo "   3. Follow the installer prompts"
    echo "   4. Grant Speech Recognition permission when requested"
fi
echo ""
echo "🧪 Testing:"
echo "   installer -pkg '$FINAL_PKG' -target /"
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "   spctl --assess --verbose=4 --type install '$FINAL_PKG'"
fi
echo ""
echo "📤 Distribution:"
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "   ✅ Ready for public distribution (signed and notarized)"
    else
        echo "   ⚠️  Suitable for limited distribution (signed but not notarized)"
    fi
else
    echo "   ❌ Development only - not suitable for public distribution"
    echo "   Configure Developer ID certificates for production distribution"
fi

# Clean up build directory (optional)
# rm -rf "$INSTALLER_BUILD_DIR"

echo ""
echo "✅ Installer creation complete!"