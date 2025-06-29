#!/bin/bash

# Build macOS App Bundle for Transcriber
# Creates a proper .app bundle structure from the Swift binary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER_DIR="$PROJECT_ROOT/installer"

# Get version using shared version determination logic
VERSION=$("$SCRIPT_DIR/get-version.sh")

# Build configuration
APP_NAME="Transcriber"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.transcriber.app"

# Paths
BUILD_DIR="$PROJECT_ROOT/.build/release"
OUTPUT_DIR="$PROJECT_ROOT/installer/build"
APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_BUNDLE"

echo "🏗️  Building macOS App Bundle for $APP_NAME v$VERSION"
echo "======================================================"

# Clean and create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS"
mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"

# Build the Swift app if needed
if [ ! -f "$BUILD_DIR/TranscriberApp" ]; then
    echo "🔨 Building TranscriberApp binary..."
    cd "$PROJECT_ROOT"
    swift build -c release --product TranscriberApp
fi

# Verify binary exists
if [ ! -f "$BUILD_DIR/TranscriberApp" ]; then
    echo "❌ TranscriberApp binary not found at $BUILD_DIR/TranscriberApp"
    exit 1
fi

# Copy the main binary
echo "📦 Copying main binary..."
cp "$BUILD_DIR/TranscriberApp" "$APP_BUNDLE_PATH/Contents/MacOS/"

# Create Info.plist with current version
echo "📝 Creating Info.plist..."
sed "s/<string>1\.0\.1<\/string>/<string>$VERSION<\/string>/g" \
    "$INSTALLER_DIR/Info.plist" > "$APP_BUNDLE_PATH/Contents/Info.plist"

# Copy entitlements for reference (not required in bundle but useful for debugging)
if [ -f "$PROJECT_ROOT/transcriber.entitlements" ]; then
    echo "🔐 Copying entitlements..."
    cp "$PROJECT_ROOT/transcriber.entitlements" "$APP_BUNDLE_PATH/Contents/Resources/"
fi

# Copy README for reference
if [ -f "$PROJECT_ROOT/README.md" ]; then
    echo "📄 Copying README..."
    cp "$PROJECT_ROOT/README.md" "$APP_BUNDLE_PATH/Contents/Resources/"
fi

# Create a simple icon if none exists (optional)
# Note: For production, you'd want to create a proper .icns file
# This creates a basic text file that can be replaced with an actual icon
echo "🎨 Adding placeholder icon..."
echo "Transcriber App Icon Placeholder" > "$APP_BUNDLE_PATH/Contents/Resources/AppIcon.txt"

# Set proper permissions
echo "🔒 Setting permissions..."
chmod -R 755 "$APP_BUNDLE_PATH"
chmod +x "$APP_BUNDLE_PATH/Contents/MacOS/TranscriberApp"

# Code sign the app bundle with entitlements
echo "🔐 Code signing app bundle..."
if [ -f "$PROJECT_ROOT/transcriber.entitlements" ]; then
    codesign --force \
             --sign - \
             --entitlements "$PROJECT_ROOT/transcriber.entitlements" \
             --options runtime \
             --deep \
             "$APP_BUNDLE_PATH"
else
    codesign --force \
             --sign - \
             --options runtime \
             --deep \
             "$APP_BUNDLE_PATH"
fi

# Verify the bundle
echo "🔍 Verifying app bundle..."
if [ -x "$APP_BUNDLE_PATH/Contents/MacOS/TranscriberApp" ]; then
    echo "✅ Main executable is present and executable"
else
    echo "❌ Main executable is missing or not executable"
    exit 1
fi

# Test code signature
codesign -v "$APP_BUNDLE_PATH" && echo "✅ Code signature is valid" || {
    echo "❌ Code signature is invalid"
    exit 1
}

# Display bundle info
echo ""
echo "📊 App Bundle Information:"
echo "   Name: $APP_BUNDLE"
echo "   Path: $APP_BUNDLE_PATH"
echo "   Version: $VERSION"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Size: $(du -sh "$APP_BUNDLE_PATH" | cut -f1)"

# List bundle contents
echo ""
echo "📂 Bundle Contents:"
find "$APP_BUNDLE_PATH" -type f | sed 's|^.*/\([^/]*\.app\)/|\1/|' | sort

echo ""
echo "✅ App bundle created successfully!"
echo "📍 Location: $APP_BUNDLE_PATH"
echo ""
echo "🚀 You can now:"
echo "   • Test the app: open '$APP_BUNDLE_PATH'"
echo "   • Move to Applications: cp -r '$APP_BUNDLE_PATH' /Applications/"
echo "   • Create installer package: ./installer/build-scripts/create-installer.sh"