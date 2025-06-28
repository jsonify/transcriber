#!/bin/bash

# Transcriber Uninstaller
# Standalone uninstall script for Transcriber

echo "🗑️  Transcriber Uninstaller"
echo "=========================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script requires administrator privileges."
    echo "Please run: sudo $0"
    exit 1
fi

echo "This will completely remove Transcriber from your system:"
echo "• /Applications/Transcriber.app"
echo "• /usr/local/bin/transcriber (CLI tool)"
echo "• /usr/local/bin/uninstall-transcriber"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Removing Transcriber components..."

# Remove app bundle
if [ -d "/Applications/Transcriber.app" ]; then
    echo "• Removing Transcriber.app..."
    rm -rf "/Applications/Transcriber.app"
    echo "  ✅ Removed"
else
    echo "• Transcriber.app not found (already removed)"
fi

# Remove CLI tool
if [ -f "/usr/local/bin/transcriber" ]; then
    echo "• Removing CLI tool..."
    rm -f "/usr/local/bin/transcriber"
    echo "  ✅ Removed"
else
    echo "• CLI tool not found (already removed)"
fi

# Remove installed uninstaller
if [ -f "/usr/local/bin/uninstall-transcriber" ]; then
    echo "• Removing uninstaller..."
    rm -f "/usr/local/bin/uninstall-transcriber"
    echo "  ✅ Removed"
fi

# Update Launch Services database
echo "• Updating Launch Services database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user >/dev/null 2>&1 || true
echo "  ✅ Updated"

echo ""
echo "🎉 Transcriber has been completely uninstalled."
echo ""
echo "Thank you for using Transcriber!"