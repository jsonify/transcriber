import SwiftUI
import AppKit
import TranscriberCore
import UserNotifications

@MainActor
class AppDelegate: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var outputFormat: String = "txt"
    @Published var language: String = "en-US"
    @Published var onDevice: Bool = true
    @Published var isTranscribing = false
    @Published var transcriptionResults: [TranscriptionResult] = []
    @Published var showingResults = false
    @Published var showingConfiguration = false
    @Published var showingAbout = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    private let speechTranscriber = SpeechTranscriber()
    private let audioExtractor = AudioExtractor()
    private let configManager = ConfigurationManager()
    
    init() {
        setupNotifications()
        loadConfiguration()
        setupProgressCallback()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    private func loadConfiguration() {
        let config = configManager.loadConfiguration(customConfigPath: nil)
        language = config.language ?? "en-US"
        outputFormat = config.format ?? "txt"
        onDevice = config.onDevice ?? true
    }
    
    private func setupProgressCallback() {
        speechTranscriber.setProgressCallback { [weak self] progress, message in
            Task { @MainActor in
                self?.isTranscribing = progress < 1.0
            }
        }
    }
    
    // MARK: - File Management
    
    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.title = "Select Audio or Video Files"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .audio,
            .movie,
            .init("public.audio")!,
            .init("public.movie")!
        ]
        
        if panel.runModal() == .OK {
            selectedFiles.append(contentsOf: panel.urls)
        }
    }
    
    func clearFiles() {
        selectedFiles.removeAll()
    }
    
    func removeFile(_ url: URL) {
        selectedFiles.removeAll { $0 == url }
    }
    
    // MARK: - Transcription
    
    func startTranscription() async {
        guard !selectedFiles.isEmpty else { return }
        
        do {
            isTranscribing = true
            transcriptionResults.removeAll()
            
            // Request permission first
            try await speechTranscriber.requestPermission()
            
            for fileURL in selectedFiles {
                let result = try await speechTranscriber.transcribeAudioFile(
                    at: fileURL,
                    language: language,
                    onDevice: onDevice
                )
                transcriptionResults.append(result)
                
                // Save the result to file
                let outputText = OutputFormatter.format(result, as: OutputFormat(rawValue: outputFormat) ?? .text)
                let outputURL = fileURL.deletingPathExtension().appendingPathExtension(outputFormat)
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
            }
            
            isTranscribing = false
            showingResults = true
            
            // Send completion notification
            sendCompletionNotification()
            
        } catch {
            isTranscribing = false
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"
        content.body = "Successfully transcribed \(transcriptionResults.count) file(s)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "transcription-complete",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - UI Actions
    
    func showResults() {
        showingResults = true
    }
    
    func showConfiguration() {
        showingConfiguration = true
    }
    
    func showAbout() {
        showingAbout = true
    }
    
    func showHelp() {
        if let url = URL(string: "https://github.com/jsonify/transcriber") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Configuration
    
    func updateConfiguration() {
        // Save configuration changes
        // This could write to the config file or user defaults
    }
    
    // MARK: - Utility
    
    func getFileIcon(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "wav", "mp3", "m4a", "aac", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "video"
        default:
            return "doc"
        }
    }
}