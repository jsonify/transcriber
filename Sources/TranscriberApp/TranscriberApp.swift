import SwiftUI
import TranscriberCore

@main
struct TranscriberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Audio Files...") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("o")
            }
        }
    }
}