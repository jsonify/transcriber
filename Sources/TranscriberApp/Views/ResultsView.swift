import SwiftUI
import TranscriberCore

struct ResultsView: View {
    let results: [TranscriptionResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with summary
                VStack(spacing: 10) {
                    Text("Transcription Results")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 20) {
                        Label("\(results.count)", systemImage: "doc.text")
                        Label(totalDurationText, systemImage: "clock")
                        Label(averageConfidenceText, systemImage: "checkmark.seal")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                Divider()
                
                // Results list
                List {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        ResultItemView(result: result, index: index + 1)
                    }
                }
                .listStyle(.inset)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Export All") {
                        exportAllResults()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var totalDurationText: String {
        let totalSeconds = results.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private var averageConfidenceText: String {
        let avgConfidence = results.reduce(0) { $0 + $1.averageConfidence } / Float(results.count)
        return "\(Int(avgConfidence * 100))%"
    }
    
    private func exportAllResults() {
        // Implementation for exporting all results
        // This could open a save panel and export in various formats
    }
}

struct ResultItemView: View {
    let result: TranscriptionResult
    let index: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text("File \(index)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Metadata badges
                HStack(spacing: 8) {
                    Badge(text: result.language, color: .blue)
                    Badge(text: result.isOnDevice ? "On-device" : "Server", color: result.isOnDevice ? .green : .orange)
                    Badge(text: "\(Int(result.averageConfidence * 100))%", color: confidenceColor)
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            // Duration and basic info
            HStack {
                Text(durationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if result.segments.count > 1 {
                    Text("• \(result.segments.count) segments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Full text preview
            Text(result.fullText.prefix(150) + (result.fullText.count > 150 ? "..." : ""))
                .font(.body)
                .lineLimit(isExpanded ? nil : 2)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
            // Expanded content - segments
            if isExpanded && result.segments.count > 1 {
                Divider()
                    .padding(.vertical, 4)
                
                Text("Segments")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.bottom, 4)
                
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { _, segment in
                        SegmentView(segment: segment)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var durationText: String {
        let minutes = Int(result.duration) / 60
        let seconds = Int(result.duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private var confidenceColor: Color {
        if result.averageConfidence > 0.8 {
            return .green
        } else if result.averageConfidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct SegmentView: View {
    let segment: TranscriptionSegment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeRangeText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .padding(.top, 1)
            
            Text(segment.text)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(Int(segment.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(confidenceColor)
                .frame(width: 35, alignment: .trailing)
                .padding(.top, 1)
        }
        .padding(.vertical, 2)
    }
    
    private var timeRangeText: String {
        let startMin = Int(segment.startTime) / 60
        let startSec = Int(segment.startTime) % 60
        let endMin = Int(segment.endTime) / 60
        let endSec = Int(segment.endTime) % 60
        
        return "\(startMin):\(String(format: "%02d", startSec))-\(endMin):\(String(format: "%02d", endSec))"
    }
    
    private var confidenceColor: Color {
        if segment.confidence > 0.8 {
            return .green
        } else if segment.confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

#if DEBUG
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSegments = [
            TranscriptionSegment(text: "Hello, this is a test transcription.", startTime: 0.0, endTime: 2.5, confidence: 0.95),
            TranscriptionSegment(text: "This is the second segment of our test.", startTime: 2.5, endTime: 5.0, confidence: 0.88)
        ]
        
        let sampleResult = TranscriptionResult(
            segments: sampleSegments,
            fullText: "Hello, this is a test transcription. This is the second segment of our test.",
            duration: 5.0,
            language: "en-US",
            isOnDevice: true
        )
        
        ResultsView(results: [sampleResult])
    }
}
#endif