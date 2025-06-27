import Foundation
import ArgumentParser
import TranscriberCore

// MARK: - CLI Styling Functions

func showHeader() {
    print()
    print("🎙️  \u{001B}[1;36mTranscriber v1.0.0\u{001B}[0m")
    print("   \u{001B}[2mModern macOS Speech Recognition\u{001B}[0m")
    print()
}

func showConfiguration(language: String, format: String, onDevice: Bool, fileCount: Int) {
    print("📋 \u{001B}[1mConfiguration\u{001B}[0m")
    print("   Language: \u{001B}[33m\(language)\u{001B}[0m")
    print("   Format: \u{001B}[33m\(format)\u{001B}[0m")
    print("   Mode: \u{001B}[33m\(onDevice ? "On-device" : "Server-based")\u{001B}[0m")
    print("   Files: \u{001B}[33m\(fileCount)\u{001B}[0m")
    print()
}

func displayProgress(_ value: Double, message: String) {
    let width = 30
    let filled = Int(value * Double(width))
    let empty = width - filled
    
    let progressBar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
    let percentage = Int(value * 100)
    
    print("\r\u{001B}[K   [\(progressBar)] \(percentage)% \u{001B}[2m\(message)\u{001B}[0m", terminator: "")
    fflush(stdout)
}

func finishProgress() {
    print() // New line after progress
}

func showError(_ message: String, details: String? = nil) {
    print("❌ \u{001B}[1;31mError:\u{001B}[0m \(message)")
    if let details = details {
        print("   \u{001B}[2m\(details)\u{001B}[0m")
    }
    print()
}

func showSuccess(_ message: String) {
    print("✅ \u{001B}[1;32m\(message)\u{001B}[0m")
}

func getFileIcon(_ fileName: String) -> String {
    let ext = (fileName as NSString).pathExtension.lowercased()
    switch ext {
    case "mp3": return "🎵"
    case "wav": return "🎤"
    case "m4a", "aac": return "🎧"
    case "aiff", "caf": return "🔊"
    default: return "🎙️"
    }
}

func showSupportedLanguages(_ languages: [(String, Bool)]) {
    print("🌍 \u{001B}[1mSupported Languages\u{001B}[0m")
    print()
    
    let onDeviceLanguages = languages.filter { $0.1 }.map { $0.0 }
    let serverLanguages = languages.filter { !$0.1 }.map { $0.0 }
    
    if !onDeviceLanguages.isEmpty {
        print("   🔒 \u{001B}[1mOn-device (Private)\u{001B}[0m")
        for language in onDeviceLanguages.sorted() {
            print("      \u{001B}[32m●\u{001B}[0m \(language)")
        }
        print()
    }
    
    if !serverLanguages.isEmpty {
        print("   🌐 \u{001B}[1mServer-based\u{001B}[0m")
        for language in serverLanguages.sorted() {
            print("      \u{001B}[34m●\u{001B}[0m \(language)")
        }
    }
    print()
}

// MARK: - Main Command

