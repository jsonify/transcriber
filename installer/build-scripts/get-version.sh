#!/bin/bash

# Shared Version Determination Script for Transcriber Build Scripts
# 
# This script provides a single source of truth for version determination
# across all build scripts, eliminating code duplication and improving robustness.
#
# Usage:
#   VERSION=$(./get-version.sh)
#
# Version Resolution Priority:
#   1. RELEASE_VERSION environment variable (CI/CD workflows)
#   2. VERSION file in project root (local development)
#   3. Error if neither is available (fail-fast approach)
#
# Exit Codes:
#   0: Success - version determined and output to stdout
#   1: Error - version could not be determined

set -e

# Get project root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Robust version determination with fail-fast approach
if [ -n "$RELEASE_VERSION" ]; then
    # Priority 1: Use environment variable (CI/CD workflows)
    VERSION="$RELEASE_VERSION"
    echo "🏷️  Using RELEASE_VERSION from environment: $VERSION" >&2
else
    # Priority 2: Use VERSION file (local development)
    VERSION_FILE="$PROJECT_ROOT/VERSION"
    
    # Check if VERSION file exists and is not empty
    if ! [ -s "$VERSION_FILE" ]; then
        echo "❌ Error: Version file not found or is empty at '$VERSION_FILE'." >&2
        echo "   Please either:" >&2
        echo "   1. Set RELEASE_VERSION environment variable, or" >&2
        echo "   2. Ensure '$VERSION_FILE' exists and contains the version" >&2
        echo "" >&2
        echo "   Example: echo '2.2.4' > '$VERSION_FILE'" >&2
        exit 1
    fi
    
    # Read version from file and strip whitespace
    VERSION=$(cat "$VERSION_FILE" | tr -d '\n\r\t ')
    
    # Validate version is not empty after stripping whitespace
    if [ -z "$VERSION" ]; then
        echo "❌ Error: VERSION file contains only whitespace at '$VERSION_FILE'." >&2
        echo "   Please ensure the file contains a valid version string." >&2
        exit 1
    fi
    
    echo "📁 Using VERSION from file: $VERSION" >&2
fi

# Validate version format (basic check for semantic versioning)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'; then
    echo "⚠️  Warning: Version '$VERSION' does not follow semantic versioning format (x.y.z)" >&2
    echo "   Proceeding anyway, but consider using proper semantic versioning." >&2
fi

# Output version for consumption by calling script
echo "$VERSION"