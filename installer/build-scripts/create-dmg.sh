#!/bin/bash

# Create macOS DMG Installer for Transcriber
# Generates a .dmg with drag-and-drop installation experience

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER_DIR="$PROJECT_ROOT/installer"

# Get version using shared version determination logic
VERSION=$("$SCRIPT_DIR/get-version.sh")

# Configuration
PRODUCT_NAME="Transcriber"
DMG_NAME="${PRODUCT_NAME}-${VERSION}"
VOLUME_NAME="Transcriber $VERSION"

# Paths
BUILD_DIR="$PROJECT_ROOT/.build/release"
INSTALLER_BUILD_DIR="$INSTALLER_DIR/build"
DMG_OUTPUT_DIR="$PROJECT_ROOT/releases"
FINAL_DMG="$DMG_OUTPUT_DIR/${DMG_NAME}.dmg"
TEMP_DMG="/tmp/${DMG_NAME}-temp.dmg"

echo "💿 Creating macOS DMG Installer for $PRODUCT_NAME v$VERSION"
echo "========================================================="

# Clean and create directories
echo "🧹 Preparing build environment..."
rm -rf "$INSTALLER_BUILD_DIR"
mkdir -p "$INSTALLER_BUILD_DIR"
mkdir -p "$DMG_OUTPUT_DIR"

# Build the Swift binaries if needed
echo "🔨 Checking for Swift binaries..."
cd "$PROJECT_ROOT"

# Check if we have pre-built binaries
if [ -f "$BUILD_DIR/transcriber" ] && [ -f "$BUILD_DIR/TranscriberApp" ]; then
    echo "✅ Found pre-built binaries - skipping build step"
    echo "   CLI: $BUILD_DIR/transcriber"
    echo "   App: $BUILD_DIR/TranscriberApp"
else
    echo "   Building CLI and App binaries from source..."
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

# Create DMG staging directory
DMG_STAGING_DIR="$INSTALLER_BUILD_DIR/dmg-staging"
echo "📂 Creating DMG staging directory..."
mkdir -p "$DMG_STAGING_DIR"

# Copy app bundle to staging
cp -R "$APP_BUNDLE_PATH" "$DMG_STAGING_DIR/"

# Install CLI tool to staging (inside app bundle for easy access)
CLI_TOOLS_DIR="$DMG_STAGING_DIR/Transcriber.app/Contents/Resources/CLI Tools"
mkdir -p "$CLI_TOOLS_DIR"
cp "$BUILD_DIR/transcriber" "$CLI_TOOLS_DIR/"
chmod +x "$CLI_TOOLS_DIR/transcriber"

# Create Applications symlink for drag-and-drop
ln -s /Applications "$DMG_STAGING_DIR/Applications"

# Create installation instructions
cat > "$DMG_STAGING_DIR/Install CLI Tool.command" << 'EOF'
#!/bin/bash

# Install Transcriber CLI Tool
# This script installs the CLI tool to /usr/local/bin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_SOURCE="$SCRIPT_DIR/Transcriber.app/Contents/Resources/CLI Tools/transcriber"

echo "Installing Transcriber CLI Tool..."
echo "================================="

if [ ! -f "$CLI_SOURCE" ]; then
    echo "❌ CLI tool not found at expected location"
    exit 1
fi

# Check if /usr/local/bin exists
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin directory..."
    sudo mkdir -p /usr/local/bin
fi

# Copy CLI tool
echo "Copying transcriber to /usr/local/bin..."
sudo cp "$CLI_SOURCE" /usr/local/bin/transcriber
sudo chmod +x /usr/local/bin/transcriber

# Verify installation
if command -v transcriber > /dev/null 2>&1; then
    echo "✅ CLI tool installed successfully!"
    echo ""
    echo "Usage:"
    echo "  transcriber --help          Show help"
    echo "  transcriber audio.mp3       Transcribe audio file"
    echo "  transcriber video.mp4       Transcribe video file"
    echo ""
    echo "You can now use 'transcriber' from any Terminal window."
