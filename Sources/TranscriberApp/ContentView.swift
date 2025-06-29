import SwiftUI
import TranscriberCore
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @State private var isShowingFilePicker = false
    @State private var dragHover = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with logo and user
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        Text("Transcriber")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            appDelegate.showingConfiguration = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Text("A")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            
                            Text("Alex Chan")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                Spacer()
                
                // Main content area
                VStack(spacing: 32) {
                    // Drag and drop area
                    if appDelegate.selectedFiles.isEmpty {
                        VStack(spacing: 16) {
                            Button(action: { isShowingFilePicker = true }) {
                                VStack(spacing: 16) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    
                                    VStack(spacing: 8) {
                                        Text("Drag & Drop your audio/video files")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("or click to select files from your device")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                            }
                            .buttonStyle(.plain)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(dragHover ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(dragHover ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            
                            Button("Select Files") {
                                isShowingFilePicker = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Settings row
                    HStack(spacing: 24) {
                        // Language
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("Language")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Picker("Language", selection: $appDelegate.language) {
                                Group {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundColor(.red)
                                        Text("English")
                                    }.tag("en-US")
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        // Output Format
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("Output Format")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Picker("Format", selection: $appDelegate.outputFormat) {
                                Text("SRT").tag("srt")
                                Text("VTT").tag("vtt") 
                                Text("TXT").tag("txt")
                                Text("JSON").tag("json")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        // Quality
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("Quality")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Picker("Quality", selection: $appDelegate.quality) {
                                Text("High").tag("High")
                                Text("Medium").tag("Medium")
                                Text("Low").tag("Low")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Uploaded Files section
                    if !appDelegate.selectedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Uploaded Files")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                            
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(appDelegate.selectedFiles) { fileItem in
                                        FileListItemView(
                                            fileItem: fileItem,
                                            onPlay: {
                                                appDelegate.playAudio(for: fileItem)
                                            },
                                            onDelete: {
                                                appDelegate.removeFile(fileItem)
                                            }
                                        )
                                        
                                        if fileItem.id != appDelegate.selectedFiles.last?.id {
                                            Divider()
                                                .background(Color.gray.opacity(0.3))
                                        }
                                    }
                                }
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 32)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onDrop(of: [UTType.audio, UTType.movie], isTargeted: $dragHover) { providers in
            handleDrop(providers: providers)
        }
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
                appDelegate.addFiles(urls)
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
        .sheet(isPresented: $appDelegate.showingConfiguration) {
            SettingsView()
                .environmentObject(appDelegate)
        }
        .alert("Error", isPresented: $appDelegate.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appDelegate.errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                let _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            urls.append(url)
                            if urls.count == providers.count {
                                appDelegate.addFiles(urls)
                            }
                        }
                    }
                }
            }
        }
        
        return true
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif