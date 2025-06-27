import XCTest
@testable import TranscriberCore

final class TranscriberTests: XCTestCase {
    
    func testTranscriptionResultCreation() {
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0.0, endTime: 1.0, confidence: 0.9),
            TranscriptionSegment(text: "World", startTime: 1.0, endTime: 2.0, confidence: 0.8)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.fullText, "Hello World")
        XCTAssertEqual(result.duration, 2.0)
        XCTAssertEqual(result.language, "en-US")
        XCTAssertTrue(result.isOnDevice)
        XCTAssertEqual(result.averageConfidence, 0.85, accuracy: 0.01)
    }
    
    func testOutputFormatterText() {
        let segments = [
            TranscriptionSegment(text: "Hello World", startTime: 0.0, endTime: 2.0, confidence: 0.9)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        let textOutput = OutputFormatter.format(result, as: .text)
        XCTAssertEqual(textOutput, "Hello World")
    }
    
    func testOutputFormatterSRT() {
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0.0, endTime: 1.0, confidence: 0.9),
            TranscriptionSegment(text: "World", startTime: 1.0, endTime: 2.0, confidence: 0.8)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.0,
            language: "en-US",
            isOnDevice: true
        )
        
        let srtOutput = OutputFormatter.format(result, as: .srt)
        
        XCTAssertTrue(srtOutput.contains("1"))
        XCTAssertTrue(srtOutput.contains("00:00:00,000 --> 00:00:01,000"))
        XCTAssertTrue(srtOutput.contains("Hello"))
        XCTAssertTrue(srtOutput.contains("2"))
        XCTAssertTrue(srtOutput.contains("00:00:01,000 --> 00:00:02,000"))
        XCTAssertTrue(srtOutput.contains("World"))
    }
    
    func testOutputFormatterVTT() {
        let segments = [
            TranscriptionSegment(text: "Hello World", startTime: 0.0, endTime: 2.5, confidence: 0.9)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Hello World",
            duration: 2.5,
            language: "en-US",
            isOnDevice: true
        )
        
        let vttOutput = OutputFormatter.format(result, as: .vtt)
        
        XCTAssertTrue(vttOutput.hasPrefix("WEBVTT"))
        XCTAssertTrue(vttOutput.contains("00:00.000 --> 00:02.500"))
        XCTAssertTrue(vttOutput.contains("Hello World"))
    }
    
    func testOutputFormatterJSON() {
        let segments = [
            TranscriptionSegment(text: "Test", startTime: 0.0, endTime: 1.0, confidence: 0.95)
        ]
        
        let result = TranscriptionResult(
            segments: segments,
            fullText: "Test",
            duration: 1.0,
            language: "en-US",
            isOnDevice: false
        )
        
        let jsonOutput = OutputFormatter.format(result, as: .json)
        
        XCTAssertTrue(jsonOutput.contains("\"text\" : \"Test\""))
        XCTAssertTrue(jsonOutput.contains("\"language\" : \"en-US\""))
        XCTAssertTrue(jsonOutput.contains("\"duration\" : 1"))
        XCTAssertTrue(jsonOutput.contains("\"isOnDevice\" : false"))
        XCTAssertTrue(jsonOutput.contains("segments"))
    }
    
    func testTranscriptionErrors() {
        let fileNotFoundError = TranscriptionError.fileNotFound("/path/to/missing.wav")
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("not found"))
        
        let unsupportedFormatError = TranscriptionError.unsupportedFormat("xyz")
        XCTAssertTrue(unsupportedFormatError.localizedDescription.contains("Unsupported"))
        
        let permissionError = TranscriptionError.speechRecognitionDenied
        XCTAssertTrue(permissionError.localizedDescription.contains("permission"))
    }
    
    func testOutputFormatCases() {
        XCTAssertEqual(OutputFormat.text.fileExtension, "txt")
        XCTAssertEqual(OutputFormat.json.fileExtension, "json")
        XCTAssertEqual(OutputFormat.srt.fileExtension, "srt")
        XCTAssertEqual(OutputFormat.vtt.fileExtension, "vtt")
        
        XCTAssertEqual(OutputFormat.allCases.count, 4)
    }
}