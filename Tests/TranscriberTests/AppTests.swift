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
}