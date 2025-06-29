#!/bin/bash

# Build script for transcriber with proper entitlements for Speech Recognition

set -e

echo "🎙️  Building transcriber with Speech Recognition entitlements..."

# Clean previous builds
swift package clean

# Build universal binaries for both architectures
echo "📦 Building universal binaries for both Intel and Apple Silicon..."
echo "   🏗️  Building for x86_64 (Intel)..."
swift build -c release --arch x86_64
echo "   🏗️  Building for arm64 (Apple Silicon)..."
swift build -c release --arch arm64

# Create universal binaries for both CLI and App
echo "🔗 Creating universal binaries..."

# CLI tool
lipo -create \
    .build/x86_64-apple-macosx/release/transcriber \
    .build/arm64-apple-macosx/release/transcriber \
    -output .build/release/transcriber

# App binary  
lipo -create \
    .build/x86_64-apple-macosx/release/TranscriberApp \
    .build/arm64-apple-macosx/release/TranscriberApp \
    -output .build/release/TranscriberApp

# Verify universal binaries
echo "🔍 Verifying universal binaries..."
echo "   CLI tool:"
lipo -info .build/release/transcriber
echo "   GUI app:"
lipo -info .build/release/TranscriberApp

# Get build paths (maintain compatibility with existing script)
BUILD_PATH=".build/release/transcriber"
APP_BUILD_PATH=".build/release/TranscriberApp"

if [ -f "$BUILD_PATH" ] && [ -f "$APP_BUILD_PATH" ]; then
    echo "✅ Build successful!"
    
    # Remove any existing code signatures
    echo "🔄 Removing existing signatures..."
    codesign --remove-signature "$BUILD_PATH" 2>/dev/null || true
    codesign --remove-signature "$APP_BUILD_PATH" 2>/dev/null || true
    
    # Code sign both binaries with entitlements using ad-hoc signature
    echo "🔐 Applying Speech Recognition entitlements to CLI tool..."
    codesign --force \
             --sign - \
             --entitlements transcriber.entitlements \
             --options runtime \
             "$BUILD_PATH"
    
    echo "🔐 Applying Speech Recognition entitlements to GUI app..."
    codesign --force \
             --sign - \
             --entitlements transcriber.entitlements \
             --options runtime \
             "$APP_BUILD_PATH"
    
    # Verify the signatures
    echo "🔍 Verifying entitlements..."
    CLI_SIGN_OK=0
    APP_SIGN_OK=0
    
    codesign -d --entitlements - "$BUILD_PATH" > /dev/null 2>&1 && CLI_SIGN_OK=1
    codesign -d --entitlements - "$APP_BUILD_PATH" > /dev/null 2>&1 && APP_SIGN_OK=1
    
    if [ $CLI_SIGN_OK -eq 1 ] && [ $APP_SIGN_OK -eq 1 ]; then
        echo "✅ Entitlements applied successfully to both binaries!"
        echo ""
        echo "📍 Binary locations:"
        echo "   CLI tool: $BUILD_PATH"
        echo "   GUI app:  $APP_BUILD_PATH"
        echo ""
        echo "🚀 Ready to use:"
        echo "   CLI: $BUILD_PATH /path/to/audio.mp3"
        echo "   GUI: open $APP_BUILD_PATH"
        echo ""
        echo "📥 To install system-wide:"
        echo "   sudo cp $BUILD_PATH /usr/local/bin/"
        echo ""
        echo "💡 On first run, macOS will show a permission dialog."
        echo "   Click 'OK' to allow Speech Recognition access."
    else
        echo "❌ Failed to apply entitlements!"
        [ $CLI_SIGN_OK -eq 0 ] && echo "   CLI tool signing failed"
        [ $APP_SIGN_OK -eq 0 ] && echo "   GUI app signing failed"
        exit 1
    fi
else
    echo "❌ Build failed!"
    [ ! -f "$BUILD_PATH" ] && echo "   CLI tool binary missing: $BUILD_PATH"
    [ ! -f "$APP_BUILD_PATH" ] && echo "   GUI app binary missing: $APP_BUILD_PATH"
    exit 1
fi