#!/bin/bash

# Build script for transcriber

set -e

echo "Building transcriber..."

# Clean previous builds
swift package clean

# Build release version
swift build -c release

# Get build path
BUILD_PATH=".build/release/transcriber"

if [ -f "$BUILD_PATH" ]; then
    echo "Build successful!"
    echo "Binary location: $BUILD_PATH"
    echo ""
    echo "To install system-wide, run:"
    echo "  sudo cp $BUILD_PATH /usr/local/bin/"
    echo ""
    echo "To test locally:"
    echo "  $BUILD_PATH --help"
else
    echo "Build failed!"
    exit 1
fi