@main
struct TranscriberCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transcriber",
        abstract: "🎙️  A modern macOS speech recognition tool for transcribing audio files",
        version: "1.0.0"
    )
    
    @Argument(help: "Input audio file path(s)")
    var inputFiles: [String] = []
    
    @Option(name: .shortAndLong, help: "Output format (txt, json, srt, vtt)")
    var format: String = "txt"
    
    @Option(name: .shortAndLong, help: "Output file path (optional)")
    var output: String?
    
    @Option(name: .long, help: "Output directory for batch processing")
    var outputDir: String?
    
    @Option(name: .shortAndLong, help: "Language code (e.g., en-US, es-ES)")
    var language: String = "en-US"
    
    @Flag(name: .long, help: "Use on-device recognition (more private, limited languages)")
    var onDevice: Bool = false
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "List supported languages")
    var listLanguages: Bool = false
    
    @Flag(name: .long, help: "Show progress during transcription")
    var showProgress: Bool = false
    
    @Flag(name: .long, help: "Disable colored output and progress bars")
    var noColor: Bool = false
    
    func run() async throws {
        let transcriber = await SpeechTranscriber()
        
        // Handle special commands first
        if listLanguages {
            let allLanguages = await transcriber.getSupportedLanguages()
            var languagesWithSupport: [(String, Bool)] = []
            
            for language in allLanguages {
                let onDeviceSupport = await transcriber.supportsOnDeviceRecognition(for: language)
                languagesWithSupport.append((language, onDeviceSupport))
            }
            
            showSupportedLanguages(languagesWithSupport)
            return
        }
        
        // Validate input
        guard !inputFiles.isEmpty else {
            showError("No input files specified", details: "Use 'transcriber --help' for usage information")
            throw ExitCode.failure
        }
        
        guard let outputFormat = OutputFormat(rawValue: format) else {
            showError("Unsupported format '\(format)'", 
                     details: "Supported formats: \(OutputFormat.allCases.map(\.rawValue).joined(separator: ", "))")
            throw ExitCode.failure
        }
        
        // Show beautiful header
        if !noColor {
            showHeader()
            showConfiguration(
                language: language,
                format: format,
                onDevice: onDevice,
                fileCount: inputFiles.count
            )
        }
        
        // Set up progress callback
        await transcriber.setProgressCallback { progress, message in
            if showProgress || !noColor {
                displayProgress(progress, message: message)
            }
        }
        
        var successCount = 0
        var failCount = 0
        
        // Process each file
        for (index, inputFile) in inputFiles.enumerated() {
            let fileURL = URL(fileURLWithPath: inputFile)
            let fileIcon = getFileIcon(inputFile)
            
            // Check file existence
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                showError("File not found: \(inputFile)")
                if verbose {
                    print("   📁 Checked: \u{001B}[2m\(fileURL.path)\u{001B}[0m")
                    print("   📂 Working dir: \u{001B}[2m\(FileManager.default.currentDirectoryPath)\u{001B}[0m")
                }
                failCount += 1
                continue
            }
            
            // Start processing this file
            print("\(fileIcon) \u{001B}[1mProcessing [\(index + 1)/\(inputFiles.count)]\u{001B}[0m \u{001B}[2m\(fileURL.lastPathComponent)\u{001B}[0m")
            
            // Show file info if verbose
            if verbose {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                print("   📊 Size: \u{001B}[2m\(formatter.string(fromByteCount: fileSize))\u{001B}[0m")
            }
            
            do {
                // Start progress
                if showProgress || !noColor {
                    print("   \u{001B}[2mStarting transcription...\u{001B}[0m")
                    displayProgress(0.0, message: "Initializing...")
                }
                
                // Perform transcription
                let result = try await transcriber.transcribeAudioFile(
                    at: fileURL,
                    language: language,
                    onDevice: onDevice
                )
                
                // Finish progress
                if showProgress || !noColor {
                    displayProgress(1.0, message: "Complete!")
                    finishProgress()
                }
                
                // Format output
                let formattedOutput = OutputFormatter.format(result, as: outputFormat)
                let outputPath = determineOutputPath(for: inputFile, format: outputFormat)
                
                // Save or display result
                if let outputPath = outputPath {
                    try formattedOutput.write(toFile: outputPath, atomically: true, encoding: .utf8)
                }
                
                // Show results
                showSuccess("Transcription Complete")
                if verbose {
                    let formatDuration = { (seconds: TimeInterval) -> String in
                        let minutes = Int(seconds) / 60
                        let remainingSeconds = Int(seconds) % 60
                        return minutes > 0 ? "\(minutes)m \(remainingSeconds)s" : String(format: "%.1fs", seconds)
                    }
                    
                    print("   ⏱️  Duration: \u{001B}[2m\(formatDuration(result.duration))\u{001B}[0m")
                    print("   🎯 Confidence: \u{001B}[2m\(String(format: "%.1f%%", result.averageConfidence * 100))\u{001B}[0m")
                    print("   📝 Segments: \u{001B}[2m\(result.segments.count)\u{001B}[0m")
                    print("   🔒 Privacy: \u{001B}[2m\(result.isOnDevice ? "On-device" : "Server-based")\u{001B}[0m")
                }
                
                if let outputPath = outputPath {
                    print("   💾 Saved to: \u{001B}[36m\(outputPath)\u{001B}[0m")
                } else {
                    print()
                    print("📄 \u{001B}[1mTranscription:\u{001B}[0m")
                    print()
                    let previewText = result.fullText.count > 200 ? String(result.fullText.prefix(200)) + "..." : result.fullText
                    print("   \u{001B}[2m\"\u{001B}[0m\(previewText)\u{001B}[2m\"\u{001B}[0m")
                }
                print()
                
                successCount += 1
                
            } catch {
                if showProgress || !noColor {
                    finishProgress()
                }
                
                showError("Failed to transcribe \(inputFile)", details: error.localizedDescription)
                failCount += 1
            }
        }
        
        // Show batch summary if multiple files
        if inputFiles.count > 1 {
            print("📊 \u{001B}[1mBatch Processing Summary\u{001B}[0m")
            print("   Total: \u{001B}[2m\(inputFiles.count)\u{001B}[0m")
            print("   ✅ Successful: \u{001B}[32m\(successCount)\u{001B}[0m")
            if failCount > 0 {
                print("   ❌ Failed: \u{001B}[31m\(failCount)\u{001B}[0m")
            }
            print()
        }
    }
    
    private func determineOutputPath(for inputFile: String, format: OutputFormat) -> String? {
        if let explicitOutput = output {
            return explicitOutput
        }
        
        let inputURL = URL(fileURLWithPath: inputFile)
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        
        if let outputDirectory = outputDir {
            let outputURL = URL(fileURLWithPath: outputDirectory)
                .appendingPathComponent("\(baseName).\(format.fileExtension)")
            
            try? FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            return outputURL.path
        }
        
        if inputFiles.count == 1 && output == nil {
            return nil
        }
        
        let outputURL = inputURL.deletingPathExtension()
            .appendingPathExtension(format.fileExtension)
        return outputURL.path
    }
}