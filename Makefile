# Makefile for Transcriber
# Modern macOS Speech Recognition CLI Tool

# Project Configuration
PROGRAM_NAME := transcriber
APP_NAME := TranscriberApp
# Version management with VERSION file fallback and release override support
VERSION_FILE := VERSION
RELEASE_VERSION ?= # Can be set via environment for CI/release builds

# Version resolution logic with release override support
ifeq ($(RELEASE_VERSION),)
  # Development build: use latest git tag or VERSION file
  # Only consider semantic version tags (v1.2.3 format, no suffixes)
  GIT_VERSION := $(shell git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -n1 | sed 's/^v//' 2>/dev/null)
  FILE_VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null | tr -d '\n' || echo "")
  
  # Use git tag if available, otherwise fall back to VERSION file with warning
  ifeq ($(GIT_VERSION),)
    ifneq ($(FILE_VERSION),)
      VERSION := $(FILE_VERSION)
      $(warning ⚠️  No git tags found, using VERSION file: $(VERSION))
    else
      $(error ❌ Neither git tags nor VERSION file found - cannot determine version)
    endif
  else
    VERSION := $(GIT_VERSION)
  endif
else
  # Release build: use provided version override (for CI/release workflows)
  VERSION := $(RELEASE_VERSION)
  $(info 🏷️  Using release version override: $(VERSION))
endif
BUILD_DIR := .build
RELEASE_DIR := releases
ARCHIVE_DIR := $(RELEASE_DIR)/$(PROGRAM_NAME)-$(VERSION)

# Build Configuration
SWIFT_BUILD_FLAGS := -c release --disable-sandbox
ENTITLEMENTS_FILE := transcriber.entitlements

# Code Signing Configuration
# Load from environment variables or use defaults
DEVELOPER_ID_APPLICATION ?= 
DEVELOPER_ID_INSTALLER ?= 
SIGNING_IDENTITY ?= -
KEYCHAIN_PROFILE ?= 
SKIP_NOTARIZATION ?= false

# Determine signing mode based on available certificates
SIGNING_MODE := $(if $(DEVELOPER_ID_APPLICATION),production,development)
CLI_SIGN_IDENTITY := $(if $(DEVELOPER_ID_APPLICATION),$(DEVELOPER_ID_APPLICATION),$(SIGNING_IDENTITY))
APP_SIGN_IDENTITY := $(if $(DEVELOPER_ID_APPLICATION),$(DEVELOPER_ID_APPLICATION),$(SIGNING_IDENTITY))

# Derived Paths
ARCHIVE_BINARY := $(ARCHIVE_DIR)/$(PROGRAM_NAME)
ARCHIVE_APP := $(ARCHIVE_DIR)/$(APP_NAME).app
ARCHIVE_FILE := $(RELEASE_DIR)/$(PROGRAM_NAME)-$(VERSION).zip

# Installer Paths
INSTALLER_DIR := installer
INSTALLER_PKG := $(RELEASE_DIR)/$(PROGRAM_NAME)-$(VERSION).pkg

# Default target
.PHONY: all
all: clean build

# Development targets
.PHONY: build
build:
	@echo "🔨 Building $(PROGRAM_NAME) CLI (debug)..."
	swift build --target TranscriberCLI

.PHONY: build-cli
build-cli:
	@echo "🔨 Building $(PROGRAM_NAME) CLI (debug)..."
	swift build --target TranscriberCLI

.PHONY: build-app
build-app:
	@echo "📱 Building $(APP_NAME) (debug)..."
	swift build --target TranscriberApp

.PHONY: build-all
build-all:
	@echo "🔨 Building both CLI and App (debug)..."
	swift build --target TranscriberCLI
	swift build --target TranscriberApp

.PHONY: test
test:
	@echo "🧪 Running tests..."
	swift test

.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	swift package clean
	rm -rf $(RELEASE_DIR)

# Release targets
.PHONY: release
release: clean build-release-all sign-all test-release archive installer

.PHONY: release-cli
release-cli: clean build-release-cli sign test-release archive-cli

.PHONY: release-app
release-app: clean build-release-app sign-app archive-app

