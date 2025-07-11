import SwiftUI
import AppKit
import TranscriberCore
import UserNotifications
import AVFoundation


@MainActor
class AppDelegate: ObservableObject {
    @Published var selectedFiles: [FileItem] = []
    @Published var outputFormat: String = "srt"
    @Published var language: String = "en-US"
    @Published var quality: String = "High"
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
    private var audioPlayer: AVAudioPlayer?
    
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
        outputFormat = config.format ?? "srt"
        quality = "High"
        onDevice = config.onDevice ?? true
    }
    
    private func setupProgressCallback() {
        speechTranscriber.setProgressCallback { [weak self] progress, message in
            Task { @MainActor in
                self?.isTranscribing = progress < 1.0
                // Update progress for currently processing file
                self?.updateCurrentFileProgress(progress, message)
            }
        }
    }
    
    private func updateCurrentFileProgress(_ progress: Double, _ message: String) {
        if let currentIndex = selectedFiles.firstIndex(where: { $0.status == .processing }) {
            selectedFiles[currentIndex].progress = progress
            selectedFiles[currentIndex].progressMessage = message
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
            addFiles(panel.urls)
        }
    }
    
    func clearFiles() {
        selectedFiles.removeAll()
    }
    
    func removeFile(_ fileItem: FileItem) {
        selectedFiles.removeAll { $0.id == fileItem.id }
    }
    
    func addFiles(_ urls: [URL]) {
        var newFiles: [FileItem] = []
        for url in urls {
            var fileItem = FileItem(url: url)
            fileItem.duration = getAudioDuration(for: url)
            newFiles.append(fileItem)
        }
        selectedFiles.append(contentsOf: newFiles)
    }
    
    private func getAudioDuration(for url: URL) -> String {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let seconds = CMTimeGetSeconds(duration)
        
        if seconds.isNaN || seconds.isInfinite {
            return "Unknown"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Transcription
    
    // Individual file transcription control
    func startTranscription(for fileItem: FileItem) async {
        guard let index = selectedFiles.firstIndex(where: { $0.id == fileItem.id }) else { return }
        guard selectedFiles[index].canStart else { return }
        
        do {
            // Set file to queued state
            selectedFiles[index].status = .queued
            selectedFiles[index].progress = 0.0
            selectedFiles[index].progressMessage = "Queued for transcription..."
            selectedFiles[index].errorMessage = nil
            
            // Brief delay to show queued state
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Start processing
            selectedFiles[index].status = .processing
            selectedFiles[index].progressMessage = "Initializing..."
            isTranscribing = true
            
            // Request permission first
            try await speechTranscriber.requestPermission()
            
            let result = try await speechTranscriber.transcribeAudioFile(
                at: selectedFiles[index].url,
                language: language,
                onDevice: onDevice,
                quality: quality
            )
            
            // Save the result to file
            let outputText = OutputFormatter.format(result, as: OutputFormat(rawValue: outputFormat) ?? .text)
            let outputURL = selectedFiles[index].url.deletingPathExtension().appendingPathExtension(outputFormat)
            try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
            
            // Update file status
            selectedFiles[index].status = .done
            selectedFiles[index].progress = 1.0
            selectedFiles[index].progressMessage = "Complete!"
            
            // Add to results
            transcriptionResults.append(result)
            
            // Show results if this is the first completed file
            if transcriptionResults.count == 1 {
                showingResults = true
            }
            
            // Send completion notification
            sendCompletionNotification(for: fileItem)
            
        } catch {
            selectedFiles[index].status = .error
            selectedFiles[index].progress = 0.0
            selectedFiles[index].progressMessage = ""
            selectedFiles[index].errorMessage = error.localizedDescription
            
            errorMessage = "Failed to transcribe \(fileItem.url.lastPathComponent): \(error.localizedDescription)"
            showingError = true
        }
        
        // Update global transcription state
        isTranscribing = selectedFiles.contains { $0.status == .processing || $0.status == .queued }
    }
    
    func cancelTranscription(for fileItem: FileItem) {
        guard let index = selectedFiles.firstIndex(where: { $0.id == fileItem.id }) else { return }
        guard selectedFiles[index].canCancel else { return }
        
        // Cancel the transcription
        speechTranscriber.cancelTranscription()
        
        // Update file status
        selectedFiles[index].status = .cancelled
        selectedFiles[index].progress = 0.0
        selectedFiles[index].progressMessage = ""
        selectedFiles[index].errorMessage = nil
        
        // Update global transcription state
        isTranscribing = selectedFiles.contains { $0.status == .processing || $0.status == .queued }
    }
    
    func queueTranscription(for fileItem: FileItem) {
        guard let index = selectedFiles.firstIndex(where: { $0.id == fileItem.id }) else { return }
        guard selectedFiles[index].status == .pending else { return }
        
        selectedFiles[index].status = .queued
        selectedFiles[index].progress = 0.0
        selectedFiles[index].progressMessage = "Queued for transcription..."
        selectedFiles[index].errorMessage = nil
    }
    
    // Batch transcription (maintains backwards compatibility)
    func startTranscription() async {
        guard !selectedFiles.isEmpty else { return }
        
        do {
            isTranscribing = true
            transcriptionResults.removeAll()
            
            // Request permission first
            try await speechTranscriber.requestPermission()
            
            for i in 0..<selectedFiles.count {
                selectedFiles[i].status = .processing
                selectedFiles[i].progress = 0.0
                
                let result = try await speechTranscriber.transcribeAudioFile(
                    at: selectedFiles[i].url,
                    language: language,
                    onDevice: onDevice,
                    quality: quality
                )
                transcriptionResults.append(result)
                
                // Save the result to file
                let outputText = OutputFormatter.format(result, as: OutputFormat(rawValue: outputFormat) ?? .text)
                let outputURL = selectedFiles[i].url.deletingPathExtension().appendingPathExtension(outputFormat)
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
                
                selectedFiles[i].status = .done
                selectedFiles[i].progress = 1.0
            }
            
            isTranscribing = false
            showingResults = true
            
            // Send completion notification
            sendCompletionNotification()
            
        } catch {
            isTranscribing = false
            // Mark current file as error
            if let currentIndex = selectedFiles.firstIndex(where: { $0.status == .processing }) {
                selectedFiles[currentIndex].status = .error
            }
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
    
    private func sendCompletionNotification(for fileItem: FileItem) {
        let content = UNMutableNotificationContent()
        content.title = "File Transcription Complete"
        content.body = "Successfully transcribed \(fileItem.url.lastPathComponent)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "file-transcription-complete-\(fileItem.id)",
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
    
    func playAudio(for fileItem: FileItem) {
        do {
            // Stop any currently playing audio
            audioPlayer?.stop()
            
            // Try to create audio player with the file
            audioPlayer = try AVAudioPlayer(contentsOf: fileItem.url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // If direct playback fails, try opening with system default app
            NSWorkspace.shared.open(fileItem.url)
        }
    }
    
    // MARK: - Configuration
    
    func updateConfiguration() {
        // Save configuration changes
        // This could write to the config file or user defaults
    }
    
    // MARK: - Utility
    
    func getFileIcon(for fileItem: FileItem) -> String {
        let pathExtension = fileItem.url.pathExtension.lowercased()
        switch pathExtension {
        case "wav", "mp3", "m4a", "aac", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        default:
            return "doc.fill"
        }
    }
}