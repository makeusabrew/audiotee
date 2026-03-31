# AudioTee

**⚠️ API Instability Warning: The AudioTee API is unstable at present and subject to change without notice.**

AudioTee captures your Mac's system audio output and writes it in PCM encoded chunks to `stdout` at regular intervals. All logging and metadata information is written to `stderr`, meaning at its simplest you can capture whatever's playing through your speakers to a file like this:

```bash
/path/to/audiotee > output.pcm
```

It's more likely you want to capture this output programmatically. Check out [AudioTee.js](https://github.com/makeusabrew/audioteejs) for a simple Node.js package which does this.

System audio is captured using the [Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) API introduced in macOS 14.2 (released in December 2023). You can do whatever you want with this audio - save it to disk, visualise it, transcribe it, etc.

By default, AudioTee captures audio output from **all** running processes. Tap output defaults to `mono` (configurable via the `--stereo` flag) and preserves your output device's sample rate (configurable via the `--sample-rate` flag). Only the default output device is currently supported.

My original (and so far only) use case is streaming audio to a parent process which communicates with a realtime ASR service, so AudioTee makes some design decisions you might not agree with. Open an issue or a PR and we can talk about them. I'm also no Swift developer, so contributions improving codebase idioms and general hygiene are welcome. I have internal variations (and, frankly, improvements) of AudioTee which allow recording mic input as well as system audio, and I'm open to making that part of the main API.

## Why?

Recording system audio is harder than it should be on macOS, and folks often wrestle with outdated advice and poorly documented APIs. It's a boring problem which stands in the way of lots of fun applications. There's more code here than you need to solve this problem yourself: the main classes of interest are probably [`Core/AudioTapManager`](https://github.com/makeusabrew/audiotee/blob/main/Sources/Core/AudioTapManager.swift) and [`Core/AudioRecorder`](https://github.com/makeusabrew/audiotee/blob/main/Sources/Core/AudioRecorder.swift). Everything's wired together in [`CLI/AudioTee`](https://github.com/makeusabrew/audiotee/blob/main/Sources/CLI/AudioTee.swift). The rest is just CLI configuration support, output formatting logic, and some utility functions you could probably live without.

## Requirements

- macOS 14.2 or later
- Swift 5.9 or later (no need for XCode)
- System audio recording permissions (see below)

## Quick start

The following will start capturing audio output from all running programs and write binary chunks of raw PCM audio data to your terminal:

```bash
git clone git@github.com:makeusabrew/audiotee.git
cd audiotee
swift run
```

More usefully, you can redirect `stdout` to a file:

```bash
swift run audiotee --sample-rate 16000 > output.pcm
```

Which you can play back using something like `ffplay`:

```bash
ffplay -f s16le -ar 16000 output.pcm
```

## Build

```bash
# omit '-c release' to get a debug build
swift build -c release
```

## Usage

### Basic usage

Replace the path below with `.build/<arch>/<target>/audiotee`, e.g. `build/arm64-apple-macosx/release/audiotee` for a release build on Apple Silicon.

```bash
# Write raw PCM audio to stdout (logs go to stderr)
./audiotee

# Redirect audio to a file
./audiotee > output.pcm

# Pipe to another program
./audiotee | your_audio_processing_tool

# Redirect logs as well
./audiotee > captured_audio.pcm 2> audiotee.log
```

### Audio conversion

Note that performing _any_ sample rate conversion will also convert the output bit depth to
16-bit - assuming an original depth of 32-bit this results in a loss of dynamic range in exchange for a 50% reduction in output size. For ASR services, 16-bit is sufficient, but it's a non-obvious behaviour worth being aware of.

```bash
# No sample rate preserves your device's default (probably 44.1 or 48kHz with 32-bit float bit depth)
./audiotee

# Any sample rate (even one matching your device default) converts to 16-bit signed integers (half the bandwidth)
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

## Output

AudioTee writes raw PCM audio data directly to `stdout` in chunks. All logging, metadata, and status information is written to `stderr`.

### Audio format

- **Format**: Raw PCM audio data
- **Channels**: 1 in Mono mode (default), 2 in stereo mode
- **Sample rate**: Matches your output device's sample rate by default (configurable)
- **Bit depth**: 32-bit float by default, or 16-bit when sample rate conversion is performed
- **Endianness**: Little-endian
- **Chunk duration**: 200ms by default (configurable)

### Logs and monitoring

All program logs are written to `stderr` and can be captured separately:

```bash
# Capture audio and logs separately
./audiotee > audio.pcm 2> audiotee.log

# View logs in real-time while capturing audio
./audiotee > audio.pcm 2>&1 | grep "AudioTee"
```

## Command Line options

- `--include-processes`: Process IDs to tap (space-separated, empty = all processes)
- `--exclude-processes`: Process IDs to exclude (space-separated, empty = none)
- `--mute`: Mute processes being tapped
- `--stereo`: Record in stereo
- `--sample-rate`: Target sample rate (8000, 16000, 22050, 24000, 32000, 44100, 48000)
- `--chunk-duration`: Audio chunk duration in seconds [default: 0.2, max: 5.0]

## Permissions

There is no provision in the code to pre-emptively check for the required `NSAudioCaptureUsageDescription` permission, so you'll be prompted the first time AudioTee tries to record anything. Note that some terminal emulators like iTerm don't always prompt for these permissions (though the macOS builtin terminal definitely does), so you might need to grant them ahead of time if audiotee runs but never records anything.

If you want to check and/or request permissions ahead of time, check out [AudioCap's fantastic TCC probing approach](https://github.com/insidegui/AudioCap/blob/main/AudioCap/ProcessTap/AudioRecordingPermission.swift). 

## Built with AudioTee

<a href="https://talat.app"><img src="https://talat.app/favicon.svg" alt="talat" width="28" height="28" /></a>&ensp;**[talat](https://talat.app)** — private, local-only meeting transcription for macOS. Captures system audio via AudioTee and runs real-time speech recognition, speaker diarization, and searchable notes entirely on-device. [As featured in TechCrunch](https://techcrunch.com/2026/03/24/talats-ai-meeting-notes-stay-on-your-machine-not-in-the-cloud/).

## References / useful links

- [Apple Core Audio Taps Documentation](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [AudioCap Implementation](https://github.com/insidegui/AudioCap)
- [AudioTee.js](https://github.com/makeusabrew/audioteejs)

## License

### The MIT License

Copyright (C) 2025 Nick Payne.