else
    echo "❌ Installation verification failed"
    echo "You may need to add /usr/local/bin to your PATH"
fi

echo ""
echo "Press any key to close this window..."
read -n 1
EOF

chmod +x "$DMG_STAGING_DIR/Install CLI Tool.command"

# Create README file
cat > "$DMG_STAGING_DIR/README.txt" << EOF
Transcriber v$VERSION
====================

📱 INSTALL APP:
   1. Drag Transcriber.app to the Applications folder
   2. IMPORTANT: If macOS blocks the app with "damaged" error:
      • Open Terminal and run:
        xattr -d com.apple.quarantine /Applications/Transcriber.app
      • OR right-click Transcriber.app → "Open" → Click "Open"

⌨️  INSTALL CLI TOOL:
   Double-click "Install CLI Tool.command"
   (Requires administrator password)

🔒 SECURITY NOTE:
   This is an unsigned app. macOS may show security warnings.
   The app is safe but hasn't been notarized through Apple's process.
   Use the commands above to bypass Gatekeeper restrictions.

📋 WHAT'S INCLUDED:
   • Transcriber.app - Native macOS application
   • transcriber CLI - Command-line tool for automation

🔒 PRIVACY:
   • On-device speech recognition available
   • No data sent to external servers (when using on-device mode)
   • Uses Apple's Speech Recognition framework

📁 SUPPORTED FORMATS:
   Input:  MP3, WAV, M4A, MP4, MOV, and more
   Output: TXT, JSON, SRT, VTT

🌍 LANGUAGES:
   Supports all languages available in macOS Speech Recognition

⚡ USAGE:
   App: Open Transcriber.app and drag files into the window
   CLI: transcriber /path/to/audio.mp3

🛠️  CONFIGURATION:
   Global: ~/.transcriber.yaml
   Project: ./.transcriber.json

📖 HELP:
   App: Help menu in application
   CLI: transcriber --help

🗑️  UNINSTALL:
   • Delete Transcriber.app from Applications
   • Remove CLI: sudo rm /usr/local/bin/transcriber

For support and documentation, visit the project repository.
EOF

# Create background image (simple gradient)
echo "🎨 Creating DMG background..."
BACKGROUND_DIR="$INSTALLER_BUILD_DIR/dmg-background"
mkdir -p "$BACKGROUND_DIR"

# Create a simple background using built-in tools
cat > "$BACKGROUND_DIR/create_background.py" << 'EOF'
#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

# Create a 600x400 background image
width, height = 600, 400
image = Image.new('RGB', (width, height), '#f0f0f0')
draw = ImageDraw.Draw(image)

# Draw a subtle gradient effect
for y in range(height):
    alpha = int(255 * (1 - y / height * 0.1))
    color = (240, 240, 240 - int(y / height * 20))
    draw.line([(0, y), (width, y)], fill=color)

# Add text instructions
try:
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 24)
    small_font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
except:
    font = ImageFont.load_default()
    small_font = ImageFont.load_default()

# Instructions text
draw.text((50, 50), "Transcriber Installation", fill='#333333', font=font)
draw.text((50, 90), "1. Drag Transcriber.app to Applications", fill='#666666', font=small_font)
draw.text((50, 120), "2. Double-click 'Install CLI Tool.command' for terminal access", fill='#666666', font=small_font)
draw.text((50, 350), "Drag & Drop Installation", fill='#888888', font=small_font)

# Save background
output_path = os.path.join(os.path.dirname(__file__), 'background.png')
image.save(output_path)
print(f"Background saved to: {output_path}")
EOF

# Try to create background with Python/PIL, fallback to simple approach
if command -v python3 > /dev/null && python3 -c "import PIL" 2>/dev/null; then
    cd "$BACKGROUND_DIR"
    python3 create_background.py
    BACKGROUND_IMAGE="$BACKGROUND_DIR/background.png"
else
    echo "   Note: PIL not available, using simple background"
    BACKGROUND_IMAGE=""
fi

