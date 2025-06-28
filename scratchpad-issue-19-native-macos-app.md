# Issue #19: Create Native macOS App While Preserving CLI Functionality

**GitHub Issue:** https://github.com/jsonify/transcriber/issues/19  
**Date:** 2025-06-28  
**Status:** Planning Phase

## Overview

Convert the transcriber CLI into a dual-mode application that functions as both a traditional CLI tool and a native macOS application while maintaining feature parity and sharing core business logic.

## Current Architecture Analysis

### Strengths for Dual Architecture Implementation

1. **Perfect Separation**: TranscriberCore (business logic) vs TranscriberCLI (interface)
2. **Modern Swift Patterns**: Already uses `@MainActor`, `ObservableObject`, `@Published` properties
3. **Async/Await Throughout**: Perfect for reactive SwiftUI binding
4. **Progress Callback System**: Ready for UI progress indicators
5. **Configuration System**: YAML/JSON config easily adaptable to app preferences
6. **Comprehensive Error Handling**: With localized descriptions for UI display

### Current Package Structure
```
Products: [.executable(name: "transcriber", targets: ["TranscriberCLI"])]
Targets: [TranscriberCLI → TranscriberCore → Apple Frameworks]
Dependencies: ArgumentParser, Yams
```

## Implementation Plan

### Phase 1: Core Architecture Updates

#### 1.1 Update Package.swift
- Add new `.app` product for macOS application
- Create `TranscriberApp` target alongside existing `TranscriberCLI`
- Maintain existing CLI functionality unchanged
- Ensure both targets share `TranscriberCore`

```swift
products: [
    .executable(name: "transcriber", targets: ["TranscriberCLI"]),
    .app(name: "Transcriber", targets: ["TranscriberApp"])
]
```

#### 1.2 Create TranscriberApp Module Structure
```
Sources/TranscriberApp/
├── TranscriberApp.swift          # Main App entry point
├── ContentView.swift             # Primary app interface
├── Views/
│   ├── FilePickerView.swift      # Native file selection
│   ├── TranscriptionView.swift   # Main transcription interface
│   ├── ProgressView.swift        # Native progress indicators
│   ├── SettingsView.swift        # App preferences
│   └── ResultsView.swift         # Transcription results display
├── Models/
│   └── AppState.swift            # SwiftUI app state management
└── Resources/
    ├── Info.plist               # App bundle configuration
    └── Assets.xcassets          # App icons and images
```

### Phase 2: SwiftUI Implementation

#### 2.1 Main App Structure
- Use existing `SpeechTranscriber` ObservableObject directly in SwiftUI
- Leverage existing `@Published` properties for reactive UI
- Maintain same async/await patterns from CLI

#### 2.2 Key SwiftUI Views

**Main Content View:**
- File picker using native `NSOpenPanel` integration
- Configuration options matching CLI functionality
- Real-time progress display using existing progress callbacks
- Results display with format selection (TXT, JSON, SRT, VTT)

**Progress Integration:**
```swift
// Existing TranscriberCore already provides:
@Published public var isTranscribing = false
@Published public var progress: Double = 0.0
@Published public var progressMessage: String = ""

// Perfect for SwiftUI binding:
ProgressView(value: speechTranscriber.progress) {
    Text(speechTranscriber.progressMessage)
}
```

#### 2.3 Native macOS Features
- **Dark/Light Mode**: Automatic via SwiftUI
- **Window Management**: Standard macOS window controls
- **Menu Bar**: File, Edit, View, Help menus with keyboard shortcuts
- **Notifications**: System notifications for completion
- **File Handling**: Drag & drop support for audio/video files

### Phase 3: Shared Core Integration

#### 3.1 Configuration Management
- Extend `ConfigurationManager` to support app preferences
- Use same YAML/JSON config files for both CLI and App
- Add app-specific settings (window position, UI preferences)

#### 3.2 Unified Error Handling
- Existing error types work perfectly with SwiftUI alerts
- Maintain same error messages between CLI and App
- Add visual error presentation for App mode

### Phase 4: Build System Updates

#### 4.1 Makefile Modifications
- Add app building targets: `make app`, `make app-signed`
- Maintain existing CLI targets: `make cli`, `make install`
- Create unified release target: `make release` (builds both)

#### 4.2 Code Signing
- App requires different entitlements than CLI
- Speech Recognition permissions still needed
- App Sandbox considerations vs CLI flexibility

#### 4.3 Distribution
- CLI: Homebrew, direct download
- App: Mac App Store, notarized DMG
- Unified release process with both versions

### Phase 5: Testing Strategy

#### 5.1 Compatibility Testing
- Both CLI and App must produce identical results
- Same configuration files work with both versions
- Performance parity between modes

#### 5.2 UI Testing
- SwiftUI UI tests for app interface
- Accessibility testing for macOS standards
- Dark/light mode compatibility

#### 5.3 Integration Testing
- Cross-mode configuration compatibility
- Shared core functionality tests
- Build system validation

## Technical Implementation Details

### Shared Core Usage Pattern

Both CLI and App will use identical patterns:

```swift
// CLI usage (existing):
let transcriber = SpeechTranscriber()
transcriber.setProgressCallback(displayProgress)
let result = try await transcriber.transcribeAudioFile(...)

// App usage (new):
@StateObject private var transcriber = SpeechTranscriber()
// Automatic UI updates via @Published properties
let result = try await transcriber.transcribeAudioFile(...)
```

### Configuration Sharing

Both modes will use the same configuration files:
- CLI: `~/.transcriber.yaml` + command-line args
- App: Same files + app preferences for UI-specific settings

### File Format Compatibility

Both modes will produce identical output:
- Same `OutputFormatter` class used by both
- Same transcription algorithms and quality
- Same error handling and validation

## Risk Mitigation

### Backward Compatibility
- CLI interface remains 100% unchanged
- Existing scripts and automation continue working
- Same command-line arguments and behavior

### Code Quality
- Existing test suite continues to pass
- New UI tests added for app functionality
- Shared core ensures identical functionality

### Performance
- No performance regression for CLI usage
- App should match or exceed CLI performance
- Shared core minimizes code duplication

## Success Criteria

### CLI Preservation
- [x] All existing CLI functionality preserved
- [x] Backward compatibility maintained
- [x] Performance matches current implementation

### App Implementation
- [ ] Native macOS application launches and functions
- [ ] All CLI features available in graphical interface
- [ ] Follows Apple Human Interface Guidelines
- [ ] Dark/light mode support
- [ ] Standard macOS keyboard shortcuts

### Shared Functionality
- [ ] Identical transcription results from both modes
- [ ] Compatible configuration files
- [ ] Unified error handling
- [ ] Feature parity between CLI and App

## Next Steps

1. **Create branch**: `feature/native-macos-app`
2. **Update Package.swift**: Add app target alongside CLI
3. **Implement core SwiftUI views**: Leverage existing ObservableObject patterns
4. **Test integration**: Ensure shared core works seamlessly
5. **Update build system**: Support dual-mode builds
6. **Comprehensive testing**: UI tests and compatibility verification
7. **Documentation updates**: README and user guides

## Notes

- The existing architecture is exceptionally well-designed for this enhancement
- ObservableObject pattern in TranscriberCore is perfect for SwiftUI binding
- Clean separation between Core and CLI makes app implementation straightforward
- Async/await throughout the codebase aligns perfectly with modern SwiftUI patterns
- Configuration system is already modular and extensible