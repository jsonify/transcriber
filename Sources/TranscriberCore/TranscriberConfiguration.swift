import Foundation

public struct TranscriberConfiguration: Codable {
    public let language: String?
    public let format: String?
    public let onDevice: Bool?
    public let outputDir: String?
    public let verbose: Bool?
    public let showProgress: Bool?
    public let noColor: Bool?
    
    public init(
        language: String? = nil,
        format: String? = nil,
        onDevice: Bool? = nil,
        outputDir: String? = nil,
        verbose: Bool? = nil,
        showProgress: Bool? = nil,
        noColor: Bool? = nil
    ) {
        self.language = language
        self.format = format
        self.onDevice = onDevice
        self.outputDir = outputDir
        self.verbose = verbose
        self.showProgress = showProgress
        self.noColor = noColor
    }
    
    static var defaultConfiguration: TranscriberConfiguration {
        return TranscriberConfiguration(
            language: "en-US",
            format: "txt",
            onDevice: false,
            outputDir: nil,
            verbose: false,
            showProgress: false,
            noColor: false
        )
    }
    
    public func merged(with other: TranscriberConfiguration) -> TranscriberConfiguration {
        return TranscriberConfiguration(
            language: other.language ?? self.language,
            format: other.format ?? self.format,
            onDevice: other.onDevice ?? self.onDevice,
            outputDir: other.outputDir ?? self.outputDir,
            verbose: other.verbose ?? self.verbose,
            showProgress: other.showProgress ?? self.showProgress,
            noColor: other.noColor ?? self.noColor
        )
    }
    
    public func asSampleYAML() -> String {
        return """
        # Transcriber Configuration File
        # This file contains default settings for the transcriber CLI tool
        
        # Language code for speech recognition (e.g., en-US, es-ES, fr-FR)
        language: "en-US"
        
        # Output format: txt, json, srt, vtt
        format: "txt"
        
        # Use on-device recognition (more private, limited languages)
        onDevice: false
        
        # Default output directory for batch processing (optional)
        # outputDir: "/path/to/output"
        
        # Enable verbose output
        verbose: false
        
        # Show progress during transcription
        showProgress: false
        
        # Disable colored output and progress bars
        noColor: false
        """
    }
    
    public func asSampleJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let sampleConfig = TranscriberConfiguration.defaultConfiguration
        
        do {
            let data = try encoder.encode(sampleConfig)
            _ = String(data: data, encoding: .utf8) ?? ""
            
            return """
            {
              "_comment": "Transcriber Configuration File - Default settings for the transcriber CLI tool",
              "format": "txt",
              "language": "en-US",
              "noColor": false,
              "onDevice": false,
              "outputDir": null,
              "showProgress": false,
              "verbose": false
            }
            """
        } catch {
            return "{}"
        }
    }
}