# Calculate size for DMG
echo "📏 Calculating DMG size..."
DMG_SIZE=$(du -sk "$DMG_STAGING_DIR" | cut -f1)
DMG_SIZE=$((DMG_SIZE + 10000))  # Add 10MB padding

echo "💿 Creating DMG image..."
# Create temporary DMG
hdiutil create -srcfolder "$DMG_STAGING_DIR" \
               -volname "$VOLUME_NAME" \
               -fs HFS+ \
               -fsargs "-c c=64,a=16,e=16" \
               -format UDRW \
               -size ${DMG_SIZE}k \
               "$TEMP_DMG"

# Mount the DMG for customization
echo "🎛️  Customizing DMG appearance..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG"

# Wait for mount to complete
sleep 2

# Set custom icon positions and view settings
if [ -d "$MOUNT_DIR" ]; then
    # Copy background image if available
    if [ -n "$BACKGROUND_IMAGE" ] && [ -f "$BACKGROUND_IMAGE" ]; then
        mkdir -p "$MOUNT_DIR/.background"
        cp "$BACKGROUND_IMAGE" "$MOUNT_DIR/.background/background.png"
    fi
    
    # Detect if we're in a CI environment or headless system
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ] || [ -z "$DISPLAY" ]; then
        echo "   🤖 CI/headless environment detected - skipping GUI customization"
        echo "   📦 DMG will use default appearance (still fully functional)"
    else
        # Only attempt AppleScript in interactive environments
        echo "   🎨 Attempting GUI customization..."
        
        # Create .DS_Store with custom view settings using AppleScript
        if osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        
        -- Only set background if image exists
        try
            if exists file ".background:background.png" then
                set background picture of theViewOptions to file ".background:background.png"
            end if
        end try
        
        -- Position items (with error handling)
        try
            set position of item "Transcriber.app" of container window to {150, 200}
            set position of item "Applications" of container window to {450, 200}
            set position of item "README.txt" of container window to {150, 350}
            set position of item "Install CLI Tool.command" of container window to {450, 350}
        end try
        
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
        then
            echo "   ✅ GUI customization completed successfully"
        else
            echo "   ⚠️  GUI customization failed, but DMG creation will continue"
            echo "   📦 DMG will use default appearance (still fully functional)"
        fi
    fi
    
    # Ensure proper permissions
    chmod -Rf go-w "$MOUNT_DIR"
    sync
else
    echo "⚠️  Could not mount DMG for customization"
fi

# Unmount the DMG
hdiutil detach "$MOUNT_DIR" 2>/dev/null || true

# Convert to compressed, read-only DMG
echo "🗜️  Compressing final DMG..."
rm -f "$FINAL_DMG"
hdiutil convert "$TEMP_DMG" \
                -format UDZO \
                -imagekey zlib-level=9 \
                -o "$FINAL_DMG"

# Clean up temporary DMG
rm -f "$TEMP_DMG"

# Code signing (if certificates available)
echo ""
echo "🔐 Code Signing:"
echo "================"

if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "🔐 Signing DMG with Developer ID..."
    echo "   Identity: $DEVELOPER_ID_APPLICATION"
    
    if codesign --sign "$DEVELOPER_ID_APPLICATION" \
                --timestamp \
                --options runtime \
                "$FINAL_DMG"; then
        echo "✅ DMG signed successfully"
        
        # Verify signature
        if codesign --verify --verbose "$FINAL_DMG" > /dev/null 2>&1; then
            echo "✅ DMG signature verified"
        else
            echo "⚠️  DMG signature verification failed"
        fi
        
        # Notarization
        if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
            echo ""
            echo "📤 Submitting for notarization..."
            echo "   Profile: $KEYCHAIN_PROFILE"
            echo "   This may take several minutes..."
            
            if xcrun notarytool submit "$FINAL_DMG" \
                --keychain-profile "$KEYCHAIN_PROFILE" \
                --wait \
                --timeout 30m; then
                echo "✅ Notarization completed successfully"
                
                # Staple notarization ticket
                if xcrun stapler staple "$FINAL_DMG"; then
                    echo "✅ Notarization ticket stapled"
                    echo "✅ DMG is ready for distribution"
                else
                    echo "⚠️  Failed to staple notarization ticket"
                fi
            else
                echo "❌ Notarization failed"
                echo "   The DMG is signed but not notarized"
                echo "   Users may see Gatekeeper warnings"
            fi
        else
            if [ "$SKIP_NOTARIZATION" = "true" ]; then
                echo "⏭️  Notarization skipped (SKIP_NOTARIZATION=true)"
            else
                echo "⚠️  No notarization profile configured"
                echo "   Set KEYCHAIN_PROFILE to enable notarization"
            fi
            echo "   DMG is signed but not notarized"
            echo "   Users may see reduced Gatekeeper warnings"
        fi
    else
        echo "❌ DMG signing failed"
        echo "   Verify Developer ID Application certificate is available"
        echo "   DMG will be unsigned but still installable"
    fi
