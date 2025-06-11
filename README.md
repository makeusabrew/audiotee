# audiotee

A command-line utility for capturing system audio on macOS and streaming it to stdout as JSON-delimited messages. Designed to be run as a child process for real-time audio streaming.

## Requirements

- macOS >= 14.2
- System audio recording permission
- Grant your terminal emulator permissions via System Settings > Privacy & Security > Screen & System Audio Recording

## Build

```bash
swift build -c release
```

## Run

```bash
.build/arm64-apple-macosx/release/tower-audio
```

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

Uses Core Audio HAL to create a process tap and aggregate device for system audio capture. Audio is streamed in 200ms chunks in the device's native format without any processing.

## References

- [Apple Core Audio Taps Documentation](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [AudioCap Implementation](https://github.com/insidegui/AudioCap)