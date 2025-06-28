# Makefile for Transcriber
# Modern macOS Speech Recognition CLI Tool

# Project Configuration
PROGRAM_NAME := transcriber
APP_NAME := TranscriberApp
# Get version from git tag, fallback to 1.0.1 if no tags exist
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.1")
# Fallback if VERSION is empty
ifeq ($(VERSION),)
VERSION := 1.0.1
endif
BUILD_DIR := .build
RELEASE_DIR := releases
ARCHIVE_DIR := $(RELEASE_DIR)/$(PROGRAM_NAME)-$(VERSION)

# Build Configuration
SWIFT_BUILD_FLAGS := -c release --disable-sandbox
ENTITLEMENTS_FILE := transcriber.entitlements

# Derived Paths
RELEASE_BINARY := $(BUILD_DIR)/x86_64-apple-macosx/release/$(PROGRAM_NAME)
RELEASE_APP := $(BUILD_DIR)/x86_64-apple-macosx/release/$(APP_NAME)
ARCHIVE_BINARY := $(ARCHIVE_DIR)/$(PROGRAM_NAME)
ARCHIVE_APP := $(ARCHIVE_DIR)/$(APP_NAME).app
ARCHIVE_FILE := $(RELEASE_DIR)/$(PROGRAM_NAME)-$(VERSION).zip

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
release: clean build-release-all sign-all test-release archive

.PHONY: release-cli
release-cli: clean build-release-cli sign test-release archive-cli

.PHONY: release-app
release-app: clean build-release-app sign-app archive-app

.PHONY: build-release-cli
build-release-cli:
	@echo "📦 Building $(PROGRAM_NAME) CLI v$(VERSION) (release)..."
	swift build $(SWIFT_BUILD_FLAGS) --product $(PROGRAM_NAME)
	@if [ ! -f "$(RELEASE_BINARY)" ]; then \
		echo "❌ CLI build failed - binary not found"; \
		exit 1; \
	fi
	@echo "✅ CLI release build complete"

.PHONY: build-release-app
build-release-app:
	@echo "📱 Building $(APP_NAME) v$(VERSION) (release)..."
	swift build $(SWIFT_BUILD_FLAGS) --product $(APP_NAME)
	@if [ ! -f "$(RELEASE_APP)" ]; then \
		echo "❌ App build failed - binary not found"; \
		exit 1; \
	fi
	@echo "✅ App release build complete"

.PHONY: build-release-all
build-release-all: build-release-cli build-release-app
	@echo "✅ Both CLI and App release builds complete"

# Legacy target for backward compatibility
.PHONY: build-release
build-release: build-release-cli

.PHONY: sign
sign: build-release-cli
	@echo "🔐 Code signing CLI with Speech Recognition entitlements..."
	@if [ ! -f "$(ENTITLEMENTS_FILE)" ]; then \
		echo "❌ Entitlements file not found: $(ENTITLEMENTS_FILE)"; \
		exit 1; \
	fi
	codesign --remove-signature "$(RELEASE_BINARY)" 2>/dev/null || true
	codesign --force \
	         --sign - \
	         --entitlements "$(ENTITLEMENTS_FILE)" \
	         --options runtime \
	         "$(RELEASE_BINARY)"
	@echo "✅ CLI code signing complete"

.PHONY: sign-app
sign-app: build-release-app
	@echo "🔐 Code signing App with Speech Recognition entitlements..."
	@if [ ! -f "$(ENTITLEMENTS_FILE)" ]; then \
		echo "❌ Entitlements file not found: $(ENTITLEMENTS_FILE)"; \
		exit 1; \
	fi
	codesign --remove-signature "$(RELEASE_APP)" 2>/dev/null || true
	codesign --force \
	         --sign - \
	         --entitlements "$(ENTITLEMENTS_FILE)" \
	         --options runtime \
	         "$(RELEASE_APP)"
	@echo "✅ App code signing complete"

.PHONY: sign-all
sign-all: sign sign-app
	@echo "✅ Both CLI and App code signing complete"

.PHONY: verify
verify: sign
	@echo "🔍 Verifying signature and entitlements..."
	codesign -v "$(RELEASE_BINARY)"
	codesign -d --entitlements - "$(RELEASE_BINARY)" > /dev/null 2>&1
	@echo "✅ Signature verification complete"

.PHONY: test-release
test-release: verify
	@echo "🧪 Testing release binary..."
	@echo "  • Testing help output..."
	@"$(RELEASE_BINARY)" --help > /dev/null
	@echo "  • Testing version output..."
	@"$(RELEASE_BINARY)" --version > /dev/null
	@echo "  • Testing language listing..."
	@timeout 30s "$(RELEASE_BINARY)" --list-languages > /dev/null 2>&1 || true
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
	cp "$(RELEASE_BINARY)" "$(ARCHIVE_BINARY)"
	cp README.md "$(ARCHIVE_DIR)/"
	cp transcriber.entitlements "$(ARCHIVE_DIR)/"

.PHONY: archive-app
archive-app: sign-app
	@echo "📱 Creating App release archive..."
	mkdir -p "$(ARCHIVE_DIR)"
	cp "$(RELEASE_APP)" "$(ARCHIVE_DIR)/$(APP_NAME)"
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
	@echo "Current version: $(VERSION)"
	@echo "To update version:"
	@echo "  1. Update VERSION in Makefile"
	@echo "  2. Update version in Sources/TranscriberCLI/main.swift"
	@echo "  3. Run 'make release' to build new version"

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
	@echo "Push with: git push origin v$(VERSION)"

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
	@echo "   make install     - Install CLI to /usr/local/bin"
	@echo "   make clean       - Clean build artifacts"
	@echo "   make info        - Show this information"

.PHONY: size
size: build-release
	@echo "📊 Binary Size Information:"
	@ls -lh "$(RELEASE_BINARY)" | awk '{print "  Release binary: " $$5 " (" $$9 ")"}'
	@if [ -f "$(ARCHIVE_FILE)" ]; then \
		ls -lh "$(ARCHIVE_FILE)" | awk '{print "  Archive size:   " $$5 " (" $$9 ")"}'; \
	fi

# Help target
.PHONY: help
help: info

# Ensure directories exist
$(BUILD_DIR) $(RELEASE_DIR) $(ARCHIVE_DIR):
	mkdir -p $@

# Dependencies
build-release: | $(BUILD_DIR)
archive: | $(RELEASE_DIR) $(ARCHIVE_DIR)
