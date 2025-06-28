#!/bin/bash

# Transcriber Silent Installation Script
# For automated deployment and enterprise installation
# 
# Usage: ./install-silently.sh [OPTIONS] [PACKAGE_PATH]
#
# Options:
#   --target PATH        Installation target (default: /)
#   --app-only          Install only the application (skip CLI)
#   --cli-only          Install only the CLI tool (skip app)
#   --verbose           Show detailed installation output
#   --help              Show this help message
#
# Examples:
#   ./install-silently.sh Transcriber-1.0.1.pkg
#   ./install-silently.sh --verbose --target / Transcriber-1.0.1.pkg
#   ./install-silently.sh --cli-only Transcriber-1.0.1.pkg

set -e

# Default values
TARGET_PATH="/"
VERBOSE=false
APP_ONLY=false
CLI_ONLY=false
PACKAGE_PATH=""

# Function to show help
show_help() {
    cat << EOF
Transcriber Silent Installation Script

USAGE:
    $0 [OPTIONS] [PACKAGE_PATH]

OPTIONS:
    --target PATH        Installation target (default: /)
    --app-only          Install only the application (skip CLI)
    --cli-only          Install only the CLI tool (skip app)
    --verbose           Show detailed installation output
    --help              Show this help message

EXAMPLES:
    # Basic silent installation
    $0 Transcriber-1.0.1.pkg

    # Verbose installation with custom target
    $0 --verbose --target / Transcriber-1.0.1.pkg

    # Install only CLI tool
    $0 --cli-only Transcriber-1.0.1.pkg

    # Install only the application
    $0 --app-only Transcriber-1.0.1.pkg

NOTES:
    - This script requires administrator privileges (sudo)
    - The package must be a valid Transcriber .pkg file
    - Use --verbose for troubleshooting installation issues
    - Component selection affects which parts are installed

REQUIREMENTS:
    - macOS 13.0 or later
    - Administrator privileges
    - Valid Transcriber .pkg installer

EOF
}

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Function to check if running as root
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This script requires administrator privileges."
        echo "Please run: sudo $0 $*"
        exit 1
    fi
}

# Function to validate package
validate_package() {
    if [ ! -f "$PACKAGE_PATH" ]; then
        echo "Error: Package file not found: $PACKAGE_PATH"
        exit 1
    fi
    
    if [[ ! "$PACKAGE_PATH" =~ \.pkg$ ]]; then
        echo "Error: File must be a .pkg installer: $PACKAGE_PATH"
        exit 1
    fi
    
    # Verify it's a valid package
    if ! pkgutil --check-signature "$PACKAGE_PATH" >/dev/null 2>&1; then
        log "Warning: Package signature could not be verified"
    fi
    
    log "Package validation successful: $PACKAGE_PATH"
}

# Function to create choices XML for component selection
create_choices_xml() {
    local choices_file="/tmp/transcriber-choices.xml"
    
    cat > "$choices_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
EOF

    if [ "$CLI_ONLY" = false ]; then
        cat >> "$choices_file" << EOF
    <dict>
        <key>choiceIdentifier</key>
        <string>com.transcriber.app</string>
        <key>choiceIsSelected</key>
        <integer>1</integer>
    </dict>
EOF
    fi

    if [ "$APP_ONLY" = false ]; then
        cat >> "$choices_file" << EOF
    <dict>
        <key>choiceIdentifier</key>
        <string>com.transcriber.cli</string>
        <key>choiceIsSelected</key>
        <integer>1</integer>
    </dict>
EOF
    fi

    cat >> "$choices_file" << EOF
</array>
</plist>
EOF

    echo "$choices_file"
}

# Function to perform silent installation
perform_installation() {
    log "Starting silent installation of Transcriber..."
    log "Package: $PACKAGE_PATH"
    log "Target: $TARGET_PATH"
    log "App Only: $APP_ONLY"
    log "CLI Only: $CLI_ONLY"
    
    # Create choices file for component selection
    local choices_file
    choices_file=$(create_choices_xml)
    
    # Build installer command
    local installer_cmd="installer -pkg '$PACKAGE_PATH' -target '$TARGET_PATH'"
    
    # Add choices file if component selection is needed
    if [ "$APP_ONLY" = true ] || [ "$CLI_ONLY" = true ]; then
        installer_cmd="$installer_cmd -applyChoiceChangesXML '$choices_file'"
    fi
    
    # Add verbosity if requested
    if [ "$VERBOSE" = true ]; then
        installer_cmd="$installer_cmd -verbose"
    fi
    
    log "Executing: $installer_cmd"
    
    # Execute installation
    if eval "$installer_cmd"; then
        echo "✅ Transcriber installation completed successfully"
        
        # Show what was installed
        if [ "$CLI_ONLY" = false ]; then
            echo "   📱 Application installed: /Applications/Transcriber.app"
        fi
        if [ "$APP_ONLY" = false ]; then
            echo "   ⌨️  CLI tool installed: /usr/local/bin/transcriber"
        fi
        echo "   🗑️  Uninstaller available: uninstall-transcriber"
        
    else
        echo "❌ Installation failed"
        echo "Check the system logs for more details: /var/log/install.log"
        exit 1
    fi
    
    # Clean up temporary files
    [ -f "$choices_file" ] && rm -f "$choices_file"
    
    log "Silent installation process completed"
}

# Function to verify installation
verify_installation() {
    log "Verifying installation..."
    
    local errors=0
    
    if [ "$CLI_ONLY" = false ]; then
        if [ -d "/Applications/Transcriber.app" ]; then
            log "✅ Application bundle found: /Applications/Transcriber.app"
        else
            echo "❌ Application bundle not found: /Applications/Transcriber.app"
            errors=$((errors + 1))
        fi
    fi
    
    if [ "$APP_ONLY" = false ]; then
        if [ -f "/usr/local/bin/transcriber" ]; then
            log "✅ CLI tool found: /usr/local/bin/transcriber"
            
            # Test CLI tool
            if /usr/local/bin/transcriber --version >/dev/null 2>&1; then
                log "✅ CLI tool is functional"
            else
                echo "⚠️  CLI tool found but may not be functional"
                errors=$((errors + 1))
            fi
        else
            echo "❌ CLI tool not found: /usr/local/bin/transcriber"
            errors=$((errors + 1))
        fi
    fi
    
    if [ "$errors" -eq 0 ]; then
        echo "🎉 Installation verification successful"
        return 0
    else
        echo "⚠️  Installation verification found $errors issue(s)"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET_PATH="$2"
            shift 2
            ;;
        --app-only)
            APP_ONLY=true
            shift
            ;;
        --cli-only)
            CLI_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [ -z "$PACKAGE_PATH" ]; then
                PACKAGE_PATH="$1"
            else
                echo "Error: Multiple package paths specified"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$PACKAGE_PATH" ]; then
    echo "Error: Package path is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ "$APP_ONLY" = true ] && [ "$CLI_ONLY" = true ]; then
    echo "Error: Cannot specify both --app-only and --cli-only"
    echo "Use --help for usage information"
    exit 1
fi

# Main execution
echo "🚀 Transcriber Silent Installer"
echo "================================"

check_privileges "$@"
validate_package
perform_installation
verify_installation

echo ""
echo "Silent installation completed successfully!"
echo "For support, visit: https://github.com/jsonify/transcriber"