import SwiftUI
import TranscriberCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @StateObject private var audioExtractor = AudioExtractor()
    private let configManager = ConfigurationManager()
    
    @State private var selectedFiles: [URL] = []
    @State private var outputFormat: String = "txt"
    @State private var language: String = "en-US"
    @State private var onDevice: Bool = true
    @State private var isShowingFilePicker = false
    @State private var transcriptionResults: [TranscriptionResult] = []
    @State private var showingResults = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Transcriber")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Modern macOS Speech Recognition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Configuration Section
            VStack(alignment: .leading, spacing: 15) {
                Text("Configuration")
                    .font(.headline)
                
                HStack {
                    Text("Language:")
                        .frame(width: 80, alignment: .leading)
                    Picker("Language", selection: $language) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("Spanish").tag("es-ES")
                        Text("French").tag("fr-FR")
                        Text("German").tag("de-DE")
                        Text("Japanese").tag("ja-JP")
                        Text("Chinese").tag("zh-CN")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    Spacer()
                }
                
                HStack {
                    Text("Output:")
                        .frame(width: 80, alignment: .leading)
                    Picker("Format", selection: $outputFormat) {
                        Text("Text (.txt)").tag("txt")
                        Text("JSON (.json)").tag("json")
                        Text("SubRip (.srt)").tag("srt")
                        Text("WebVTT (.vtt)").tag("vtt")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    Spacer()
                }
                
                HStack {
                    Text("Mode:")
                        .frame(width: 80, alignment: .leading)
                    Picker("Recognition Mode", selection: $onDevice) {
                        Text("On-device").tag(true)
                        Text("Server-based").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            Divider()
            
            // File Selection Section
            VStack(spacing: 15) {
                Text("Audio Files")
                    .font(.headline)
                
                if selectedFiles.isEmpty {
                    Button(action: { isShowingFilePicker = true }) {
                        VStack {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Select Audio Files")
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Text("Choose .wav, .mp3, .m4a, .mp4, or other audio/video files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(selectedFiles.count) file(s) selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Clear") {
                                selectedFiles.removeAll()
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Add More") {
                                isShowingFilePicker = true
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(selectedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: getFileIcon(for: file))
                                            .foregroundColor(.blue)
                                        
                                        Text(file.lastPathComponent)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            selectedFiles.removeAll { $0 == file }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Progress Section
            if speechTranscriber.isTranscribing {
                VStack(spacing: 10) {
                    Text("Transcribing...")
                        .font(.headline)
                    
                    ProgressView(value: speechTranscriber.progress)
                        .progressViewStyle(.linear)
                    
                    Text(speechTranscriber.progressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 15) {
                Button("Transcribe") {
                    Task {
                        await transcribeFiles()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty || speechTranscriber.isTranscribing)
                
                if !transcriptionResults.isEmpty {
                    Button("View Results") {
                        showingResults = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity,
               minHeight: 400, idealHeight: 500, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [
                UTType.audio,
                UTType.movie,
                UTType("public.audio")!,
                UTType("public.movie")!
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedFiles.append(contentsOf: urls)
            case .failure(let error):
                errorMessage = "Failed to select files: \(error.localizedDescription)"
                showingError = true
            }
        }
        .sheet(isPresented: $showingResults) {
            ResultsView(results: transcriptionResults)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func transcribeFiles() async {
        do {
            // Request permission first
            try await speechTranscriber.requestPermission()
            
            transcriptionResults.removeAll()
            
            for fileURL in selectedFiles {
                let result = try await speechTranscriber.transcribeAudioFile(
                    at: fileURL,
                    language: language,
                    onDevice: onDevice
                )
                transcriptionResults.append(result)
                
                // Save the result to file using static method
                let outputText = OutputFormatter.format(result, as: OutputFormat(rawValue: outputFormat) ?? .text)
                let outputURL = fileURL.deletingPathExtension().appendingPathExtension(outputFormat)
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
            }
            
            showingResults = true
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func getFileIcon(for url: URL) -> String {
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

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif