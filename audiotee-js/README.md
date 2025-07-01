# AudioTee.js

Node.js wrapper for [AudioTee](https://github.com/your-org/audiotee) - capture macOS system audio using Core Audio taps.

AudioTee.js provides a streaming interface to capture system audio in real-time, perfect for building applications that need to process audio from any running application on macOS.

## Features

- 🎵 **Real-time system audio capture** using Core Audio taps
- 📦 **Streaming interface** with Node.js EventEmitter API
- ⚡ **High performance** binary protocol support
- 🎛️ **Flexible configuration** - sample rates, chunk sizes, process filtering
- 🔇 **Process-specific capture** - include/exclude specific applications
- 📊 **Audio metadata** - format information and level monitoring
- 🛡️ **Error handling** - graceful failure and process management

## Requirements

- **macOS 14.2+** (Sonoma or later)
- **Node.js 14+**
- **Audio recording permissions** (you'll be prompted on first use)

## Installation

```bash
npm install audiotee-js
```

The package will automatically download the appropriate AudioTee binary for your system during installation.

## Quick Start

```javascript
const { AudioTeeStream } = require('audiotee-js');

// Create a stream with 16kHz sample rate (great for ASR)
const stream = new AudioTeeStream({
  sampleRate: 16000,
  format: 'binary',
  chunkDuration: 0.2
});

// Listen for audio metadata
stream.on('metadata', (metadata) => {
  console.log('Audio format:', metadata);
});

// Process audio chunks
stream.on('audio', (packet) => {
  console.log(`Received ${packet.audioData.length} bytes of audio`);
  // packet.audioData is a Buffer containing raw PCM data
  // packet.timestamp, packet.duration, packet.peakAmplitude also available
});

// Handle errors
stream.on('error', (error) => {
  console.error('AudioTee error:', error);
});

// Start capturing
stream.start();

// Stop when done
// stream.stop();
```

## API Reference

### AudioTeeStream

The main class for capturing system audio.

#### Constructor

```javascript
new AudioTeeStream(options)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | `string` | `'binary'` | Output format: `'json'`, `'binary'`, or `'auto'` |
| `sampleRate` | `number` | `undefined` | Target sample rate (8000, 16000, 22050, 24000, 32000, 44100, 48000) |
| `chunkDuration` | `number` | `0.2` | Audio chunk duration in seconds (max 5.0) |
| `includeProcesses` | `number[]` | `[]` | Process IDs to capture (empty = all processes) |
| `excludeProcesses` | `number[]` | `[]` | Process IDs to exclude |
| `mute` | `boolean` | `false` | Mute processes being captured |
| `binaryPath` | `string` | `auto` | Custom path to AudioTee binary |

#### Methods

- **`start()`** - Start audio capture, returns `this` for chaining
- **`stop()`** - Stop audio capture 
- **`isActive()`** - Returns `true` if currently capturing
- **`getMetadata()`** - Returns audio metadata (available after `metadata` event)

#### Events

- **`metadata`** - Audio format information
- **`stream_start`** - Capture has started
- **`audio`** - Audio data packet
- **`stream_stop`** - Capture has stopped  
- **`log`** - Log messages from AudioTee
- **`error`** - Error occurred
- **`close`** - Process has closed

### Audio Packet Format

Audio events receive packets with this structure:

```javascript
{
  timestamp: Date,           // When this audio was captured
  duration: number,          // Duration in seconds  
  peakAmplitude: number,     // Peak amplitude (0.0 - 1.0)
  audioData: Buffer          // Raw PCM audio data
}
```

### Metadata Format

Metadata events provide audio format information:

```javascript
{
  sample_rate: number,       // e.g. 48000
  channels_per_frame: number,// Always 1 (mono)  
  bits_per_channel: number,  // e.g. 32
  is_float: boolean,         // true for float32, false for int16
  encoding: string,          // e.g. "pcm_f32le"
  capture_mode: string,      // "audio" 
  device_name: string|null,  // Audio device name
  device_uid: string|null    // Audio device UID
}
```

## Examples

### Basic Recording

```javascript
const { AudioTeeStream } = require('audiotee-js');

const stream = new AudioTeeStream();

stream.on('metadata', console.log);
stream.on('audio', (packet) => {
  console.log(`${packet.audioData.length} bytes, peak: ${packet.peakAmplitude}`);
});

stream.start();
```

### Save to WAV File

```javascript
const fs = require('fs');
const { AudioTeeStream } = require('audiotee-js');

const stream = new AudioTeeStream({
  sampleRate: 44100,
  format: 'binary'
});

const output = fs.createWriteStream('recording.raw');

stream.on('audio', (packet) => {
  output.write(packet.audioData);
});

stream.start();

// Stop after 10 seconds
setTimeout(() => {
  stream.stop();
  output.end();
}, 10000);
```

### Process-Specific Capture

```javascript
const { AudioTeeStream } = require('audiotee-js');

// Only capture audio from Spotify (you'd need to find Spotify's PID)
const spotifyPID = 1234; // Use Activity Monitor or `pgrep Spotify`

const stream = new AudioTeeStream({
  includeProcesses: [spotifyPID],
  mute: true // Don't play through speakers
});

stream.on('audio', (packet) => {
  // Only Spotify's audio will be captured
  console.log('Spotify audio:', packet.audioData.length, 'bytes');
});

stream.start();
```

### Real-time ASR Integration

```javascript
const { AudioTeeStream } = require('audiotee-js');

const stream = new AudioTeeStream({
  sampleRate: 16000, // Common ASR sample rate
  chunkDuration: 0.1, // Faster chunks for real-time
  format: 'binary'
});

stream.on('audio', async (packet) => {
  // Send to your ASR service
  const transcript = await sendToASR(packet.audioData);
  if (transcript) {
    console.log('Transcription:', transcript);
  }
});

stream.start();
```

## Testing

Run the included test to verify everything works:

```bash
# Basic interactive test
npm test

# Quick automated test  
npm test quick
```

The test will capture audio for a few seconds and display statistics.

## Troubleshooting

### Permission Denied

AudioTee requires microphone permissions. You'll see a system dialog on first use - make sure to allow access.

### Binary Not Found

If you see "AudioTee binary not found", try rebuilding:

```bash
npm run build
```

### No Audio Captured

- Check that audio is actually playing on your system
- Verify you have the latest macOS version (14.2+)
- Try running the Swift AudioTee directly to isolate the issue

## Development

### Building from Source

```bash
# Clone and build the parent AudioTee project first
git clone https://github.com/your-org/audiotee.git
cd audiotee
swift build -c release

# Then build the Node.js package
cd audiotee-js
npm install
npm run build
```

### Testing Changes

```bash
npm test          # Run basic test
npm run lint      # Check code style
npm run clean     # Clean build artifacts
```

## Performance Notes

- **Binary format** is more efficient than JSON for high-throughput applications
- **Lower chunk durations** increase CPU usage but reduce latency
- **Sample rate conversion** adds processing overhead - use native rates when possible
- The AudioTee binary uses real-time audio threads for minimal latency

## License

MIT License - see [LICENSE](LICENSE) file.

## Related Projects

- [AudioTee](https://github.com/your-org/audiotee) - The underlying Swift CLI tool
- [node-core-audio](https://github.com/ZECTBynmo/node-core-audio) - Alternative Node.js audio library
- [AudioCap](https://github.com/insidegui/AudioCap) - macOS audio capture inspiration 