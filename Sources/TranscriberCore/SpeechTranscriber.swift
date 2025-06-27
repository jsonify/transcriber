import Foundation
import Speech
import AVFoundation

@MainActor
public class SpeechTranscriber: NSObject, ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    @Published public var isTranscribing = false
    @Published public var progress: Double = 0.0
    @Published public var progressMessage: String = ""
    
    public var progressCallback: ((Double, String) -> Void)?
    private var progressTimer: Timer?
    private var currentProgress: Double = 0.0
    private var targetProgress: Double = 0.0
    private var estimatedDuration: TimeInterval = 0.0
    private var startTime: Date = Date()
    
    public func setProgressCallback(_ callback: @escaping (Double, String) -> Void) {
        progressCallback = callback
    }
    
    public override init() {
        super.init()
    }
    
    public func requestPermission() async throws {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch authStatus {
        case .authorized:
            return
        case .denied:
            throw TranscriptionError.speechRecognitionDenied
        case .restricted:
            throw TranscriptionError.speechRecognitionRestricted
        case .notDetermined:
            updateProgress(0.0, "Requesting speech recognition permission...")
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            if !granted {
                throw TranscriptionError.speechRecognitionDenied
            }
        @unknown default:
            throw TranscriptionError.speechRecognitionNotDetermined
        }
    }
    
    public func transcribeAudioFile(
        at url: URL,
        language: String = "en-US", 
        onDevice: Bool = true
    ) async throws -> TranscriptionResult {
        try await requestPermission()
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            throw TranscriptionError.languageNotSupported(language)
        }
        
        guard recognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionNotAvailable
        }
        
        self.speechRecognizer = recognizer
        
        if onDevice && !recognizer.supportsOnDeviceRecognition {
            updateProgress(0.1, "On-device recognition not available, using server-based...")
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = onDevice && recognizer.supportsOnDeviceRecognition
        
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        
        isTranscribing = true
        progress = 0.0
        updateProgress(0.1, "Initializing speech recognition...")
        
        // Estimate duration based on file size for progress simulation
        let audioDuration = getAudioDuration(url: url)
        let estimatedProcessingTime = max(audioDuration * 0.5, 5.0) // At least 5 seconds, usually 50% of audio duration
        
        return try await withCheckedThrowingContinuation { continuation in
            updateProgress(0.2, "Loading audio file...")
            updateProgress(0.3, "Starting audio analysis...")
            
            // Start smooth progress simulation
            startProgressSimulation(estimatedDuration: estimatedProcessingTime)
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let error = error {
                        self?.stopProgressSimulation()
                        self?.isTranscribing = false
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let result = result else { return }
                    
                    if result.isFinal {
                        self?.stopProgressSimulation()
                        self?.updateProgress(0.95, "Processing final results...")
                        
                        // Brief pause for visual feedback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self?.isTranscribing = false
                            self?.updateProgress(1.0, "Complete!")
                            
                            let segments = self?.convertToSegments(from: result, duration: self?.getAudioDuration(url: url) ?? 0.0) ?? []
                            let duration = self?.getAudioDuration(url: url) ?? 0.0
                            
                            let transcriptionResult = TranscriptionResult(
                                segments: segments,
                                fullText: result.bestTranscription.formattedString,
                                duration: duration,
                                language: language,
                                isOnDevice: request.requiresOnDeviceRecognition
                            )
                            
                            continuation.resume(returning: transcriptionResult)
                        }
                    } else {
                        // We have partial results - speed up progress slightly
                        if let self = self {
                            self.targetProgress = min(0.9, self.targetProgress + 0.05)
                        }
                    }
                }
            }
        }
    }
    
    public func getSupportedLanguages() -> [String] {
        return SFSpeechRecognizer.supportedLocales().map { $0.identifier }.sorted()
    }
    
    public func supportsOnDeviceRecognition(for language: String) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            return false
        }
        return recognizer.supportsOnDeviceRecognition
    }
    
    private func convertToSegments(from result: SFSpeechRecognitionResult, duration: TimeInterval) -> [TranscriptionSegment] {
        let transcription = result.bestTranscription
        var segments: [TranscriptionSegment] = []
        
        if #available(macOS 13.0, *), !transcription.segments.isEmpty {
            for segment in transcription.segments {
                segments.append(TranscriptionSegment(
                    text: segment.substring,
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration,
                    confidence: segment.confidence
                ))
            }
        } else {
            segments.append(TranscriptionSegment(
                text: transcription.formattedString,
                startTime: 0.0,
                endTime: duration,
                confidence: 1.0
            ))
        }
        
        return segments
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            return duration
        } catch {
            return 0.0
        }
    }
    
    public func cancelTranscription() {
        stopProgressSimulation()
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
        updateProgress(0.0, "Cancelled")
    }
    
    private func updateProgress(_ value: Double, _ message: String) {
        progress = value
        progressMessage = message
        progressCallback?(value, message)
    }
    
    private func startProgressSimulation(estimatedDuration: TimeInterval) {
        self.estimatedDuration = estimatedDuration
        self.startTime = Date()
        self.currentProgress = 0.3 // Start after initial setup
        self.targetProgress = 0.85 // Don't go to 100% until we get final result
        
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateProgress()
            }
        }
    }
    
    private func simulateProgress() {
        let elapsed = Date().timeIntervalSince(startTime)
        let progressRate = min(elapsed / estimatedDuration, 1.0)
        
        // Smooth progress curve - fast at first, then slows down
        let smoothProgress = 1.0 - exp(-3.0 * progressRate)
        let newProgress = 0.3 + (smoothProgress * (targetProgress - 0.3))
        
        if newProgress > currentProgress {
            currentProgress = newProgress
            
            let message: String
            let progressPercent = Int(currentProgress * 100)
            
            switch progressPercent {
            case 30..<45:
                message = "Analyzing audio format..."
            case 45..<60:
                message = "Processing speech patterns..."
            case 60..<75:
                message = "Transcribing audio content..."
            case 75..<85:
                message = "Refining transcription..."
            default:
                message = "Finalizing results..."
            }
            
            updateProgress(currentProgress, message)
        }
    }
    
    private func stopProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}