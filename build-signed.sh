#!/bin/bash

# Build script for transcriber with proper entitlements for Speech Recognition

set -e

echo "🎙️  Building transcriber with Speech Recognition entitlements..."

# Clean previous builds
swift package clean

# Build release version
echo "📦 Building release binary..."
swift build -c release

# Get build path
BUILD_PATH=".build/release/transcriber"

if [ -f "$BUILD_PATH" ]; then
    echo "✅ Build successful!"
    
    # Remove any existing code signature
    echo "🔄 Removing existing signatures..."
    codesign --remove-signature "$BUILD_PATH" 2>/dev/null || true
    
    # Code sign with entitlements using ad-hoc signature
    echo "🔐 Applying Speech Recognition entitlements..."
    codesign --force \
             --sign - \
             --entitlements transcriber.entitlements \
             --options runtime \
             "$BUILD_PATH"
    
    # Verify the signature
    echo "🔍 Verifying entitlements..."
    codesign -d --entitlements - "$BUILD_PATH" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Entitlements applied successfully!"
        echo "📍 Binary location: $BUILD_PATH"
        echo ""
        echo "🚀 Ready to use:"
        echo "   $BUILD_PATH /path/to/audio.mp3"
        echo ""
        echo "📥 To install system-wide:"
        echo "   sudo cp $BUILD_PATH /usr/local/bin/"
        echo ""
        echo "💡 On first run, macOS will show a permission dialog."
        echo "   Click 'OK' to allow Speech Recognition access."
    else
        echo "❌ Failed to apply entitlements!"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi