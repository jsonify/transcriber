import SwiftUI
import TranscriberCore

struct FileListItemView: View {
    let fileItem: FileItem
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onStartTranscription: () -> Void
    let onCancelTranscription: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: getFileIcon())
                .font(.system(size: 20))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileItem.url.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(fileItem.duration.isEmpty ? "Unknown duration" : fileItem.duration)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // Enhanced status indicators
                    switch fileItem.status {
                    case .pending:
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("Ready to start")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    case .queued:
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Queued")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    case .processing:
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("Processing \(Int(fileItem.progress * 100))%")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                            if !fileItem.progressMessage.isEmpty {
                                Text(fileItem.progressMessage)
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                        }
                    case .done:
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Complete")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    case .error:
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                Text("Error")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                            if let errorMessage = fileItem.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    case .cancelled:
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Cancelled")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Primary action button (context-aware)
                switch fileItem.status {
                case .pending, .error, .cancelled:
                    // Start Transcription button
                    Button(action: onStartTranscription) {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 16))
                            Text("Start")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                case .queued, .processing:
                    // Cancel button
                    Button(action: onCancelTranscription) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle")
                                .font(.system(size: 16))
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                case .done:
                    // Play button for completed files
                    Button(action: onPlay) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                // Delete button (always available except when processing)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .disabled(fileItem.status == .processing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            // Enhanced progress indicator
            switch fileItem.status {
            case .queued:
                // Subtle queued indicator
                Rectangle()
                    .fill(Color.orange.opacity(0.1))
            case .processing:
                // Animated progress bar
                GeometryReader { geometry in
                    HStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width * fileItem.progress)
                            .animation(.easeInOut(duration: 0.3), value: fileItem.progress)
                        Spacer()
                    }
                }
            case .done:
                // Success indicator
                Rectangle()
                    .fill(Color.green.opacity(0.1))
            case .error:
                // Error indicator
                Rectangle()
                    .fill(Color.red.opacity(0.1))
            default:
                EmptyView()
            }
        }
    }
    
    private func getFileIcon() -> String {
        let pathExtension = fileItem.url.pathExtension.lowercased()
        switch pathExtension {
        case "wav", "mp3", "m4a", "aac", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        default:
            return "doc.fill"
        }
    }
}

#if DEBUG
struct FileListItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FileListItemView(
                fileItem: FileItem(url: URL(string: "file:///meeting-recording.mp4")!),
                onPlay: {},
                onDelete: {},
                onStartTranscription: {},
                onCancelTranscription: {}
            )
            .background(Color.black)
            
            FileListItemView(
                fileItem: {
                    var item = FileItem(url: URL(string: "file:///interview-audio.wav")!)
                    item.status = .processing
                    item.progress = 0.6
                    item.progressMessage = "Processing speech patterns..."
                    return item
                }(),
                onPlay: {},
                onDelete: {},
                onStartTranscription: {},
                onCancelTranscription: {}
            )
            .background(Color.black)
            
            FileListItemView(
                fileItem: {
                    var item = FileItem(url: URL(string: "file:///presentation.mp3")!)
                    item.status = .done
                    item.duration = "1:12:45"
                    return item
                }(),
                onPlay: {},
                onDelete: {},
                onStartTranscription: {},
                onCancelTranscription: {}
            )
            .background(Color.black)
            
            // Additional preview for new states
            FileListItemView(
                fileItem: {
                    var item = FileItem(url: URL(string: "file:///queued-file.mp3")!)
                    item.status = .queued
                    item.duration = "0:45:30"
                    return item
                }(),
                onPlay: {},
                onDelete: {},
                onStartTranscription: {},
                onCancelTranscription: {}
            )
            .background(Color.black)
            
            FileListItemView(
                fileItem: {
                    var item = FileItem(url: URL(string: "file:///error-file.wav")!)
                    item.status = .error
                    item.duration = "0:23:15"
                    item.errorMessage = "Speech recognition not available"
                    return item
                }(),
                onPlay: {},
                onDelete: {},
                onStartTranscription: {},
                onCancelTranscription: {}
            )
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
    }
}
#endif