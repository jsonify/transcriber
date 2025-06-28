import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Transcriber")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Modern macOS Speech Recognition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                Text("Features")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "brain.head.profile", text: "On-device and server-based speech recognition")
                    FeatureRow(icon: "globe", text: "Support for multiple languages")
                    FeatureRow(icon: "doc.text", text: "Multiple output formats (TXT, JSON, SRT, VTT)")
                    FeatureRow(icon: "video", text: "Automatic video to audio conversion")
                    FeatureRow(icon: "speedometer", text: "High-performance batch processing")
                    FeatureRow(icon: "lock.shield", text: "Privacy-first design")
                }
            }
            
            Divider()
            
            // Technology
            VStack(alignment: .leading, spacing: 12) {
                Text("Built With")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    TechRow(name: "Swift", description: "Modern, safe programming language")
                    TechRow(name: "SwiftUI", description: "Declarative user interface framework")
                    TechRow(name: "Speech Framework", description: "Apple's speech recognition technology")
                    TechRow(name: "AVFoundation", description: "Audio and video processing")
                }
            }
            
            Spacer()
            
            // Links
            HStack(spacing: 20) {
                Button("GitHub Repository") {
                    if let url = URL(string: "https://github.com/jsonify/transcriber") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Report Issue") {
                    if let url = URL(string: "https://github.com/jsonify/transcriber/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // Copyright
            VStack(spacing: 4) {
                Text("© 2025 Transcriber Project")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Open source software built with ❤️")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .frame(width: 400, height: 600)
        .background(Color(.windowBackgroundColor))
        .overlay(
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.top, 15)
            .padding(.trailing, 15),
            alignment: .topTrailing
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct TechRow: View {
    let name: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif