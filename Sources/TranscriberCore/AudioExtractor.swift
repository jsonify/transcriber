import Foundation
import AVFoundation

@MainActor
public class AudioExtractor: NSObject, ObservableObject {
    @Published public var isExtracting = false
    @Published public var progress: Double = 0.0
    @Published public var progressMessage: String = ""
    
    public var progressCallback: ((Double, String) -> Void)?
    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    
    public func setProgressCallback(_ callback: @escaping (Double, String) -> Void) {
        progressCallback = callback
    }
    
    public func extractAudio(
        from videoURL: URL,
        to outputURL: URL,
        format: AudioFormat = .wav
    ) async throws {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw AudioExtractionError.fileNotFound(videoURL.path)
        }
        
        let asset = AVAsset(url: videoURL)
        
        // Check if the asset has audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioExtractionError.noAudioTrack
        }
        
        // Get the appropriate export preset
        let exportPreset = format.exportPreset
        guard AVAssetExportSession.allExportPresets().contains(exportPreset) else {
            throw AudioExtractionError.unsupportedFormat(format.rawValue)
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: exportPreset) else {
            throw AudioExtractionError.exportSessionCreationFailed
        }
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.fileType
        exportSession.shouldOptimizeForNetworkUse = false
        
        // Set up audio mix to ensure we get all audio tracks
        if audioTracks.count > 1 {
            let audioMix = AVMutableAudioMix()
            var audioMixInputParameters: [AVMutableAudioMixInputParameters] = []
            
            for track in audioTracks {
                let audioMixInputParameter = AVMutableAudioMixInputParameters(track: track)
                audioMixInputParameter.setVolume(1.0, at: .zero)
                audioMixInputParameters.append(audioMixInputParameter)
            }
            
            audioMix.inputParameters = audioMixInputParameters
            exportSession.audioMix = audioMix
        }
        
        self.exportSession = exportSession
        self.isExtracting = true
        
        // Start progress tracking
        startProgressTracking()
        updateProgress(0.1, "Starting audio extraction...")
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously { [weak self, exportSession] in
                Task { @MainActor [weak self] in
                    self?.stopProgressTracking()
                    self?.isExtracting = false
                    
                    switch exportSession.status {
                    case .completed:
                        self?.updateProgress(1.0, "Audio extraction completed!")
                        continuation.resume()
                    case .failed:
                        let error = exportSession.error ?? AudioExtractionError.exportFailed("Unknown error")
                        continuation.resume(throwing: AudioExtractionError.exportFailed(error.localizedDescription))
                    case .cancelled:
                        continuation.resume(throwing: AudioExtractionError.exportCancelled)
                    default:
                        continuation.resume(throwing: AudioExtractionError.exportFailed("Export failed with status: \(exportSession.status)"))
                    }
                }
            }
        }
    }
    
    public func cancelExtraction() {
        exportSession?.cancelExport()
        stopProgressTracking()
        isExtracting = false
        updateProgress(0.0, "Cancelled")
    }
    
    private func startProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgressFromExportSession()
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgressFromExportSession() {
        guard let exportSession = exportSession else { return }
        
        let sessionProgress = Double(exportSession.progress)
        let adjustedProgress = 0.1 + (sessionProgress * 0.9) // Start at 10%, end at 100%
        
        let message: String
        switch sessionProgress {
        case 0.0..<0.2:
            message = "Analyzing video file..."
        case 0.2..<0.5:
            message = "Extracting audio tracks..."
        case 0.5..<0.8:
            message = "Converting to \(exportSession.outputFileType?.rawValue ?? "audio")..."
        case 0.8..<1.0:
            message = "Finalizing audio file..."
        default:
            message = "Processing..."
        }
        
        updateProgress(adjustedProgress, message)
    }
    
    private func updateProgress(_ value: Double, _ message: String) {
        progress = value
        progressMessage = message
        progressCallback?(value, message)
    }
    
    nonisolated public static func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "3gp", "webm"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    nonisolated public static func generateAudioOutputURL(from videoURL: URL, format: AudioFormat) -> URL {
        let baseName = videoURL.deletingPathExtension().lastPathComponent
        let outputDir = videoURL.deletingLastPathComponent()
        return outputDir.appendingPathComponent("\(baseName).\(format.fileExtension)")
    }
}

public enum AudioFormat: String, CaseIterable {
    case wav = "wav"
    case m4a = "m4a"
    case aiff = "aiff"
    
    public var fileExtension: String {
        return rawValue
    }
    
    var exportPreset: String {
        switch self {
        case .wav:
            return AVAssetExportPresetPassthrough
        case .m4a:
            return AVAssetExportPresetAppleM4A
        case .aiff:
            return AVAssetExportPresetPassthrough
        }
    }
    
    var fileType: AVFileType {
        switch self {
        case .wav:
            return .wav
        case .m4a:
            return .m4a
        case .aiff:
            return .aiff
        }
    }
}

public enum AudioExtractionError: Error, LocalizedError {
    case fileNotFound(String)
    case noAudioTrack
    case unsupportedFormat(String)
    case exportSessionCreationFailed
    case exportFailed(String)
    case exportCancelled
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Video file not found: \(path)"
        case .noAudioTrack:
            return "No audio track found in video file"
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format)"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let message):
            return "Audio extraction failed: \(message)"
        case .exportCancelled:
            return "Audio extraction was cancelled"
        }
    }
}