.PHONY: build-release-cli
build-release-cli:
	@echo "📦 Building $(PROGRAM_NAME) CLI v$(VERSION) universal binary (release)..."
	@# Clean build cache to avoid conflicts between architecture builds
	swift package clean
	@echo "   🏗️  Building for x86_64 (Intel)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch x86_64 --product $(PROGRAM_NAME)
	@echo "   🏗️  Building for arm64 (Apple Silicon)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch arm64 --product $(PROGRAM_NAME)
	@echo "   🔗 Creating universal binary..."
	lipo -create \
		.build/x86_64-apple-macosx/release/$(PROGRAM_NAME) \
		.build/arm64-apple-macosx/release/$(PROGRAM_NAME) \
		-output .build/release/$(PROGRAM_NAME)
	@echo "   🔍 Verifying universal binary..."
	lipo -info .build/release/$(PROGRAM_NAME)
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	if [ ! -f "$$BINARY_PATH" ]; then \
		echo "❌ CLI build failed - binary not found at $$BINARY_PATH"; \
		echo "Directory contents:"; \
		ls -la "$$BIN_PATH" 2>/dev/null || echo "Directory does not exist"; \
		exit 1; \
	fi; \
	echo "✅ CLI universal binary build complete at $$BINARY_PATH"

.PHONY: build-release-cli-intel
build-release-cli-intel:
	@echo "📦 Building $(PROGRAM_NAME) CLI v$(VERSION) Intel-only binary (release)..."
	@# Clean build cache to avoid conflicts between architecture builds
	swift package clean
	@echo "   🏗️  Building for x86_64 (Intel)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch x86_64 --product $(PROGRAM_NAME)
	@# Copy Intel binary to release location
	mkdir -p .build/release
	cp .build/x86_64-apple-macosx/release/$(PROGRAM_NAME) .build/release/$(PROGRAM_NAME)-intel
	@echo "   🔍 Verifying Intel-only binary..."
	file .build/release/$(PROGRAM_NAME)-intel
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	if [ ! -f ".build/release/$(PROGRAM_NAME)-intel" ]; then \
		echo "❌ Intel CLI build failed - binary not found"; \
		exit 1; \
	fi; \
	echo "✅ CLI Intel-only binary build complete at .build/release/$(PROGRAM_NAME)-intel"

.PHONY: build-release-app-intel  
build-release-app-intel:
	@echo "📱 Building $(APP_NAME) v$(VERSION) Intel-only binary (release)..."
	@# Clean build cache to avoid conflicts between architecture builds
	swift package clean
	@echo "   🏗️  Building for x86_64 (Intel)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch x86_64 --product $(APP_NAME)
	@# Copy Intel binary to release location
	mkdir -p .build/release
	cp .build/x86_64-apple-macosx/release/$(APP_NAME) .build/release/$(APP_NAME)-intel
	@echo "   🔍 Verifying Intel-only binary..."
	file .build/release/$(APP_NAME)-intel
	@if [ ! -f ".build/release/$(APP_NAME)-intel" ]; then \
		echo "❌ Intel App build failed - binary not found"; \
		exit 1; \
	fi; \
	echo "✅ App Intel-only binary build complete at .build/release/$(APP_NAME)-intel"

.PHONY: build-release-app
build-release-app:
	@echo "📱 Building $(APP_NAME) v$(VERSION) universal binary (release)..."
	@# Clean build cache to avoid conflicts between architecture builds
	swift package clean
	@echo "   🏗️  Building for x86_64 (Intel)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch x86_64 --product $(APP_NAME)
	@echo "   🏗️  Building for arm64 (Apple Silicon)..."
	swift build $(SWIFT_BUILD_FLAGS) --arch arm64 --product $(APP_NAME)
	@echo "   🔗 Creating universal binary..."
	lipo -create \
		.build/x86_64-apple-macosx/release/$(APP_NAME) \
		.build/arm64-apple-macosx/release/$(APP_NAME) \
		-output .build/release/$(APP_NAME)
	@echo "   🔍 Verifying universal binary..."
	lipo -info .build/release/$(APP_NAME)
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(APP_NAME)"; \
	if [ ! -f "$$BINARY_PATH" ]; then \
		echo "❌ App build failed - binary not found at $$BINARY_PATH"; \
		echo "Directory contents:"; \
		ls -la "$$BIN_PATH" 2>/dev/null || echo "Directory does not exist"; \
		exit 1; \
	fi; \
	echo "✅ App universal binary build complete at $$BINARY_PATH"

