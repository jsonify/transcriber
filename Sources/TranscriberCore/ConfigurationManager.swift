import Foundation
import Yams

public class ConfigurationManager {
    public enum ConfigurationError: Error, LocalizedError {
        case invalidYAML(String)
        case invalidJSON(String)
        case fileNotReadable(String)
        case unsupportedFormat(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidYAML(let message):
                return "Invalid YAML configuration: \(message)"
            case .invalidJSON(let message):
                return "Invalid JSON configuration: \(message)"
            case .fileNotReadable(let path):
                return "Cannot read configuration file: \(path)"
            case .unsupportedFormat(let format):
                return "Unsupported configuration format: \(format)"
            }
        }
    }
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func loadConfiguration(customConfigPath: String? = nil) -> TranscriberConfiguration {
        var finalConfig = TranscriberConfiguration.defaultConfiguration
        
        let configPaths = getConfigurationPaths(customPath: customConfigPath)
        
        for path in configPaths {
            if let config = loadConfigurationFromFile(at: path) {
                finalConfig = finalConfig.merged(with: config)
            }
        }
        
        return finalConfig
    }
    
    public func generateSampleConfiguration(format: String, at path: String) throws {
        let config = TranscriberConfiguration.defaultConfiguration
        let content: String
        
        switch format.lowercased() {
        case "yaml", "yml":
            content = config.asSampleYAML()
        case "json":
            content = config.asSampleJSON()
        default:
            throw ConfigurationError.unsupportedFormat(format)
        }
        
        let url = URL(fileURLWithPath: path)
        
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigurationError.fileNotReadable(path)
        }
    }
    
    private func getConfigurationPaths(customPath: String?) -> [String] {
        var paths: [String] = []
        
        if let customPath = customPath {
            paths.append(customPath)
            return paths
        }
        
        if let homeDir = fileManager.homeDirectoryForCurrentUser.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            let homeDirectory = homeDir.removingPercentEncoding ?? homeDir
            paths.append(contentsOf: [
                "\(homeDirectory)/.transcriber.yaml",
                "\(homeDirectory)/.transcriber.json"
            ])
        }
        
        let currentDir = fileManager.currentDirectoryPath
        paths.append(contentsOf: [
            "\(currentDir)/.transcriber.yaml",
            "\(currentDir)/.transcriber.json"
        ])
        
        return paths
    }
    
    private func loadConfigurationFromFile(at path: String) -> TranscriberConfiguration? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        
        guard let data = fileManager.contents(atPath: path) else {
            return nil
        }
        
        let url = URL(fileURLWithPath: path)
        let fileExtension = url.pathExtension.lowercased()
        
        do {
            switch fileExtension {
            case "yaml", "yml":
                return try loadYAMLConfiguration(from: data)
            case "json":
                return try loadJSONConfiguration(from: data)
            default:
                return nil
            }
        } catch {
            return nil
        }
    }
    
    private func loadYAMLConfiguration(from data: Data) throws -> TranscriberConfiguration {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.invalidYAML("Cannot decode file as UTF-8")
        }
        
        do {
            let yamlData = try Yams.load(yaml: yamlString)
            guard let yamlDict = yamlData as? [String: Any] else {
                throw ConfigurationError.invalidYAML("Configuration must be a dictionary")
            }
            
            return try parseConfigurationDictionary(yamlDict)
        } catch let error as YamlError {
            throw ConfigurationError.invalidYAML(error.localizedDescription)
        } catch {
            throw error
        }
    }
    
    private func loadJSONConfiguration(from data: Data) throws -> TranscriberConfiguration {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let jsonDict = jsonObject as? [String: Any] else {
                throw ConfigurationError.invalidJSON("Configuration must be a JSON object")
            }
            
            return try parseConfigurationDictionary(jsonDict)
        } catch let error as NSError {
            throw ConfigurationError.invalidJSON(error.localizedDescription)
        }
    }
    
    private func parseConfigurationDictionary(_ dict: [String: Any]) throws -> TranscriberConfiguration {
        return TranscriberConfiguration(
            language: dict["language"] as? String,
            format: dict["format"] as? String,
            onDevice: dict["onDevice"] as? Bool,
            outputDir: dict["outputDir"] as? String,
            verbose: dict["verbose"] as? Bool,
            showProgress: dict["showProgress"] as? Bool,
            noColor: dict["noColor"] as? Bool
        )
    }
    
    public func validateConfiguration(_ config: TranscriberConfiguration) -> [String] {
        var errors: [String] = []
        
        if let format = config.format {
            let validFormats = ["txt", "json", "srt", "vtt"]
            if !validFormats.contains(format) {
                errors.append("Invalid format '\(format)'. Valid formats: \(validFormats.joined(separator: ", "))")
            }
        }
        
        if let outputDir = config.outputDir {
            let url = URL(fileURLWithPath: outputDir)
            if !fileManager.fileExists(atPath: url.path) {
                if let parent = url.path(percentEncoded: false).split(separator: "/").dropLast().joined(separator: "/").isEmpty ? nil : "/" + url.path(percentEncoded: false).split(separator: "/").dropLast().joined(separator: "/") {
                    if !fileManager.fileExists(atPath: parent) {
                        errors.append("Output directory parent does not exist: \(parent)")
                    }
                }
            }
        }
        
        return errors
    }
}