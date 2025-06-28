import XCTest
@testable import TranscriberCore

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}

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
    
    func testVersionFileReadability() {
        // Test that VERSION file exists and can be read
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let versionFileURL = currentDirectoryURL.appendingPathComponent("VERSION")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: versionFileURL.path), 
                      "VERSION file should exist in project root")
        
        do {
            let versionContent = try String(contentsOf: versionFileURL, encoding: .utf8)
            let trimmedVersion = versionContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            XCTAssertFalse(trimmedVersion.isEmpty, "VERSION file should not be empty")
            XCTAssertTrue(trimmedVersion.matches(#"^\d+\.\d+\.\d+$"#), 
                          "VERSION file should contain semantic version format (e.g., 2.2.0)")
            
            // Verify it's a valid semantic version (don't hardcode specific version)
            let versionComponents = trimmedVersion.split(separator: ".")
            XCTAssertEqual(versionComponents.count, 3, "VERSION should have exactly 3 components (major.minor.patch)")
            
            // Verify each component is a valid number
            for component in versionComponents {
                XCTAssertNotNil(Int(component), "Each version component should be a valid number")
            }
            
        } catch {
            XCTFail("Failed to read VERSION file: \(error)")
        }
    }
    
    func testCodeSigningConfigurationTemplate() {
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let envExampleURL = currentDirectoryURL.appendingPathComponent(".env.example")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: envExampleURL.path), 
                      ".env.example file should exist in project root")
        
        do {
            let envContent = try String(contentsOf: envExampleURL, encoding: .utf8)
            
            // Verify essential configuration keys are documented
            XCTAssertTrue(envContent.contains("DEVELOPER_ID_APPLICATION"), 
                         ".env.example should document DEVELOPER_ID_APPLICATION")
            XCTAssertTrue(envContent.contains("DEVELOPER_ID_INSTALLER"), 
                         ".env.example should document DEVELOPER_ID_INSTALLER")
            XCTAssertTrue(envContent.contains("KEYCHAIN_PROFILE"), 
                         ".env.example should document KEYCHAIN_PROFILE")
            XCTAssertTrue(envContent.contains("SIGNING_IDENTITY"), 
                         ".env.example should document SIGNING_IDENTITY")
            XCTAssertTrue(envContent.contains("SKIP_NOTARIZATION"), 
                         ".env.example should document SKIP_NOTARIZATION")
            
            // Verify setup instructions are present
            XCTAssertTrue(envContent.contains("SETUP INSTRUCTIONS"), 
                         ".env.example should contain setup instructions")
            XCTAssertTrue(envContent.contains("Apple Developer"), 
                         ".env.example should reference Apple Developer requirements")
            XCTAssertTrue(envContent.contains("notarytool"), 
                         ".env.example should document notarization setup")
            
        } catch {
            XCTFail("Should be able to read .env.example file: \(error)")
        }
    }
    
    func testSigningScriptsExist() {
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let scriptsDir = currentDirectoryURL.appendingPathComponent("scripts")
        
        // Verify signing helper scripts exist
        let setupScript = scriptsDir.appendingPathComponent("setup-signing.sh")
        let verifyScript = scriptsDir.appendingPathComponent("verify-signing.sh")
        let buildScript = scriptsDir.appendingPathComponent("build-production.sh")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: setupScript.path), 
                     "setup-signing.sh script should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: verifyScript.path), 
                     "verify-signing.sh script should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: buildScript.path), 
                     "build-production.sh script should exist")
        
        // Verify scripts are executable
        do {
            let setupAttrs = try FileManager.default.attributesOfItem(atPath: setupScript.path)
            let verifyAttrs = try FileManager.default.attributesOfItem(atPath: verifyScript.path)
            let buildAttrs = try FileManager.default.attributesOfItem(atPath: buildScript.path)
            
            if let setupPerms = setupAttrs[.posixPermissions] as? NSNumber,
               let verifyPerms = verifyAttrs[.posixPermissions] as? NSNumber,
               let buildPerms = buildAttrs[.posixPermissions] as? NSNumber {
                
                // Check if executable bit is set (mode & 0o111 != 0)
                XCTAssertNotEqual(setupPerms.intValue & 0o111, 0, "setup-signing.sh should be executable")
                XCTAssertNotEqual(verifyPerms.intValue & 0o111, 0, "verify-signing.sh should be executable")
                XCTAssertNotEqual(buildPerms.intValue & 0o111, 0, "build-production.sh should be executable")
            }
        } catch {
            XCTFail("Should be able to check script permissions: \(error)")
        }
    }
}