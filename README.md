# Transcriber

A modern MacOS speech recognition CLI tool for transcribing audio files using Apple's built-in Speech framework.

## Features

- **🎨 Beautiful CLI**: Modern interface with colors, icons, and progress bars (inspired by Claude Code)
- **📊 Real-time Progress**: Animated progress bars with status updates
- **🔀 Multiple Output Formats**: Text, JSON, SRT subtitles, and WebVTT
- **📁 Batch Processing**: Process multiple audio files at once with summary
- **🔒 Privacy-First**: On-device recognition option for sensitive content
- **🌍 Multi-Language Support**: 50+ languages with on-device capability indicators
- **⚙️ Configuration Files**: Save default settings in YAML or JSON config files
- **⚡ Modern Swift Architecture**: Built with async/await and SwiftArgumentParser

## Installation

### Quick Install (DMG)

1. Download the latest DMG from the [releases page](https://github.com/jsonify/transcriber/releases)
2. Open the DMG file
3. Drag Transcriber.app to your Applications folder
4. **Important**: Due to macOS security restrictions, you'll need to bypass Gatekeeper on first launch:

```bash
# Remove quarantine attribute to bypass Gatekeeper
xattr -d com.apple.quarantine /Applications/Transcriber.app
```

5. Launch Transcriber.app from Applications

**Alternative method** if the command above doesn't work:
- Right-click Transcriber.app → "Open"
- Click "Open" when macOS warns about unidentified developer
- The app will then launch normally in future

### ⚠️ Important Installation Notes

**Always use the proper app bundle**: The app must be installed as `Transcriber.app` (an app bundle) in `/Applications/`, not as a raw executable file.

- ✅ **Correct**: `/Applications/Transcriber.app/` 
- ❌ **Incorrect**: `/Applications/transcriber` (raw executable)

If you accidentally install a raw executable file, it will open as a text document instead of launching the application. Use the DMG installer to ensure proper installation.

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

### Package Installer (Recommended)

For easy installation and distribution, use the macOS installer package:

```bash
# Create installer package (development - unsigned)
make installer

# Create production installer (signed and notarized)
make installer-production
```

The installer package includes both the CLI tool and native macOS application, and automatically handles permissions and setup.

**Note**: Production installers require Developer ID certificates. See [Code Signing](#code-signing) section below.

## Code Signing

To reduce macOS Gatekeeper warnings, you can configure code signing. There are three approaches available:

### Option 1: Self-Signed Certificates (Recommended for Open Source)

**Best for:** Individual developers, open source projects, or anyone without an Apple Developer account.

```bash
# Create self-signed certificates (no Apple account needed)
make setup-self-signed

# Build signed package
make installer-production
```

**Benefits:**
- ✅ No Apple Developer account required ($0 vs $99/year)
- ✅ Better security than ad-hoc signing
- ✅ Users can easily bypass Gatekeeper with provided instructions
- ⚠️ Still shows Gatekeeper warnings (but with bypass instructions)

### Option 2: Apple Developer ID (Production)

**Best for:** Commercial distribution, maximum user trust.

```bash
# Interactive setup wizard (requires Apple Developer account)
scripts/setup-signing.sh

# Verify configuration
scripts/verify-signing.sh

# Build production package
scripts/build-production.sh
```

**Requirements:**
1. **Apple Developer Program membership** ($99/year)
2. **Developer ID certificates** from Apple Developer Portal
3. **Notarization** setup for best user experience

**Manual Configuration:**

1. **Obtain Developer ID certificates** from Apple Developer Portal
2. **Create `.env` file** (copy from `.env.example`)
3. **Configure environment variables**:

```bash
# Developer ID certificates
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"

# Notarization keychain profile
KEYCHAIN_PROFILE="your-profile-name"
```

4. **Set up notarization profile**:

```bash
xcrun notarytool store-credentials "your-profile-name" \
    --apple-id your@email.com \
    --team-id YOUR_TEAM_ID
```

### Option 3: Ad-hoc Signing (Development Only)

**Best for:** Development, testing, personal use.

```bash
# Uses default ad-hoc signing
make build-release
make sign
```

### Code Signing Commands

```bash
# Check current signing configuration
make check-signing-environment

# Set up self-signed certificates (recommended)
make setup-self-signed

# Verify certificates
make verify-certificates

# Build with current signing configuration
make installer-production
```

**Signing Modes:**
- **Ad-hoc**: No certificates (default, shows Gatekeeper warnings)
- **Self-signed**: Self-generated certificates (shows warnings with bypass instructions)
- **Developer ID**: Apple certificates (minimal or no Gatekeeper warnings)

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

## Configuration Files

Save time by creating configuration files with your preferred settings instead of passing the same arguments repeatedly.

### Supported Configuration Files

The transcriber automatically searches for configuration files in this order:
1. Custom config file (specified with `--config`)
2. Project root: `./.transcriber.yaml` or `./.transcriber.json`
3. Home directory: `~/.transcriber.yaml` or `~/.transcriber.json`

### Generate Sample Configuration

```bash
# Generate a sample configuration file
transcriber --generate-config

# Generate config in specific format and location
transcriber --generate-config --format yaml --output ~/.transcriber.yaml
```

### Configuration Examples

**YAML format (.transcriber.yaml):**
```yaml
# Default transcription settings
language: "en-US"
format: "txt"
onDevice: false
outputDir: "./transcripts"
verbose: false
showProgress: true
noColor: false
```

**JSON format (.transcriber.json):**
```json
{
  "language": "en-US",
  "format": "json",
  "onDevice": true,
  "outputDir": "./results",
  "verbose": true,
  "showProgress": true,
  "noColor": false
}
```

### Usage with Configuration

```bash
# Use default config file
transcriber audio.wav

# Override config with CLI arguments
transcriber audio.wav --format srt --language es-ES

# Use custom config file
transcriber audio.wav --config my-config.yaml
```

**Note:** Command-line arguments always override configuration file settings.

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
| `--config` | Path to custom configuration file |
| `--generate-config` | Generate sample configuration file |
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

### macOS Gatekeeper "App is Damaged" Error

If macOS blocks the app with errors like "Transcriber is damaged and can't be opened" or "App cannot be opened because the developer cannot be verified":

**Quick Fix (Recommended):**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/Transcriber.app
```

**Alternative Method:**
1. Right-click Transcriber.app in Applications
2. Select "Open" from the context menu
3. Click "Open" when macOS warns about unidentified developer
4. App will launch normally in future

**Why This Happens:**
- macOS Gatekeeper blocks unsigned or self-signed applications
- This is a security feature, not a virus or actual damage
- The bypass methods above are safe and standard practice

**Permanent Solution:**
```bash
# Set up better code signing (no Apple account needed)
make setup-self-signed
make installer-production
```

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
