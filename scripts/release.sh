#!/bin/bash

# Release script for Transcriber
# Usage: ./scripts/release.sh [VERSION]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Get version from argument or prompt
if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
    echo "Current version: $CURRENT_VERSION"
    read -p "Enter new version: " NEW_VERSION
fi

# Validate version format
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Use semver (e.g., 1.0.0)"
    exit 1
fi

echo "🚀 Creating release v$NEW_VERSION..."

# Update version files
echo "$NEW_VERSION" > VERSION

# Update Makefile
sed -i '' "s/VERSION := .*/VERSION := $NEW_VERSION/" Makefile

# Update Swift CLI version
sed -i '' "s/version: \".*\"/version: \"$NEW_VERSION\"/" Sources/TranscriberCLI/main.swift

# Update README if it contains version references
if grep -q "Transcriber v" README.md; then
    sed -i '' "s/Transcriber v[0-9]\+\.[0-9]\+\.[0-9]\+/Transcriber v$NEW_VERSION/g" README.md
fi

echo "📝 Updated version to $NEW_VERSION in:"
echo "   - VERSION"
echo "   - Makefile"
echo "   - Sources/TranscriberCLI/main.swift"
echo "   - README.md (if applicable)"

# Commit changes
if git status --porcelain | grep -q .; then
    echo "📦 Committing version update..."
    git add VERSION Makefile Sources/TranscriberCLI/main.swift README.md
    git commit -m "Bump version to v$NEW_VERSION"
else
    echo "📝 No changes to commit"
fi

# Build release
echo "🔨 Building release..."
make release

# Create git tag
echo "🏷️  Creating git tag..."
if git tag | grep -q "v$NEW_VERSION"; then
    echo "⚠️  Tag v$NEW_VERSION already exists, skipping tag creation"
else
    git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"
    echo "✅ Created tag v$NEW_VERSION"
fi

# Show release info
echo ""
echo "🎉 Release v$NEW_VERSION ready!"
echo ""
echo "📦 Release files:"
echo "   Binary: .build/release/transcriber"
echo "   Archive: releases/transcriber-$NEW_VERSION.zip"
echo ""
echo "🚀 Next steps:"
echo "   1. Test the release: .build/release/transcriber --version"
echo "   2. Push changes: git push origin main"
echo "   3. Push tag: git push origin v$NEW_VERSION"
echo "   4. Create GitHub release with releases/transcriber-$NEW_VERSION.zip"
echo ""
echo "📥 Users can install with:"
echo "   curl -L https://github.com/youruser/transcriber/releases/download/v$NEW_VERSION/transcriber-$NEW_VERSION.zip -o transcriber.zip"
echo "   unzip transcriber.zip && cd transcriber-$NEW_VERSION && ./install.sh"