.PHONY: build-release-all
build-release-all: build-release-cli build-release-app
	@echo "✅ Both CLI and App release builds complete"

# Legacy target for backward compatibility
.PHONY: build-release
build-release: build-release-cli

.PHONY: sign
sign:
	@echo "🔐 Code signing CLI with Speech Recognition entitlements ($(SIGNING_MODE) mode)..."
	@if [ ! -f "$(ENTITLEMENTS_FILE)" ]; then \
		echo "❌ Entitlements file not found: $(ENTITLEMENTS_FILE)"; \
		exit 1; \
	fi
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "   Using Developer ID: $(CLI_SIGN_IDENTITY)"; \
	else \
		echo "   Using ad-hoc signature (development mode)"; \
	fi
	@# Check if universal binary exists, if not build it
	@if [ ! -f ".build/release/$(PROGRAM_NAME)" ]; then \
		echo "   Universal binary not found, building..."; \
		$(MAKE) build-release-cli; \
	fi
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	codesign --remove-signature "$$BINARY_PATH" 2>/dev/null || true; \
	codesign --force \
	         --sign "$(CLI_SIGN_IDENTITY)" \
	         --entitlements "$(ENTITLEMENTS_FILE)" \
	         --options runtime \
	         "$$BINARY_PATH"
	@echo "✅ CLI code signing complete"

.PHONY: sign-app
sign-app:
	@echo "🔐 Code signing App with Speech Recognition entitlements ($(SIGNING_MODE) mode)..."
	@if [ ! -f "$(ENTITLEMENTS_FILE)" ]; then \
		echo "❌ Entitlements file not found: $(ENTITLEMENTS_FILE)"; \
		exit 1; \
	fi
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "   Using Developer ID: $(APP_SIGN_IDENTITY)"; \
	else \
		echo "   Using ad-hoc signature (development mode)"; \
	fi
	@# Check if universal binary exists, if not build it
	@if [ ! -f ".build/release/$(APP_NAME)" ]; then \
		echo "   Universal binary not found, building..."; \
		$(MAKE) build-release-app; \
	fi
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(APP_NAME)"; \
	codesign --remove-signature "$$BINARY_PATH" 2>/dev/null || true; \
	codesign --force \
	         --sign "$(APP_SIGN_IDENTITY)" \
	         --entitlements "$(ENTITLEMENTS_FILE)" \
	         --options runtime \
	         "$$BINARY_PATH"
	@echo "✅ App code signing complete"

.PHONY: sign-all
sign-all: sign sign-app
	@echo "✅ Both CLI and App code signing complete"

.PHONY: verify
verify: sign
	@echo "🔍 Verifying signature and entitlements..."
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	codesign -v "$$BINARY_PATH"; \
	codesign -d --entitlements - "$$BINARY_PATH" > /dev/null 2>&1
	@echo "✅ Signature verification complete"

# Certificate verification and management
.PHONY: verify-certificates
verify-certificates:
	@echo "🔍 Verifying code signing certificates..."
	@echo "   Signing mode: $(SIGNING_MODE)"
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "   Developer ID Application: $(DEVELOPER_ID_APPLICATION)"; \
		echo "   Developer ID Installer: $(if $(DEVELOPER_ID_INSTALLER),$(DEVELOPER_ID_INSTALLER),❌ Not configured)"; \
		echo "   Keychain profile: $(if $(KEYCHAIN_PROFILE),$(KEYCHAIN_PROFILE),❌ Not configured)"; \
		echo ""; \
		echo "🔍 Checking certificate availability..."; \
		if security find-identity -v -p codesigning | grep -q "$(DEVELOPER_ID_APPLICATION)"; then \
			echo "✅ Developer ID Application certificate found"; \
		else \
			echo "❌ Developer ID Application certificate not found in keychain"; \
		fi; \
		if [ -n "$(DEVELOPER_ID_INSTALLER)" ]; then \
			if security find-identity -v -p codesigning | grep -q "$(DEVELOPER_ID_INSTALLER)"; then \
				echo "✅ Developer ID Installer certificate found"; \
			else \
				echo "❌ Developer ID Installer certificate not found in keychain"; \
			fi; \
		fi; \
	else \
		echo "   Using ad-hoc signatures (development mode)"; \
		echo "   💡 Set DEVELOPER_ID_APPLICATION to enable production signing"; \
	fi

