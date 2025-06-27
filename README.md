# Transcriber

A modern MacOS speech recognition CLI tool for transcribing audio files using Apple's built-in Speech framework.

## Features

- **🎨 Beautiful CLI**: Modern interface with colors, icons, and progress bars (inspired by Claude Code)
- **📊 Real-time Progress**: Animated progress bars with status updates
- **🔀 Multiple Output Formats**: Text, JSON, SRT subtitles, and WebVTT
- **📁 Batch Processing**: Process multiple audio files at once with summary
- **🔒 Privacy-First**: On-device recognition option for sensitive content
- **🌍 Multi-Language Support**: 50+ languages with on-device capability indicators
- **⚡ Modern Swift Architecture**: Built with async/await and SwiftArgumentParser

## Installation

### Build from Source

```bash
git clone <repository-url>
cd transcriber

# Build with proper entitlements (recommended)
./build-signed.sh

# Install system-wide
sudo cp .build/release/transcriber /usr/local/bin/
```

### Requirements

- macOS 13.0 or later
- Speech recognition permissions (granted on first use)

## Usage

### Basic Usage

```bash
# Transcribe a single file to text
transcriber audio.wav

# Transcribe with specific output file
transcriber audio.wav --output transcript.txt

# Transcribe to JSON format
transcriber audio.wav --format json --output result.json
```

### Batch Processing

```bash
# Process multiple files
transcriber *.wav --format txt --output-dir ./transcripts

# Process with verbose output
transcriber audio1.wav audio2.mp3 --verbose --output-dir ./results
```

### Subtitle Generation

```bash
# Generate SRT subtitles
transcriber video_audio.wav --format srt --output subtitles.srt

# Generate WebVTT subtitles
transcriber presentation.m4a --format vtt --output captions.vtt
```

### Language Support

```bash
# List all supported languages
transcriber --list-languages

# Transcribe in Spanish
transcriber spanish_audio.wav --language es-ES

# Use on-device recognition (more private, limited languages)
transcriber audio.wav --language en-US --on-device
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--format`, `-f` | Output format: txt, json, srt, vtt (default: txt) |
| `--output`, `-o` | Output file path |
| `--output-dir` | Output directory for batch processing |
| `--language`, `-l` | Language code (default: en-US) |
| `--on-device` | Use on-device recognition for privacy |
| `--verbose`, `-v` | Show detailed output with file info and stats |
| `--show-progress` | Display animated progress bars |
| `--no-color` | Disable colors and progress bars |
| `--list-languages` | List all supported languages with capability indicators |
| `--help` | Show help information |
| `--version` | Show version |

## Supported Audio Formats

The tool supports all audio formats supported by macOS CoreAudio:
- WAV, MP3, AIFF, AAC, CAF, ALAC
- M4A, MP4 audio tracks
- And many more...

## Output Formats

### Text (.txt)
Plain text transcription

### JSON (.json)
Structured output with metadata:
```json
{
  "text": "Full transcription text",
  "language": "en-US",
  "duration": 45.2,
  "isOnDevice": true,
  "averageConfidence": 0.95,
  "segments": [
    {
      "text": "Segment text",
      "startTime": 0.0,
      "endTime": 5.2,
      "confidence": 0.98
    }
  ],
  "metadata": {
    "segmentCount": 1,
    "transcribedAt": "2025-01-01T12:00:00Z"
  }
}
```

### SRT (.srt)
Standard subtitle format:
```
1
00:00:00,000 --> 00:00:05,200
Segment text

2
00:00:05,200 --> 00:00:10,500
Next segment text
```

### WebVTT (.vtt)
Web Video Text Tracks format:
```
WEBVTT

00:00.000 --> 05.200
Segment text

05.200 --> 10.500
Next segment text
```

## Privacy

- Use `--on-device` flag for completely local transcription
- Without this flag, data may be sent to Apple servers for processing
- On-device recognition supports fewer languages but provides complete privacy
- No data is stored or transmitted by this tool itself

## Troubleshooting

### Abort Signal (Process Killed)
If you get `[1] XXXX abort transcriber file.mp3`, this is due to missing Speech Recognition entitlements:

1. **Always use the signed build script (recommended):**
   ```bash
   ./build-signed.sh
   .build/release/transcriber file.mp3
   ```

2. **Install the properly signed version:**
   ```bash
   sudo cp .build/release/transcriber /usr/local/bin/
   transcriber file.mp3
   ```

3. **Verify with verbose output:**
   ```bash
   transcriber file.mp3 --verbose
   ```

The signed build applies proper macOS entitlements required for Speech Recognition access.

### Permission Issues
**First Run:** The app will request Speech Recognition permission automatically.

If you get permission errors:
1. Go to System Preferences > Security & Privacy > Privacy
2. Select "Speech Recognition" 
3. Add Terminal or your terminal app to the list
4. Or add the `transcriber` binary directly

### File Not Found
```bash
# Check current directory
ls *.mp3 *.wav *.m4a

# Use full path
transcriber "/full/path/to/audio.mp3"

# Use verbose mode to see what's happening
transcriber audio.mp3 --verbose
```

### Language Not Supported
```bash
# List all supported languages
transcriber --list-languages

# Some languages only work with server-based recognition
transcriber audio.mp3 --language es-ES  # Server-based
transcriber audio.mp3 --language en-US --on-device  # On-device
```

### Audio File Issues
- Ensure file is in supported format: WAV, MP3, M4A, AIFF, AAC, etc.
- Check file isn't corrupted: `file audio.mp3`
- Try with a different audio file
- Use verbose mode to see detailed error information

## Examples

### Beautiful CLI in Action

```bash
# Basic transcription with beautiful output
transcriber interview.wav

# 🎙️  Transcriber v1.0.0
#    Modern macOS Speech Recognition
# 
# 📋 Configuration
#    Language: en-US
#    Format: txt
#    Mode: Server-based
#    Files: 1
# 
# 🎤 Processing [1/1] interview.wav
#    Starting transcription...
#    [████████████████████████████████] 100% Complete!
# ✅ Transcription Complete
# 
# 📄 Transcription:
#    "Welcome to today's interview..."

# Batch processing with progress bars
transcriber *.mp3 --format json --output-dir results --verbose

# Generate subtitles with real-time progress
transcriber movie_audio.wav --format srt --output movie.srt --show-progress

# Privacy-focused with on-device recognition
transcriber sensitive_meeting.wav --on-device --language en-US

# See beautiful language listing
transcriber --list-languages

# 🌍 Supported Languages
# 
#    🔒 On-device (Private)
#       ● en-US
#       ● en-ID
#       ● en-PH
#       ● en-SA
# 
#    🌐 Server-based
#       ● ar-SA
#       ● es-ES
#       ● fr-FR
#       ...
```
