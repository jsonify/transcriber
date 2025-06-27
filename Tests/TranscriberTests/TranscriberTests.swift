import XCTest
@testable import TranscriberCore

final class TranscriberTests: XCTestCase {
    
    func testTranscriptionResultCreation() {
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0.0, endTime: 1.0, confidence: 0.9),
            TranscriptionSegment(text: "World", startTime: 1.0, endTime: 2.0, confidence: 0.8)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.fullText, "Hello World")
        XCTAssertEqual(result.duration, 2.0)
        XCTAssertEqual(result.language, "en-US")
        XCTAssertTrue(result.isOnDevice)
        XCTAssertEqual(result.averageConfidence, 0.85, accuracy: 0.01)
    }
    
    func testOutputFormatterText() {
        let segments = [
            TranscriptionSegment(text: "Hello World", startTime: 0.0, endTime: 2.0, confidence: 0.9)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        let textOutput = OutputFormatter.format(result, as: .text)
        XCTAssertEqual(textOutput, "Hello World")
    }
    
    func testOutputFormatterSRT() {
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0.0, endTime: 1.0, confidence: 0.9),
            TranscriptionSegment(text: "World", startTime: 1.0, endTime: 2.0, confidence: 0.8)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        let srtOutput = OutputFormatter.format(result, as: .srt)
        
        XCTAssertTrue(srtOutput.contains("1"))
        XCTAssertTrue(srtOutput.contains("00:00:00,000 --> 00:00:01,000"))
        XCTAssertTrue(srtOutput.contains("Hello"))
        XCTAssertTrue(srtOutput.contains("2"))
        XCTAssertTrue(srtOutput.contains("00:00:01,000 --> 00:00:02,000"))
        XCTAssertTrue(srtOutput.contains("World"))
    }
    
    func testOutputFormatterVTT() {
        let segments = [
            TranscriptionSegment(text: "Hello World", startTime: 0.0, endTime: 2.5, confidence: 0.9)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.5,
            language: "en-US",
            isOnDevice: true
        )
        
        let vttOutput = OutputFormatter.format(result, as: .vtt)
        
        XCTAssertTrue(vttOutput.hasPrefix("WEBVTT"))
        XCTAssertTrue(vttOutput.contains("00:00.000 --> 00:02.500"))
        XCTAssertTrue(vttOutput.contains("Hello World"))
    }
    
    func testOutputFormatterJSON() {
        let segments = [
            TranscriptionSegment(text: "Test", startTime: 0.0, endTime: 1.0, confidence: 0.95)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Test",
            duration: 1.0,
            language: "en-US",
            isOnDevice: false
        )
        
        let jsonOutput = OutputFormatter.format(result, as: .json)
        
        XCTAssertTrue(jsonOutput.contains("\"text\" : \"Test\""))
        XCTAssertTrue(jsonOutput.contains("\"language\" : \"en-US\""))
        XCTAssertTrue(jsonOutput.contains("\"duration\" : 1"))
        XCTAssertTrue(jsonOutput.contains("\"isOnDevice\" : false"))
        XCTAssertTrue(jsonOutput.contains("segments"))
    }
    
    func testTranscriptionErrors() {
        let fileNotFoundError = TranscriptionError.fileNotFound("/path/to/missing.wav")
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("not found"))
        
        let unsupportedFormatError = TranscriptionError.unsupportedFormat("xyz")
        XCTAssertTrue(unsupportedFormatError.localizedDescription.contains("Unsupported"))
        
        let permissionError = TranscriptionError.speechRecognitionDenied
        XCTAssertTrue(permissionError.localizedDescription.contains("permission"))
    }
    
    func testOutputFormatCases() {
        XCTAssertEqual(OutputFormat.text.fileExtension, "txt")
        XCTAssertEqual(OutputFormat.json.fileExtension, "json")
        XCTAssertEqual(OutputFormat.srt.fileExtension, "srt")
        XCTAssertEqual(OutputFormat.vtt.fileExtension, "vtt")
        
        XCTAssertEqual(OutputFormat.allCases.count, 4)
    }
    
    // MARK: - Configuration Tests
    
    func testTranscriberConfigurationCreation() {
        let config = TranscriberConfiguration(
            language: "es-ES",
            format: "json",
            onDevice: true,
            outputDir: "/test/output",
            verbose: true,
            showProgress: true,
            noColor: false
        )
        
        XCTAssertEqual(config.language, "es-ES")
        XCTAssertEqual(config.format, "json")
        XCTAssertEqual(config.onDevice, true)
        XCTAssertEqual(config.outputDir, "/test/output")
        XCTAssertEqual(config.verbose, true)
        XCTAssertEqual(config.showProgress, true)
        XCTAssertEqual(config.noColor, false)
    }
    
    func testTranscriberConfigurationDefaults() {
        let config = TranscriberConfiguration.defaultConfiguration
        
        XCTAssertEqual(config.language, "en-US")
        XCTAssertEqual(config.format, "txt")
        XCTAssertEqual(config.onDevice, false)
        XCTAssertNil(config.outputDir)
        XCTAssertEqual(config.verbose, false)
        XCTAssertEqual(config.showProgress, false)
        XCTAssertEqual(config.noColor, false)
    }
    
    func testTranscriberConfigurationMerging() {
        let baseConfig = TranscriberConfiguration(
            language: "en-US",
            format: "txt",
            onDevice: false,
            outputDir: nil,
            verbose: false,
            showProgress: false,
            noColor: false
        )
        
        let overrideConfig = TranscriberConfiguration(
            language: "es-ES",
            format: nil,
            onDevice: true,
            outputDir: "/test",
            verbose: nil,
            showProgress: true,
            noColor: nil
        )
        
        let merged = baseConfig.merged(with: overrideConfig)
        
        XCTAssertEqual(merged.language, "es-ES")
        XCTAssertEqual(merged.format, "txt") 
        XCTAssertEqual(merged.onDevice, true)
        XCTAssertEqual(merged.outputDir, "/test")
        XCTAssertEqual(merged.verbose, false)
        XCTAssertEqual(merged.showProgress, true)
        XCTAssertEqual(merged.noColor, false)
    }
    
    func testConfigurationManagerLoadNonExistentFile() {
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration(customConfigPath: "/non/existent/config.yaml")
        
        XCTAssertEqual(config.language, "en-US")
        XCTAssertEqual(config.format, "txt")
    }
    
    func testConfigurationManagerValidation() {
        let configManager = ConfigurationManager()
        
        let validConfig = TranscriberConfiguration(
            language: "en-US",
            format: "txt",
            onDevice: false,
            outputDir: nil,
            verbose: false,
            showProgress: false,
            noColor: false
        )
        
        let validationErrors = configManager.validateConfiguration(validConfig)
        XCTAssertTrue(validationErrors.isEmpty)
        
        let invalidConfig = TranscriberConfiguration(
            language: "en-US",
            format: "invalid",
            onDevice: false,
            outputDir: nil,
            verbose: false,
            showProgress: false,
            noColor: false
        )
        
        let invalidErrors = configManager.validateConfiguration(invalidConfig)
        XCTAssertFalse(invalidErrors.isEmpty)
        XCTAssertTrue(invalidErrors[0].contains("Invalid format 'invalid'"))
    }
    
    func testConfigurationSampleGeneration() {
        let config = TranscriberConfiguration.defaultConfiguration
        
        let yamlSample = config.asSampleYAML()
        XCTAssertTrue(yamlSample.contains("language: \"en-US\""))
        XCTAssertTrue(yamlSample.contains("format: \"txt\""))
        XCTAssertTrue(yamlSample.contains("onDevice: false"))
        XCTAssertTrue(yamlSample.contains("verbose: false"))
        XCTAssertTrue(yamlSample.contains("showProgress: false"))
        XCTAssertTrue(yamlSample.contains("noColor: false"))
        
        let jsonSample = config.asSampleJSON()
        XCTAssertTrue(jsonSample.contains("\"language\": \"en-US\""))
        XCTAssertTrue(jsonSample.contains("\"format\": \"txt\""))
        XCTAssertTrue(jsonSample.contains("\"onDevice\": false"))
    }
    
    func testConfigurationManagerGenerateSampleFiles() {
        let configManager = ConfigurationManager()
        let tempDir = FileManager.default.temporaryDirectory
        
        let yamlPath = tempDir.appendingPathComponent("test.transcriber.yaml").path
        let jsonPath = tempDir.appendingPathComponent("test.transcriber.json").path
        
        do {
            try configManager.generateSampleConfiguration(format: "yaml", at: yamlPath)
            try configManager.generateSampleConfiguration(format: "json", at: jsonPath)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: yamlPath))
            XCTAssertTrue(FileManager.default.fileExists(atPath: jsonPath))
            
            let yamlContent = try String(contentsOfFile: yamlPath)
            let jsonContent = try String(contentsOfFile: jsonPath)
            
            XCTAssertTrue(yamlContent.contains("language: \"en-US\""))
            XCTAssertTrue(jsonContent.contains("\"language\": \"en-US\""))
            
            try? FileManager.default.removeItem(atPath: yamlPath)
            try? FileManager.default.removeItem(atPath: jsonPath)
            
        } catch {
            XCTFail("Failed to generate sample configuration files: \(error)")
        }
    }
    
    func testConfigurationManagerUnsupportedFormat() {
        let configManager = ConfigurationManager()
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("test.config").path
        
        XCTAssertThrowsError(try configManager.generateSampleConfiguration(format: "xml", at: tempPath)) { error in
            if let configError = error as? ConfigurationManager.ConfigurationError {
                switch configError {
                case .unsupportedFormat(let format):
                    XCTAssertEqual(format, "xml")
                default:
                    XCTFail("Expected unsupportedFormat error")
                }
            } else {
                XCTFail("Expected ConfigurationError")
            }
        }
    }
    
    func testConfigurationFileLoadingJSON() {
        let configManager = ConfigurationManager()
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-config.json").path
        
        let testConfigContent = """
        {
            "language": "fr-FR",
            "format": "srt",
            "onDevice": true,
            "verbose": true,
            "showProgress": true,
            "noColor": false
        }
        """
        
        do {
            try testConfigContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            
            let loadedConfig = configManager.loadConfiguration(customConfigPath: configPath)
            
            XCTAssertEqual(loadedConfig.language, "fr-FR")
            XCTAssertEqual(loadedConfig.format, "srt")
            XCTAssertEqual(loadedConfig.onDevice, true)
            XCTAssertEqual(loadedConfig.verbose, true)
            XCTAssertEqual(loadedConfig.showProgress, true)
            XCTAssertEqual(loadedConfig.noColor, false)
            
            try? FileManager.default.removeItem(atPath: configPath)
            
        } catch {
            XCTFail("Failed to test JSON configuration loading: \(error)")
        }
    }
    
    func testConfigurationFileLoadingYAML() {
        let configManager = ConfigurationManager()
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-config.yaml").path
        
        let testConfigContent = """
        language: "de-DE"
        format: "vtt"
        onDevice: false
        outputDir: "/tmp/transcripts"
        verbose: false
        showProgress: true
        noColor: true
        """
        
        do {
            try testConfigContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            
            let loadedConfig = configManager.loadConfiguration(customConfigPath: configPath)
            
            XCTAssertEqual(loadedConfig.language, "de-DE")
            XCTAssertEqual(loadedConfig.format, "vtt")
            XCTAssertEqual(loadedConfig.onDevice, false)
            XCTAssertEqual(loadedConfig.outputDir, "/tmp/transcripts")
            XCTAssertEqual(loadedConfig.verbose, false)
            XCTAssertEqual(loadedConfig.showProgress, true)
            XCTAssertEqual(loadedConfig.noColor, true)
            
            try? FileManager.default.removeItem(atPath: configPath)
            
        } catch {
            XCTFail("Failed to test YAML configuration loading: \(error)")
        }
    }
}