.PHONY: setup-self-signed
setup-self-signed:
	@echo "🔐 Setting up self-signed certificates..."
	scripts/setup-self-signed.sh

.PHONY: check-signing-environment
check-signing-environment: verify-certificates
	@echo ""
	@echo "📋 Code Signing Environment Summary:"
	@echo "   Project: $(PROGRAM_NAME) v$(VERSION)"
	@echo "   Mode: $(SIGNING_MODE)"
	@echo "   CLI identity: $(CLI_SIGN_IDENTITY)"
	@echo "   App identity: $(APP_SIGN_IDENTITY)"
	@echo "   Installer identity: $(if $(DEVELOPER_ID_INSTALLER),$(DEVELOPER_ID_INSTALLER),❌ Not configured)"
	@echo "   Notarization: $(if $(KEYCHAIN_PROFILE),Enabled ($(KEYCHAIN_PROFILE)),❌ Disabled)"
	@echo ""
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "✅ Ready for production signing and distribution"; \
	else \
		echo "⚠️  Development mode - packages will not pass Gatekeeper"; \
		echo "   Set environment variables in .env to enable production signing"; \
	fi

.PHONY: test-release
test-release: verify
	@echo "🧪 Testing release binary..."
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	echo "  • Testing help output..."; \
	"$$BINARY_PATH" --help > /dev/null; \
	echo "  • Testing version output..."; \
	"$$BINARY_PATH" --version > /dev/null; \
	echo "  • Testing language listing..."; \
	timeout 30s "$$BINARY_PATH" --list-languages > /dev/null 2>&1 || true
	@echo "✅ Release binary tests passed"

.PHONY: archive
archive: verify archive-cli archive-app
	@echo "📦 Creating combined release archive..."
	cd "$(RELEASE_DIR)" && zip -r "$(PROGRAM_NAME)-$(VERSION).zip" "$(PROGRAM_NAME)-$(VERSION)"
	@echo "✅ Combined archive created: $(ARCHIVE_FILE)"
	@echo "📊 Archive contents:"
	@cd "$(RELEASE_DIR)" && unzip -l "$(PROGRAM_NAME)-$(VERSION).zip"

.PHONY: archive-cli
archive-cli: verify
	@echo "📦 Creating CLI release archive..."
	mkdir -p "$(ARCHIVE_DIR)"
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(PROGRAM_NAME)"; \
	cp "$$BINARY_PATH" "$(ARCHIVE_BINARY)"
	cp README.md "$(ARCHIVE_DIR)/"
	cp transcriber.entitlements "$(ARCHIVE_DIR)/"

.PHONY: archive-app
archive-app: sign-app
	@echo "📱 Creating App release archive..."
	mkdir -p "$(ARCHIVE_DIR)"
	@BIN_PATH=$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path); \
	BINARY_PATH="$$BIN_PATH/$(APP_NAME)"; \
	cp "$$BINARY_PATH" "$(ARCHIVE_DIR)/$(APP_NAME)"
	@echo "#!/bin/bash" > "$(ARCHIVE_DIR)/install.sh"
	@echo "# Install script for $(PROGRAM_NAME) v$(VERSION)" >> "$(ARCHIVE_DIR)/install.sh"
	@echo "set -e" >> "$(ARCHIVE_DIR)/install.sh"
	@echo "echo \"Installing $(PROGRAM_NAME) v$(VERSION)...\"" >> "$(ARCHIVE_DIR)/install.sh"
	@echo "sudo cp $(PROGRAM_NAME) /usr/local/bin/" >> "$(ARCHIVE_DIR)/install.sh"
	@echo "echo \"✅ $(PROGRAM_NAME) installed to /usr/local/bin/\"" >> "$(ARCHIVE_DIR)/install.sh"
	@echo "echo \"Run '$(PROGRAM_NAME) --help' to get started\"" >> "$(ARCHIVE_DIR)/install.sh"
	chmod +x "$(ARCHIVE_DIR)/install.sh"

# Installation targets
.PHONY: install
install: sign
	@echo "📥 Installing $(PROGRAM_NAME) to /usr/local/bin/..."
	sudo cp "$(RELEASE_BINARY)" /usr/local/bin/
	@echo "✅ $(PROGRAM_NAME) installed successfully"
	@echo "Run '$(PROGRAM_NAME) --help' to get started"

