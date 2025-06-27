import Foundation

public enum OutputFormat: String, CaseIterable {
    case text = "txt"
    case json = "json"
    case srt = "srt"
    case vtt = "vtt"
    
    public var fileExtension: String {
        return self.rawValue
    }
}

public struct OutputFormatter {
    public static func format(_ result: TranscriptionResult, as format: OutputFormat) -> String {
        switch format {
        case .text:
            return formatAsText(result)
        case .json:
            return formatAsJSON(result)
        case .srt:
            return formatAsSRT(result)
        case .vtt:
            return formatAsVTT(result)
        }
    }
    
    private static func formatAsText(_ result: TranscriptionResult) -> String {
        return result.fullText
    }
    
    private static func formatAsJSON(_ result: TranscriptionResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = TranscriptionJSON(
            text: result.fullText,
            language: result.language,
            duration: result.duration,
            isOnDevice: result.isOnDevice,
            averageConfidence: result.averageConfidence,
            segments: result.segments.map { segment in
                TranscriptionSegmentJSON(
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    confidence: segment.confidence
                )
            },
            metadata: TranscriptionMetadataJSON(
                segmentCount: result.segments.count,
                transcribedAt: Date()
            )
        )
        
        do {
            let data = try encoder.encode(jsonData)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error encoding JSON: \(error.localizedDescription)"
        }
    }
    
    private static func formatAsSRT(_ result: TranscriptionResult) -> String {
        var srtOutput = ""
        
        for (index, segment) in result.segments.enumerated() {
            let startTime = formatTimeForSRT(segment.startTime)
            let endTime = formatTimeForSRT(segment.endTime)
            
            srtOutput += "\(index + 1)\n"
            srtOutput += "\(startTime) --> \(endTime)\n"
            srtOutput += "\(segment.text)\n\n"
        }
        
        return srtOutput
    }
    
    private static func formatAsVTT(_ result: TranscriptionResult) -> String {
        var vttOutput = "WEBVTT\n\n"
        
        for segment in result.segments {
            let startTime = formatTimeForVTT(segment.startTime)
            let endTime = formatTimeForVTT(segment.endTime)
            
            vttOutput += "\(startTime) --> \(endTime)\n"
            vttOutput += "\(segment.text)\n\n"
        }
        
        return vttOutput
    }
    
    private static func formatTimeForSRT(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    private static func formatTimeForVTT(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%06.3f", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%06.3f", minutes, seconds)
        }
    }
}

private struct TranscriptionJSON: Codable {
    let text: String
    let language: String
    let duration: TimeInterval
    let isOnDevice: Bool
    let averageConfidence: Float
    let segments: [TranscriptionSegmentJSON]
    let metadata: TranscriptionMetadataJSON
}

private struct TranscriptionSegmentJSON: Codable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

private struct TranscriptionMetadataJSON: Codable {
    let segmentCount: Int
    let transcribedAt: Date
}