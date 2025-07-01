const { spawn } = require("child_process");
const { EventEmitter } = require("events");
const readline = require("readline");

/**
 * AudioTeeStream - Node.js wrapper for AudioTee system audio capture
 *
 * Events:
 * - 'metadata': Audio format information
 * - 'stream_start': Recording has started
 * - 'audio': Audio data chunk { timestamp, duration, peakAmplitude, audioData }
 * - 'stream_stop': Recording has stopped
 * - 'log': Log messages { level, message, context }
 * - 'error': Errors
 * - 'close': Process has closed
 */
class AudioTeeStream extends EventEmitter {
  constructor(options = {}) {
    super();

    // Binary path - use provided path or get from main module
    this.binaryPath =
      options.binaryPath ||
      (() => {
        try {
          return require("../index").getBinaryPath();
        } catch {
          throw new Error(
            "AudioTee binary path not available. Ensure package is properly installed."
          );
        }
      })();

    // AudioTee options
    this.format = options.format || "binary"; // 'json', 'binary', or 'auto'
    this.sampleRate = options.sampleRate;
    this.chunkDuration = options.chunkDuration || 0.2;
    this.includeProcesses = options.includeProcesses || [];
    this.excludeProcesses = options.excludeProcesses || [];
    this.mute = options.mute || false;

    // Internal state
    this.process = null;
    this.metadata = null;
    this.isStarted = false;

    // Binary format state
    this.pendingAudioMeta = null;
    this.expectedBytes = 0;
    this.binaryBuffer = Buffer.alloc(0);
  }

  /**
   * Start audio capture
   * @returns {AudioTeeStream} this instance for chaining
   */
  start() {
    if (this.isStarted) {
      throw new Error("AudioTeeStream is already started");
    }

    const args = this.buildArguments();

    try {
      this.process = spawn(this.binaryPath, args, {
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (error) {
      this.emit(
        "error",
        new Error(`Failed to start AudioTee: ${error.message}`)
      );
      return this;
    }

    this.isStarted = true;
    this.setupProtocolHandling();
    this.setupProcessHandlers();

    return this;
  }

  /**
   * Stop audio capture
   */
  stop() {
    if (this.process && !this.process.killed) {
      this.process.kill("SIGTERM");
    }
  }

  /**
   * Check if the stream is currently active
   * @returns {boolean}
   */
  isActive() {
    return this.isStarted && this.process && !this.process.killed;
  }

  /**
   * Get current audio metadata (available after 'metadata' event)
   * @returns {Object|null}
   */
  getMetadata() {
    return this.metadata;
  }

  // Private methods

  buildArguments() {
    const args = [`--format=${this.format}`];

    if (this.sampleRate) {
      args.push(`--sample-rate=${this.sampleRate}`);
    }

    if (this.chunkDuration !== 0.2) {
      args.push(`--chunk-duration=${this.chunkDuration}`);
    }

    if (this.includeProcesses.length) {
      args.push(`--include-processes=${this.includeProcesses.join(" ")}`);
    }

    if (this.excludeProcesses.length) {
      args.push(`--exclude-processes=${this.excludeProcesses.join(" ")}`);
    }

    if (this.mute) {
      args.push("--mute");
    }

    return args;
  }

  setupProtocolHandling() {
    if (this.format === "binary") {
      this.setupBinaryProtocol();
    } else {
      this.setupJSONProtocol();
    }
  }

  setupJSONProtocol() {
    const rl = readline.createInterface({
      input: this.process.stdout,
      crlfDelay: Infinity,
    });

    rl.on("line", (line) => this.handleJSONLine(line));
  }

  setupBinaryProtocol() {
    // For binary format, we need to handle both JSON lines and raw binary data
    let lineBuffer = "";
    let inJsonMode = true;

    this.process.stdout.on("data", (chunk) => {
      if (inJsonMode) {
        // Look for complete JSON lines
        lineBuffer += chunk.toString();

        let newlineIndex;
        while ((newlineIndex = lineBuffer.indexOf("\n")) !== -1) {
          const line = lineBuffer.slice(0, newlineIndex);
          lineBuffer = lineBuffer.slice(newlineIndex + 1);

          try {
            const message = JSON.parse(line);
            if (message.message_type === "audio" && this.format === "binary") {
              // Prepare for binary data
              this.expectedBytes = message.data.audio_length;
              this.pendingAudioMeta = {
                timestamp: new Date(message.data.timestamp),
                duration: message.data.duration,
                peakAmplitude: message.data.peak_amplitude,
              };
              inJsonMode = false;
            } else {
              this.handleJSONMessage(message);
            }
          } catch (error) {
            this.emit(
              "error",
              new Error(`Failed to parse JSON: ${error.message}`)
            );
          }
        }
      } else {
        // We're expecting binary audio data
        this.binaryBuffer = Buffer.concat([this.binaryBuffer, chunk]);

        if (this.binaryBuffer.length >= this.expectedBytes) {
          // Extract the audio data
          const audioData = this.binaryBuffer.slice(0, this.expectedBytes);
          this.binaryBuffer = this.binaryBuffer.slice(this.expectedBytes);

          // Emit the audio event
          this.emit("audio", {
            ...this.pendingAudioMeta,
            audioData,
          });

          // Reset state
          this.expectedBytes = 0;
          this.pendingAudioMeta = null;
          inJsonMode = true;

          // Process any remaining data as JSON
          if (this.binaryBuffer.length > 0) {
            lineBuffer += this.binaryBuffer.toString();
            this.binaryBuffer = Buffer.alloc(0);
          }
        }
      }
    });
  }

  handleJSONLine(line) {
    try {
      const message = JSON.parse(line);
      this.handleJSONMessage(message);
    } catch (error) {
      this.emit("error", new Error(`Failed to parse JSON: ${error.message}`));
    }
  }

  handleJSONMessage(message) {
    switch (message.message_type) {
      case "metadata":
        this.metadata = message.data;
        this.emit("metadata", this.metadata);
        break;

      case "stream_start":
        this.emit("stream_start");
        break;

      case "audio":
        if (this.format === "json") {
          // JSON format - audio data is base64 encoded
          const audioBuffer = Buffer.from(message.data.audio_data, "base64");
          this.emit("audio", {
            timestamp: new Date(message.data.timestamp),
            duration: message.data.duration,
            peakAmplitude: message.data.peak_amplitude,
            audioData: audioBuffer,
          });
        }
        // Binary format audio is handled in setupBinaryProtocol
        break;

      case "stream_stop":
        this.emit("stream_stop");
        break;

      case "info":
      case "error":
      case "debug":
        this.emit("log", {
          level: message.message_type,
          message: message.data?.message || "Unknown log message",
          context: message.data?.context,
        });
        break;

      default:
        this.emit("log", {
          level: "debug",
          message: `Unknown message type: ${message.message_type}`,
          context: { raw_message: message },
        });
    }
  }

  setupProcessHandlers() {
    this.process.stderr.on("data", (data) => {
      // AudioTee should not write to stderr in normal operation
      this.emit("log", {
        level: "error",
        message: "AudioTee stderr output",
        context: { output: data.toString().trim() },
      });
    });

    this.process.on("close", (code, signal) => {
      this.isStarted = false;
      this.emit("close", { code, signal });
    });

    this.process.on("error", (error) => {
      this.isStarted = false;
      this.emit("error", new Error(`AudioTee process error: ${error.message}`));
    });
  }
}

module.exports = AudioTeeStream;
