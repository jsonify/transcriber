import SwiftUI
import TranscriberCore
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @State private var isShowingFilePicker = false
    
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
                    Picker("Language", selection: $appDelegate.language) {
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
                    Picker("Format", selection: $appDelegate.outputFormat) {
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
                    Picker("Recognition Mode", selection: $appDelegate.onDevice) {
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
                
                if appDelegate.selectedFiles.isEmpty {
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
                            Text("\(appDelegate.selectedFiles.count) file(s) selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Clear") {
                                appDelegate.clearFiles()
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Add More") {
                                isShowingFilePicker = true
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(appDelegate.selectedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: appDelegate.getFileIcon(for: file))
                                            .foregroundColor(.blue)
                                        
                                        Text(file.lastPathComponent)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            appDelegate.removeFile(file)
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
            if appDelegate.isTranscribing || speechTranscriber.isTranscribing {
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
                        await appDelegate.startTranscription()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appDelegate.selectedFiles.isEmpty || appDelegate.isTranscribing)
                
                if !appDelegate.transcriptionResults.isEmpty {
                    Button("View Results") {
                        appDelegate.showResults()
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
                appDelegate.selectedFiles.append(contentsOf: urls)
            case .failure(let error):
                appDelegate.errorMessage = "Failed to select files: \(error.localizedDescription)"
                appDelegate.showingError = true
            }
        }
        .sheet(isPresented: $appDelegate.showingResults) {
            ResultsView(results: appDelegate.transcriptionResults)
        }
        .sheet(isPresented: $appDelegate.showingAbout) {
            AboutView()
        }
        .alert("Error", isPresented: $appDelegate.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appDelegate.errorMessage ?? "An unknown error occurred")
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