.PHONY: uninstall
uninstall:
	@echo "🗑️  Uninstalling $(PROGRAM_NAME)..."
	sudo rm -f /usr/local/bin/$(PROGRAM_NAME)
	@echo "✅ $(PROGRAM_NAME) uninstalled"

# Development helpers
.PHONY: dev
dev: build
	@echo "🚀 Development build ready: $(BUILD_DIR)/debug/$(PROGRAM_NAME)"

.PHONY: run
run: build
	@echo "🏃 Running $(PROGRAM_NAME) (debug build)..."
	@echo "Usage: make run ARGS='--help' or make run ARGS='audio.mp3'"
	$(BUILD_DIR)/debug/$(PROGRAM_NAME) $(ARGS)

.PHONY: lint
lint:
	@echo "🔍 Running Swift format check..."
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format --version; \
		find Sources Tests -name "*.swift" -exec swift-format format --in-place {} \; ; \
		echo "✅ Swift format complete"; \
	else \
		echo "⚠️  swift-format not installed, skipping..."; \
	fi

# Release management
.PHONY: version
version:
	@echo "📋 Version Information:"
	@echo "   Current: $(VERSION)"
	@echo "   Git tag: $(GIT_VERSION)"
	@echo "   VERSION file: $(FILE_VERSION)"
	@if [ -n "$(RELEASE_VERSION)" ]; then \
		echo "   Release override: $(RELEASE_VERSION)"; \
	fi
	@echo ""
	@echo "💡 To update version:"
	@echo "  1. Create git tag: git tag v<version>"
	@echo "  2. Update VERSION file: make update-version-file"
	@echo "  3. Run 'make release' to build new version"

.PHONY: version-debug
version-debug:
	@echo "🔍 Detailed Version Debug Information:"
	@echo "   RELEASE_VERSION: '$(RELEASE_VERSION)'"
	@echo "   GIT_VERSION: '$(GIT_VERSION)'"
	@echo "   FILE_VERSION: '$(FILE_VERSION)'"
	@echo "   Final VERSION: '$(VERSION)'"
	@echo ""
	@echo "🔧 Version Resolution Logic:"
	@if [ -n "$(RELEASE_VERSION)" ]; then \
		echo "   ✅ Using RELEASE_VERSION override (CI/release build)"; \
	elif [ -n "$(GIT_VERSION)" ]; then \
		echo "   ✅ Using GIT_VERSION (development build)"; \
	elif [ -n "$(FILE_VERSION)" ]; then \
		echo "   ⚠️  Using FILE_VERSION fallback (no git tags)"; \
	else \
		echo "   ❌ No version source available"; \
	fi

.PHONY: version-info
version-info: version

.PHONY: update-version-file
update-version-file:
	@echo "📝 Updating VERSION file to match git tag..."
	@LATEST_TAG=$$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -n1 | sed 's/^v//' 2>/dev/null); \
	if [ -z "$$LATEST_TAG" ]; then \
		echo "❌ No git tags found - cannot update VERSION file"; \
		echo "   Create a git tag first: git tag v<version>"; \
		exit 1; \
	fi; \
	echo "$$LATEST_TAG" > $(VERSION_FILE); \
	echo "✅ VERSION file updated to $$LATEST_TAG"

.PHONY: tag
tag:
	@echo "🏷️  Creating git tag v$(VERSION)..."
	@if git tag | grep -q "v$(VERSION)"; then \
		echo "❌ Tag v$(VERSION) already exists"; \
		exit 1; \
	fi
	git add -A
	git commit -m "Release v$(VERSION)" || true
	git tag -a "v$(VERSION)" -m "Release version $(VERSION)"
	@echo "✅ Tag v$(VERSION) created"
	@echo "💡 Don't forget to:"
	@echo "  1. Push tag: git push origin v$(VERSION)"
	@echo "  2. Update VERSION file: make update-version-file"

