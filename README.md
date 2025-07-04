# AudioTee

AudioTee captures your Mac's system audio output and writes it in PCM encoded chunks to `stdout` at regular intervals, either in base64-encoded JSON (good for humans, easy on terminals) or binary (good for other programs). It uses the [Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) API introduced in macOS 14.2 (released in December 2023). You can do whatever you want with this audio - stream it somewhere else, save it to disk, visualize it, etc.

By default, it taps the audio output from **all** running process and selects the most appropriate audio chunk output format to use based on the presence of a tty. Tap output is forced to `mono` (not yet configurable) and preserves your output device's sample rate (configurable via the `--sample-rate` flag). Only the default output device is currently supported.

My original (and so far only) use case is streaming audio to a parent process which communicates with a realtime ASR service, so AudioTee makes some design decisions you might not agree with. Open an issue or a PR and we can talk about them. I'm also no Swift developer, so contributions improving codebase idioms and general hygiene are welcome.

Recording system audio is harder than it should be on macOS, and folks often wrestle with outdated advice and poorly documented APIs. It's a boring problem which stands in the way of lots of fun applications. There's more code here than you need to solve this problem yourself: the main classes of interest are probably [`Core/AudioTapManager`](https://github.com/makeusabrew/audiotee/blob/main/Sources/Core/AudioTapManager.swift) and [`Core/AudioRecorder`](https://github.com/makeusabrew/audiotee/blob/main/Sources/Core/AudioRecorder.swift). Everything's wired together in [`CLI/AudioTee`](https://github.com/makeusabrew/audiotee/blob/main/Sources/CLI/AudioTee.swift). The rest is just CLI configuration support, output formatting logic, and some utility functions you could probably live without.

## Requirements

- macOS 14.2 or later
- Swift 5.9 or later (no need for XCode)
- System audio recording permissions (see below)

## Quick start

The following will start capturing audio output from all running programs and write base64-encoded chunks of it to your terminal every 200ms:

```bash
git clone git@github.com:makeusabrew/audiotee.git
cd audiotee
swift run
```

If you're not playing audio when you run it, you'll just see packets full of `AAAAA...` - the base64 version of a bunch of zeroes.

## Build

```bash
# omit '-c release' to get a debug build
swift build -c release
```

## Usage

### Permission management

AudioTee requires system audio recording permissions to work. Use these commands to check and request permissions:

```bash
# Check current audio recording permissions
./audiotee --permissions

# Request audio recording permissions (will prompt user)
./audiotee --permissions --request
```

### Basic usage

Replace the path below with `.build/<arch>/<target>/audiotee`, e.g. `build/arm64-apple-macosx/release/audiotee` for a release build on Apple Silicon.

```bash
# Auto-detect output format (JSON in terminal, binary when piped)
./audiotee

# Always use JSON format (terminal-safe)
./audiotee --format json

# Always use binary format (pipe-optimised)
./audiotee --format binary
```

### Audio conversion

Note that performing sample rate conversion will also convert the output bit depth to
16-bit - assuming an original depth of 32-bit this results in a loss of dynamic range in exchange for half the output chunk size. For ASR services, 16-bit is sufficient, but in any case it's a behaviour worth being aware of.

```bash
# Convert to 16kHz mono (useful for ASR services)
./audiotee --sample-rate 16000

# Other supported sample rates: 22050, 24000, 32000, 44100, 48000
./audiotee --sample-rate 44100
```

### Tap configuration

For now, only a subset of the `CATapDescription` (https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) interface is exposed. PRs welcome.

Note that trying to include or exclude a PID which isn't currently playing audio will probably fail to convert to an Audio Object and will cause the process to exit.

```bash
# Tap all system audio (default)
./audiotee

# Tap only a specific process (by PID)
./audiotee --include-processes 1234

# Tap multiple specific processes
./audiotee --include-processes 1234 5678 9012

# Tap everything *except* a specific process (by PID)
./audiotee --exclude-processes 1234

# Exclude multiple specific processes
./audiotee --exclude-processes 1234 5678 9012
```

```bash
# Mute processes being tapped (so they don't play through speakers)
./audiotee --mute

# Custom chunk duration (default 0.2 seconds, max 5.0)
./audiotee --chunk-duration 0.1
```

## Output formats

AudioTee supports two output formats optimised for different use cases:

### JSON format (`--format json` or auto in terminal)

JSON messages to stdout, one per line. Audio data is base64-encoded for terminal safety.

### Binary format (`--format binary` or auto when piped)

JSON metadata lines followed by raw binary audio data. More efficient for piping to other processes.

## Protocol

### Message types

All messages (except raw binary audio chunks) follow this envelope structure:

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "...",
  "data": { ... }
}
```

#### 1. Metadata

Sent once at startup to describe the audio format:

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "metadata",
  "data": {
    "sample_rate": 48000,
    "channels_per_frame": 1,
    "bits_per_channel": 32,
    "is_float": true,
    "capture_mode": "audio",
    "device_name": null,
    "device_uid": null,
    "encoding": "pcm_f32le"
  }
}
```

