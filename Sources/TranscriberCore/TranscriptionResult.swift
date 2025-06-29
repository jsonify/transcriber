import Foundation

public struct TranscriptionSegment {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float
    
    public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

public struct TranscriptionResult {
    public let segments: [TranscriptionSegment]
    public let fullText: String
    public let duration: TimeInterval
    public let language: String
    public let isOnDevice: Bool
    
    public init(segments: [TranscriptionSegment], fullText: String, duration: TimeInterval, language: String, isOnDevice: Bool) {
        self.segments = segments
        self.fullText = fullText
        self.duration = duration
        self.language = language
        self.isOnDevice = isOnDevice
    }
    
    public var averageConfidence: Float {
        guard !segments.isEmpty else { return 0.0 }
        return segments.reduce(0.0) { $0 + $1.confidence } / Float(segments.count)
    }
}

// File management types for UI
public enum FileStatus: Equatable {
    case pending
    case processing
    case done
    case error
}

public struct FileItem: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL
    public var status: FileStatus = .pending
    public var duration: String = ""
    public var progress: Double = 0.0
    
    public init(url: URL, status: FileStatus = .pending, duration: String = "", progress: Double = 0.0) {
        self.url = url
        self.status = status
        self.duration = duration
        self.progress = progress
    }
    
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
}

public enum TranscriptionError: Error, LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case speechRecognitionNotAvailable
    case speechRecognitionDenied
    case speechRecognitionRestricted
    case speechRecognitionNotDetermined
    case audioEngineError(String)
    case transcriptionFailed(String)
    case languageNotSupported(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Audio file not found: \(path)"
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format)"
        case .speechRecognitionNotAvailable:
            return "Speech recognition is not available on this device"
        case .speechRecognitionDenied:
            return "Speech recognition permission denied. Please enable in System Preferences > Security & Privacy > Privacy > Speech Recognition"
        case .speechRecognitionRestricted:
            return "Speech recognition is restricted on this device"
        case .speechRecognitionNotDetermined:
            return "Speech recognition permission not determined"
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .languageNotSupported(let language):
            return "Language not supported: \(language)"
        }
    }
}