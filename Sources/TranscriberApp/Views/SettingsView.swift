import SwiftUI
import TranscriberCore

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var tempLanguage: String = ""
    @State private var tempOutputFormat: String = ""
    @State private var tempOnDevice: Bool = true
    @State private var showAdvanced = false
    
    var body: some View {
        TabView {
            // General Settings
            VStack(alignment: .leading, spacing: 20) {
                Text("General Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Default Language:")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("Language", selection: $tempLanguage) {
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
                        Text("Default Output Format:")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("Format", selection: $tempOutputFormat) {
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
                        Text("Recognition Mode:")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("Recognition Mode", selection: $tempOnDevice) {
                            Text("On-device").tag(true)
                            Text("Server-based").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Performance")
                        .font(.headline)
                    
                    HStack {
                        Toggle("Show advanced options", isOn: $showAdvanced)
                        Spacer()
                    }
                    
                    if showAdvanced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Batch Processing:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Max concurrent files:")
                                    .frame(width: 140, alignment: .leading)
                                
                                Stepper(value: .constant(1), in: 1...5) {
                                    Text("1")
                                }
                                .frame(maxWidth: 100)
                                
                                Spacer()
                            }
                        }
                        .padding(.leading, 16)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Apply") {
                        applySettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Audio Settings
            VStack(alignment: .leading, spacing: 20) {
                Text("Audio Processing")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Audio Quality")
                        .font(.headline)
                    
                    HStack {
                        Text("Sample Rate:")
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("Sample Rate", selection: .constant("auto")) {
                            Text("Auto").tag("auto")
                            Text("16 kHz").tag("16000")
                            Text("44.1 kHz").tag("44100")
                            Text("48 kHz").tag("48000")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 150)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Format Conversion:")
                            .frame(width: 120, alignment: .leading)
                        
                        Toggle("Auto-convert video files", isOn: .constant(true))
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Noise Reduction")
                        .font(.headline)
                    
                    HStack {
                        Toggle("Enable noise reduction", isOn: .constant(false))
                        Spacer()
                    }
                    
                    Text("Note: Noise reduction may improve transcription quality but will increase processing time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Audio", systemImage: "waveform")
            }
            
            // Privacy Settings
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy & Security")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Data Processing")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Prefer on-device processing", isOn: $tempOnDevice)
                            Spacer()
                        }
                        
                        Text("When enabled, transcription will be performed locally when possible, keeping your audio data private.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temporary Files")
                            .font(.headline)
                        
                        HStack {
                            Toggle("Auto-delete temporary files", isOn: .constant(true))
                            Spacer()
                        }
                        
                        Text("Automatically remove temporary audio files created during video processing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Permissions")
                        .font(.headline)
                    
                    HStack {
                        Button("Review Speech Recognition Permission") {
                            openSystemPreferences()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                    
                    Text("Speech Recognition permission is required for transcription functionality.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("Privacy", systemImage: "lock.shield")
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        tempLanguage = appDelegate.language
        tempOutputFormat = appDelegate.outputFormat
        tempOnDevice = appDelegate.onDevice
    }
    
    private func applySettings() {
        appDelegate.language = tempLanguage
        appDelegate.outputFormat = tempOutputFormat
        appDelegate.onDevice = tempOnDevice
        appDelegate.updateConfiguration()
    }
    
    private func resetToDefaults() {
        tempLanguage = "en-US"
        tempOutputFormat = "txt"
        tempOnDevice = true
    }
    
    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppDelegate())
    }
}
#endif