#### 2. Stream start

Indicates audio data will follow:

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "stream_start",
  "data": null
}
```

#### 3. Audio data

**JSON format:**

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "audio",
  "data": {
    "timestamp": "2024-03-21T15:30:45.123Z",
    "duration": 0.2,
    "peak_amplitude": 0.45,
    "audio_data": "base64_encoded_raw_audio..."
  }
}
```

**Binary format:**

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "audio",
  "data": {
    "timestamp": "2024-03-21T15:30:45.123Z",
    "duration": 0.2,
    "peak_amplitude": 0.45,
    "audio_length": 9600
  }
}
```

_Followed immediately by 9600 bytes of raw binary audio data_

#### 4. Stream stop

Sent when recording stops:

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "stream_stop",
  "data": null
}
```

#### 5. Log messages

Info, error, and debug messages (useful for monitoring):

```json
{
  "timestamp": "2024-03-21T15:30:45.123Z",
  "message_type": "info",
  "data": {
    "message": "Starting AudioTee...",
    "context": { "output_format": "auto" }
  }
}
```

### Consuming output

**JSON format:**

1. Parse each line as JSON using the envelope structure
2. Use `metadata` message to understand the audio format
3. For `audio` messages, decode `audio_data` from base64 to get raw PCM data
4. Do something with each chunk of data

**Binary format:**

1. Parse JSON metadata lines using the envelope structure
2. Use `metadata` message to understand the audio format
3. For `audio` messages, read `audio_length` bytes of raw binary data after the JSON line
4. Do something with each chunk of data

**Note**: binary is actually a mixed mode; JSON during boot, JSON packet header information preceding each binary chunk.

## Command Line options

- `--format, -f`: Output format (`json`, `binary`, `auto`) [default: `auto`]
- `--include-processes`: Process IDs to tap (space-separated, empty = all processes)
- `--exclude-processes`: Process IDs to exclude (space-separated, empty = none)
- `--mute`: Mute processes being tapped
- `--sample-rate`: Target sample rate (8000, 16000, 22050, 24000, 32000, 44100, 48000)
- `--chunk-duration`: Audio chunk duration in seconds [default: 0.2, max: 5.0]

## Permissions

There is no provision in the code to pre-emptively check for the required `NSAudioCaptureUsageDescription` permission,
so you'll be prompted the first time AudioTee tries to record anything. If you want to check and/or request permissions ahead of time, check out [AudioCap's clever TCC probing approach](https://github.com/insidegui/AudioCap/blob/main/AudioCap/ProcessTap/AudioRecordingPermission.swift).

## References

- [Apple Core Audio Taps Documentation](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [AudioCap Implementation](https://github.com/insidegui/AudioCap)

## License

### The MIT License

Copyright (C) 2025 Nick Payne.