else
    echo "⚠️  No Developer ID Application certificate configured"
    echo "   DMG will be unsigned but still installable via right-click"
    echo "   Set DEVELOPER_ID_APPLICATION in .env for production signing"
    echo ""
    echo "📋 Current signing configuration:"
    echo "   DEVELOPER_ID_APPLICATION: ${DEVELOPER_ID_APPLICATION:-❌ Not set}"
    echo "   KEYCHAIN_PROFILE: ${KEYCHAIN_PROFILE:-❌ Not set}"
    echo "   SKIP_NOTARIZATION: ${SKIP_NOTARIZATION:-false}"
fi

# Verify the DMG was created
if [ ! -f "$FINAL_DMG" ]; then
    echo "❌ Failed to create DMG"
    exit 1
fi

# Display DMG information
echo ""
echo "🎉 DMG installer created successfully!"
echo "====================================="
echo "   DMG: $FINAL_DMG"
echo "   Version: $VERSION"
echo "   Size: $(du -sh "$FINAL_DMG" | cut -f1)"
echo ""

# Show DMG contents
echo "💿 DMG Contents:"
hdiutil attach -readonly -noverify -noautoopen "$FINAL_DMG" > /dev/null 2>&1
if [ -d "/Volumes/$VOLUME_NAME" ]; then
    ls -la "/Volumes/$VOLUME_NAME"
    hdiutil detach "/Volumes/$VOLUME_NAME" > /dev/null 2>&1
else
    echo "   (Could not mount DMG to show contents)"
fi

echo ""
echo "🚀 Installation Instructions:"
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "   1. Double-click $FINAL_DMG to mount (signed DMG)"
    echo "   2. Drag Transcriber.app to Applications folder"
    echo "   3. Double-click 'Install CLI Tool.command' for terminal access"
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "   ✅ DMG is signed and notarized - no Gatekeeper warnings"
    else
        echo "   ⚠️  DMG is signed but not notarized - may show Gatekeeper warnings"
    fi
else
    echo "   ⚠️  UNSIGNED DMG - may show Gatekeeper warnings"
    echo "   1. Right-click $FINAL_DMG and select 'Open' if blocked"
    echo "   2. Double-click the DMG file to mount"
    echo "   3. Drag Transcriber.app to Applications folder"
    echo "   4. Double-click 'Install CLI Tool.command' for terminal access"
fi

echo ""
echo "🧪 Testing:"
echo "   hdiutil attach '$FINAL_DMG'"
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "   spctl --assess --verbose=4 --type execute '/Volumes/$VOLUME_NAME/Transcriber.app'"
fi

echo ""
echo "📤 Distribution:"
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    if [ -n "$KEYCHAIN_PROFILE" ] && [ "$SKIP_NOTARIZATION" != "true" ]; then
        echo "   ✅ Ready for public distribution (signed and notarized)"
    else
        echo "   ⚠️  Suitable for limited distribution (signed but not notarized)"
    fi
else
    echo "   ⚠️  Development distribution - users may see warnings"
    echo "   Configure Developer ID certificates for production distribution"
fi

# Clean up build directory (optional)
# rm -rf "$INSTALLER_BUILD_DIR"

echo ""
echo "✅ DMG creation complete!"