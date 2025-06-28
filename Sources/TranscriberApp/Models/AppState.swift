import Foundation
import TranscriberCore

@MainActor
class AppState: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var configuration = TranscriberConfiguration()
    @Published var isProcessing = false
    @Published var currentProgress: Double = 0.0
    @Published var currentTask: String = ""
    @Published var transcriptionResults: [TranscriptionResult] = []
    @Published var lastError: Error?
    
    private let configurationManager = ConfigurationManager()
    
    init() {
        loadConfiguration()
    }
    
    func loadConfiguration() {
        configuration = configurationManager.loadConfiguration(customConfigPath: nil)
    }
    
    func addFiles(_ urls: [URL]) {
        selectedFiles.append(contentsOf: urls)
    }
    
    func removeFile(at index: Int) {
        guard index < selectedFiles.count else { return }
        selectedFiles.remove(at: index)
    }
    
    func clearFiles() {
        selectedFiles.removeAll()
    }
    
    func updateProgress(_ progress: Double, task: String) {
        currentProgress = progress
        currentTask = task
    }
    
    func addTranscriptionResult(_ result: TranscriptionResult) {
        transcriptionResults.append(result)
    }
    
    func clearResults() {
        transcriptionResults.removeAll()
    }
    
    func setError(_ error: Error) {
        lastError = error
    }
    
    func clearError() {
        lastError = nil
    }
}