import SwiftUI
import TranscriberCore

struct FileListItemView: View {
    let fileItem: FileItem
    let onPlay: () -> Void
    let onDelete: () -> Void
    
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
                    
                    if fileItem.status == .processing {
                        Text("Processing")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    } else if fileItem.status == .done {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Done")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    } else if fileItem.status == .error {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("Error")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Pending")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Play button
                Button(action: onPlay) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(fileItem.status == .processing)
                
                // Delete button
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
            if fileItem.status == .processing {
                GeometryReader { geometry in
                    HStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width * fileItem.progress)
                        Spacer()
                    }
                }
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
                onDelete: {}
            )
            .background(Color.black)
            
            FileListItemView(
                fileItem: {
                    var item = FileItem(url: URL(string: "file:///interview-audio.wav")!)
                    item.status = .processing
                    item.progress = 0.6
                    return item
                }(),
                onPlay: {},
                onDelete: {}
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
                onDelete: {}
            )
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
    }
}
#endif