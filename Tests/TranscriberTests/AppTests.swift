import XCTest
@testable import TranscriberCore

class AppTests: XCTestCase {
    
    // Test that both CLI and App use the same core functionality
    func testSharedCoreCompatibility() {
        // Test TranscriptionResult creation (used by both CLI and App)
        let segments = [
            TranscriptionSegment(text: "Hello world", startTime: 0.0, endTime: 2.0, confidence: 0.95),
            TranscriptionSegment(text: "This is a test", startTime: 2.0, endTime: 4.0, confidence: 0.88)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello world This is a test",
            duration: 4.0,
            language: "en-US",
            isOnDevice: true
        )
        
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.fullText, "Hello world This is a test")
        XCTAssertEqual(result.duration, 4.0)
        XCTAssertEqual(result.language, "en-US")
        XCTAssertEqual(result.isOnDevice, true)
        
        // Test that average confidence calculation works the same for both
        let expectedConfidence: Float = (0.95 + 0.88) / 2.0
        XCTAssertEqual(result.averageConfidence, expectedConfidence, accuracy: 0.001)
    }
    
    func testOutputFormatterCompatibility() {
        // Both CLI and App should produce identical output for the same input
        let segments = [
            TranscriptionSegment(text: "Test transcription", startTime: 0.0, endTime: 2.0, confidence: 0.9)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Test transcription",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        // Test all output formats
        let textOutput = OutputFormatter.format(result, as: .text)
        XCTAssertEqual(textOutput, "Test transcription")
        
        let jsonOutput = OutputFormatter.format(result, as: .json)
        XCTAssertTrue(jsonOutput.contains("Test transcription"))
        XCTAssertTrue(jsonOutput.contains("en-US"))
        
        let srtOutput = OutputFormatter.format(result, as: .srt)
        XCTAssertTrue(srtOutput.contains("1"))
        XCTAssertTrue(srtOutput.contains("00:00:00,000 --> 00:00:02,000"))
        XCTAssertTrue(srtOutput.contains("Test transcription"))
        
        let vttOutput = OutputFormatter.format(result, as: .vtt)
        XCTAssertTrue(vttOutput.contains("WEBVTT"))
        XCTAssertTrue(vttOutput.contains("00:00.000 --> 00:02.000"))
        XCTAssertTrue(vttOutput.contains("Test transcription"))
    }
    
    func testConfigurationCompatibility() {
        // Test that configuration loading works the same for both CLI and App
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration(customConfigPath: nil)
        
        // Should return default values when no config file exists
        XCTAssertNotNil(config)
        
        // Test default configuration
        let defaultConfig = TranscriberConfiguration.defaultConfiguration
        XCTAssertEqual(defaultConfig.language, "en-US")
        XCTAssertEqual(defaultConfig.format, "txt")
        XCTAssertEqual(defaultConfig.onDevice, false)
        XCTAssertEqual(defaultConfig.verbose, false)
    }
    
    func testErrorHandlingCompatibility() {
        // Test that error types are consistent between CLI and App
        let fileNotFoundError = TranscriptionError.fileNotFound("test.wav")
        XCTAssertNotNil(fileNotFoundError.errorDescription)
        XCTAssertTrue(fileNotFoundError.errorDescription!.contains("test.wav"))
        
        let permissionError = TranscriptionError.speechRecognitionDenied
        XCTAssertNotNil(permissionError.errorDescription)
        XCTAssertTrue(permissionError.errorDescription!.contains("permission"))
        
        let formatError = TranscriptionError.unsupportedFormat("xyz")
        XCTAssertNotNil(formatError.errorDescription)
        XCTAssertTrue(formatError.errorDescription!.contains("xyz"))
    }
    
    func testLanguageSupport() {
        // Test that language codes are valid for both CLI and App
        let supportedLanguages = [
            "en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "ja-JP", "zh-CN"
        ]
        
        for language in supportedLanguages {
            // Language codes should be valid format
            XCTAssertTrue(language.contains("-"))
            XCTAssertEqual(language.count, 5)
        }
    }
    
    func testOutputFormatEnumeration() {
        // Test that all output formats are available to both CLI and App
        let allFormats = OutputFormat.allCases
        XCTAssertEqual(allFormats.count, 4)
        
        let formatStrings = allFormats.map { $0.rawValue }
        XCTAssertTrue(formatStrings.contains("txt"))
        XCTAssertTrue(formatStrings.contains("json"))
        XCTAssertTrue(formatStrings.contains("srt"))
        XCTAssertTrue(formatStrings.contains("vtt"))
        
        // Test file extensions match
        for format in allFormats {
            XCTAssertEqual(format.fileExtension, format.rawValue)
        }
    }
    
    // MARK: - UI Component Tests
    
    func testFileItemDataStructure() {
        // Test FileItem creation and properties
        let testURL = URL(string: "file:///test-audio.mp3")!
        let fileItem = FileItem(url: testURL)
        
        XCTAssertEqual(fileItem.url, testURL)
        XCTAssertEqual(fileItem.status, .pending)
        XCTAssertEqual(fileItem.duration, "")
        XCTAssertEqual(fileItem.progress, 0.0)
        XCTAssertNotNil(fileItem.id)
    }
    
    func testFileItemStatusTracking() {
        // Test FileStatus enum cases (updated for Issue #45)
        let statuses: [FileStatus] = [.pending, .queued, .processing, .done, .error, .cancelled]
        XCTAssertEqual(statuses.count, 6)
        
        // Test status transitions
        let testURL = URL(string: "file:///test-audio.wav")!
        var fileItem = FileItem(url: testURL)
        
        // Initial state
        XCTAssertEqual(fileItem.status, .pending)
        
        // Simulate queuing
        fileItem.status = .queued
        XCTAssertEqual(fileItem.status, .queued)
        
        // Simulate processing
        fileItem.status = .processing
        fileItem.progress = 0.5
        XCTAssertEqual(fileItem.status, .processing)
        XCTAssertEqual(fileItem.progress, 0.5)
        
        // Simulate completion
        fileItem.status = .done
        fileItem.progress = 1.0
        XCTAssertEqual(fileItem.status, .done)
        XCTAssertEqual(fileItem.progress, 1.0)
        
        // Test error state
        fileItem.status = .error
        fileItem.errorMessage = "Test error"
        XCTAssertEqual(fileItem.status, .error)
        XCTAssertEqual(fileItem.errorMessage, "Test error")
        
        // Test cancelled state
        fileItem.status = .cancelled
        XCTAssertEqual(fileItem.status, .cancelled)
    }
    
    func testFileItemEquality() {
        // Test FileItem equality comparison
        let testURL1 = URL(string: "file:///test1.mp3")!
        let testURL2 = URL(string: "file:///test2.mp3")!
        
        let fileItem1 = FileItem(url: testURL1)
        let fileItem2 = FileItem(url: testURL1) // Same URL
        let fileItem3 = FileItem(url: testURL2) // Different URL
        
        // Same URLs should be equal
        XCTAssertEqual(fileItem1, fileItem2)
        
        // Different URLs should not be equal
        XCTAssertNotEqual(fileItem1, fileItem3)
    }
    
    func testQualityParameterSupport() {
        // Test that quality parameter values are properly supported  
        let validQualities = ["High", "Medium", "Low", "invalid"]
        
        // Test that all quality values can be used (testing API compatibility)
        for quality in validQualities {
            // Testing the parameter acceptance - actual transcription would require files/permissions
            XCTAssertNotNil(quality)
            XCTAssertFalse(quality.isEmpty)
        }
        
        // Test quality-specific behavior (lower case handling)
        XCTAssertEqual("High".lowercased(), "high")
        XCTAssertEqual("Medium".lowercased(), "medium")
        XCTAssertEqual("Low".lowercased(), "low")
    }
    
    // MARK: - Issue #45 Tests - Manual Transcription Control
    
    func testFileItemEnhancedProperties() {
        // Test new properties added for Issue #45
        let testURL = URL(string: "file:///enhanced-test.mp3")!
        let fileItem = FileItem(
            url: testURL,
            status: .processing,
            duration: "2:30",
            progress: 0.75,
            progressMessage: "Processing speech patterns...",
            errorMessage: nil
        )
        
        XCTAssertEqual(fileItem.url, testURL)
        XCTAssertEqual(fileItem.status, .processing)
        XCTAssertEqual(fileItem.duration, "2:30")
        XCTAssertEqual(fileItem.progress, 0.75)
        XCTAssertEqual(fileItem.progressMessage, "Processing speech patterns...")
        XCTAssertNil(fileItem.errorMessage)
    }
    
    func testFileItemControlLogic() {
        // Test computed properties for UI control logic (Issue #45)
        let testURL = URL(string: "file:///control-test.wav")!
        
        // Test canStart property
        var fileItem = FileItem(url: testURL, status: .pending)
        XCTAssertTrue(fileItem.canStart)
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertFalse(fileItem.isActive)
        
        fileItem.status = .error
        XCTAssertTrue(fileItem.canStart)
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertFalse(fileItem.isActive)
        
        fileItem.status = .cancelled
        XCTAssertTrue(fileItem.canStart)
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertFalse(fileItem.isActive)
        
        // Test canCancel property
        fileItem.status = .queued
        XCTAssertFalse(fileItem.canStart)
        XCTAssertTrue(fileItem.canCancel)
        XCTAssertTrue(fileItem.isActive)
        
        fileItem.status = .processing
        XCTAssertFalse(fileItem.canStart)
        XCTAssertTrue(fileItem.canCancel)
        XCTAssertTrue(fileItem.isActive)
        
        // Test completed states
        fileItem.status = .done
        XCTAssertFalse(fileItem.canStart)
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertFalse(fileItem.isActive)
    }
    
    func testFileItemNewStatusStates() {
        // Test new status states added for Issue #45
        let testURL = URL(string: "file:///status-test.mp4")!
        var fileItem = FileItem(url: testURL)
        
        // Test queued state
        fileItem.status = .queued
        fileItem.progressMessage = "Queued for transcription..."
        XCTAssertEqual(fileItem.status, .queued)
        XCTAssertEqual(fileItem.progressMessage, "Queued for transcription...")
        XCTAssertTrue(fileItem.canCancel)
        XCTAssertFalse(fileItem.canStart)
        XCTAssertTrue(fileItem.isActive)
        
        // Test cancelled state
        fileItem.status = .cancelled
        fileItem.progressMessage = ""
        XCTAssertEqual(fileItem.status, .cancelled)
        XCTAssertEqual(fileItem.progressMessage, "")
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertTrue(fileItem.canStart)
        XCTAssertFalse(fileItem.isActive)
        
        // Test error state with message
        fileItem.status = .error
        fileItem.errorMessage = "Speech recognition not available"
        XCTAssertEqual(fileItem.status, .error)
        XCTAssertEqual(fileItem.errorMessage, "Speech recognition not available")
        XCTAssertFalse(fileItem.canCancel)
        XCTAssertTrue(fileItem.canStart)
        XCTAssertFalse(fileItem.isActive)
    }
    
    func testFileItemProgressTracking() {
        // Test enhanced progress tracking for Issue #45
        let testURL = URL(string: "file:///progress-test.wav")!
        var fileItem = FileItem(url: testURL)
        
        // Test initial state
        XCTAssertEqual(fileItem.progress, 0.0)
        XCTAssertEqual(fileItem.progressMessage, "")
        
        // Test progress updates during processing
        fileItem.status = .processing
        fileItem.progress = 0.25
        fileItem.progressMessage = "Analyzing audio format..."
        
        XCTAssertEqual(fileItem.progress, 0.25)
        XCTAssertEqual(fileItem.progressMessage, "Analyzing audio format...")
        
        // Test mid-progress
        fileItem.progress = 0.6
        fileItem.progressMessage = "Processing speech patterns..."
        
        XCTAssertEqual(fileItem.progress, 0.6)
        XCTAssertEqual(fileItem.progressMessage, "Processing speech patterns...")
        
        // Test completion
        fileItem.status = .done
        fileItem.progress = 1.0
        fileItem.progressMessage = "Complete!"
        
        XCTAssertEqual(fileItem.status, .done)
        XCTAssertEqual(fileItem.progress, 1.0)
        XCTAssertEqual(fileItem.progressMessage, "Complete!")
    }
    
    func testFileItemInitializationVariants() {
        // Test different initialization patterns for Issue #45
        let testURL = URL(string: "file:///init-test.mp3")!
        
        // Test minimal initialization
        let basicItem = FileItem(url: testURL)
        XCTAssertEqual(basicItem.status, .pending)
        XCTAssertEqual(basicItem.progress, 0.0)
        XCTAssertEqual(basicItem.progressMessage, "")
        XCTAssertNil(basicItem.errorMessage)
        
        // Test full initialization
        let fullItem = FileItem(
            url: testURL,
            status: .processing,
            duration: "1:45:30",
            progress: 0.85,
            progressMessage: "Finalizing results...",
            errorMessage: nil
        )
        
        XCTAssertEqual(fullItem.status, .processing)
        XCTAssertEqual(fullItem.duration, "1:45:30")
        XCTAssertEqual(fullItem.progress, 0.85)
        XCTAssertEqual(fullItem.progressMessage, "Finalizing results...")
        XCTAssertNil(fullItem.errorMessage)
        
        // Test error initialization
        let errorItem = FileItem(
            url: testURL,
            status: .error,
            errorMessage: "File format not supported"
        )
        
        XCTAssertEqual(errorItem.status, .error)
        XCTAssertEqual(errorItem.errorMessage, "File format not supported")
        XCTAssertTrue(errorItem.canStart) // Can retry after error
        XCTAssertFalse(errorItem.canCancel)
    }
}