# audiotee

A command-line utility for capturing system audio or microphone input on macOS and streaming it to stdout as JSON-delimited messages. Designed to be run as a child process for real-time audio streaming.

## Requirements

- macOS >= 14.2
- For system audio: System audio recording permission
- For microphone: Microphone access permission  
- Grant your terminal emulator permissions via System Settings > Privacy & Security > Screen & System Audio Recording (for system audio) or Microphone (for mic input)

## Build

```bash
swift build -c release
```

## Run

### System Audio Mode (Default)
Captures all system audio output:
```bash
.build/arm64-apple-macosx/release/audiotee
# or explicitly
.build/arm64-apple-macosx/release/audiotee system
```

### Microphone Mode  
Captures microphone input with echo cancellation enabled:
```bash
.build/arm64-apple-macosx/release/audiotee mic
```

The echo cancellation is crucial for microphone recording as it prevents audio feedback loops and improves speech recognition quality.

## Protocol

The program outputs JSON messages to stdout, one per line. Audio data is captured in the device's native format (sample rate, channels, bit depth) without any conversion.

### Message Types

1. **metadata** - Audio format details:
```json
{
  "message_type": "metadata",
  "data": {
    "sample_rate": 48000,
    "channels_per_frame": 2,
    "bits_per_channel": 32,
    "is_float": true,
    "encoding": "pcm_f32le"
  }
}
```

2. **stream_start** - Indicates audio data will follow:
```json
{
  "message_type": "stream_start",
  "data": null
}
```

3. **audio** - Raw audio data chunks:
```json
{
  "message_type": "audio",
  "data": {
    "timestamp": "2024-03-21T15:30:45.123Z",
    "duration": 0.2,
    "audio_data": "base64_encoded_raw_audio..."
  }
}
```

4. **error** - Error messages:
```json
{
  "message_type": "error",
  "data": "Error description"
}
```

### Consuming Output

Host programs should:
1. Parse each line as JSON
2. Use `metadata` to understand the audio format
3. Decode `audio_data` from base64 to get raw PCM data
4. Handle the native format (no conversion performed)

## Implementation

### System Audio Mode
Uses Core Audio HAL to create a process tap and aggregate device for system audio capture. Audio is streamed in 200ms chunks in the device's native format without any processing.

### Microphone Mode  
Uses Core Audio HAL with AudioUnit for microphone input with the following features:
- **Echo cancellation enabled** via `kAUVoiceIOProperty_BypassVoiceProcessing` 
- Continuous audio capture (no voice activity detection - streams everything)
- Shared access (allows other apps to use microphone simultaneously)
- Direct device access for minimal latency

Audio is streamed in 200ms chunks in a consistent 16-bit mono format at 44.1kHz.

## References

- [Apple Core Audio Taps Documentation](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [AudioCap Implementation](https://github.com/insidegui/AudioCap)