# Info targets
.PHONY: info
info:
	@echo "📋 $(PROGRAM_NAME) Build Information"
	@echo "   Version: $(VERSION)"
	@echo "   Program: $(PROGRAM_NAME)"
	@echo "   Build Dir: $(BUILD_DIR)"
	@echo "   Release Dir: $(RELEASE_DIR)"
	@echo "   Entitlements: $(ENTITLEMENTS_FILE)"
	@echo ""
	@echo "🎯 Common Commands:"
	@echo "   make build       - Build CLI (debug)"
	@echo "   make build-app   - Build macOS App (debug)"
	@echo "   make build-all   - Build both CLI and App (debug)"
	@echo "   make test        - Run tests"
	@echo "   make release     - Full release build (both CLI and App)"
	@echo "   make release-cli - Release build CLI only"
	@echo "   make release-app - Release build App only"
	@echo "   make build-release-cli-intel  - Build Intel-only CLI"
	@echo "   make build-release-app-intel  - Build Intel-only App"
	@echo "   make installer   - Create macOS installer package (.pkg)"
	@echo "   make installer-production - Create signed installer (requires .env)"
	@echo "   make install     - Install CLI to /usr/local/bin"
	@echo "   make clean       - Clean build artifacts"
	@echo "   make info        - Show this information"
	@echo ""
	@echo "🔐 Code Signing Commands:"
	@echo "   make setup-self-signed   - Create self-signed certificates (no Apple account needed)"
	@echo "   make verify-certificates - Check Developer ID certificates"
	@echo "   make check-signing-environment - Show signing configuration"

.PHONY: size
size: build-release
	@echo "📊 Binary Size Information:"
	@ls -lh "$(RELEASE_BINARY)" | awk '{print "  Release binary: " $$5 " (" $$9 ")"}'
	@if [ -f "$(ARCHIVE_FILE)" ]; then \
		ls -lh "$(ARCHIVE_FILE)" | awk '{print "  Archive size:   " $$5 " (" $$9 ")"}'; \
	fi

# Installer targets
.PHONY: installer
installer: build-app-bundle create-installer

.PHONY: dmg
dmg: build-app-bundle create-dmg

.PHONY: build-app-bundle
build-app-bundle: build-release-app sign-app
	@echo "📱 Creating macOS app bundle..."
	$(INSTALLER_DIR)/build-scripts/build-app-bundle.sh

.PHONY: create-installer
create-installer: build-release-all sign-all
	@echo "📦 Creating macOS installer package..."
	$(INSTALLER_DIR)/build-scripts/create-installer.sh

.PHONY: create-dmg
create-dmg: build-release-all sign-all
	@echo "💿 Creating macOS DMG installer..."
	$(INSTALLER_DIR)/build-scripts/create-dmg.sh

.PHONY: installer-production
installer-production: check-signing-environment build-app-bundle create-installer
	@echo "🎁 Production installer created with code signing"
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "✅ Package signed with Developer ID and ready for distribution"; \
		echo "   Location: $(INSTALLER_PKG)"; \
		echo "   Test installation: sudo installer -pkg '$(INSTALLER_PKG)' -target /"; \
	else \
		echo "⚠️  Development package created - will be blocked by Gatekeeper"; \
		echo "   Set DEVELOPER_ID_INSTALLER in .env for production signing"; \
	fi

.PHONY: dmg-production
dmg-production: check-signing-environment build-app-bundle create-dmg
	@echo "💿 Production DMG created with code signing"
	@if [ "$(SIGNING_MODE)" = "production" ]; then \
		echo "✅ DMG signed with Developer ID and ready for distribution"; \
		echo "   Location: $(RELEASE_DIR)/Transcriber-$(VERSION).dmg"; \
		echo "   Test: hdiutil attach '$(RELEASE_DIR)/Transcriber-$(VERSION).dmg'"; \
	else \
		echo "⚠️  Development DMG created - may show Gatekeeper warnings"; \
		echo "   Set DEVELOPER_ID_APPLICATION in .env for production signing"; \
	fi

.PHONY: installer-clean
installer-clean:
	@echo "🧹 Cleaning installer build artifacts..."
	rm -rf $(INSTALLER_DIR)/build
	rm -f $(INSTALLER_PKG)
	rm -f $(RELEASE_DIR)/Transcriber-*.dmg

# Help target
.PHONY: help
help: info

# Ensure directories exist
$(BUILD_DIR) $(RELEASE_DIR) $(ARCHIVE_DIR):
	mkdir -p $@

# Dependencies
build-release: | $(BUILD_DIR)
archive: | $(RELEASE_DIR) $(ARCHIVE_DIR)
