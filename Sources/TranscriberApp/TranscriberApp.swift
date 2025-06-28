import SwiftUI
import TranscriberCore

@main
struct TranscriberApp: App {
    @StateObject private var appDelegate = AppDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("Open Audio Files...") {
                    appDelegate.openFileDialog()
                }
                .keyboardShortcut("o")
                
                Divider()
                
                Button("Clear Files") {
                    appDelegate.clearFiles()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(appDelegate.selectedFiles.isEmpty)
            }
            
            // Edit Menu Additions
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Select All Files") {
                    // Implementation for selecting all files
                }
                .keyboardShortcut("a")
                .disabled(appDelegate.selectedFiles.isEmpty)
            }
            
            // View Menu
            CommandGroup(after: .sidebar) {
                Divider()
                
                Button("Show Results") {
                    appDelegate.showResults()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appDelegate.transcriptionResults.isEmpty)
                
                Button("Show Configuration") {
                    appDelegate.showConfiguration()
                }
                .keyboardShortcut(",")
            }
            
            // Tools Menu
            CommandMenu("Tools") {
                Button("Start Transcription") {
                    Task {
                        await appDelegate.startTranscription()
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(appDelegate.selectedFiles.isEmpty || appDelegate.isTranscribing)
                
                Divider()
                
                Menu("Set Language") {
                    ForEach(["en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "ja-JP", "zh-CN"], id: \.self) { lang in
                        Button(languageName(for: lang)) {
                            appDelegate.language = lang
                        }
                    }
                }
                
                Menu("Set Output Format") {
                    ForEach(["txt", "json", "srt", "vtt"], id: \.self) { format in
                        Button(formatName(for: format)) {
                            appDelegate.outputFormat = format
                        }
                    }
                }
                
                Divider()
                
                Toggle("On-Device Recognition", isOn: .constant(appDelegate.onDevice))
                    .toggleStyle(.checkbox)
            }
            
            // Help Menu Additions
            CommandGroup(after: .help) {
                Button("About Transcriber") {
                    appDelegate.showAbout()
                }
                
                Button("Transcriber Help") {
                    appDelegate.showHelp()
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appDelegate)
        }
    }
    
    private func languageName(for code: String) -> String {
        switch code {
        case "en-US": return "English (US)"
        case "en-GB": return "English (UK)"
        case "es-ES": return "Spanish"
        case "fr-FR": return "French"
        case "de-DE": return "German"
        case "ja-JP": return "Japanese"
        case "zh-CN": return "Chinese"
        default: return code
        }
    }
    
    private func formatName(for format: String) -> String {
        switch format {
        case "txt": return "Text (.txt)"
        case "json": return "JSON (.json)"
        case "srt": return "SubRip (.srt)"
        case "vtt": return "WebVTT (.vtt)"
        default: return format
        }
    }
}