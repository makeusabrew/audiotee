#!/usr/bin/env node

/**
 * Basic AudioTee.js Usage Examples
 *
 * This file demonstrates common patterns for using AudioTee.js
 * Run with: node examples/basic-usage.js
 */

const { AudioTeeStream } = require("../index");
const fs = require("fs");

// Example 1: Basic audio capture with console output
function basicCapture() {
  console.log("=== Example 1: Basic Audio Capture ===\n");

  const stream = new AudioTeeStream({
    format: "binary",
    sampleRate: 16000, // Good for speech recognition
    chunkDuration: 0.2,
  });

  let packetCount = 0;
  let totalBytes = 0;

  stream.on("metadata", (metadata) => {
    console.log("🎵 Audio metadata:");
    console.log(`   Sample rate: ${metadata.sample_rate} Hz`);
    console.log(`   Encoding: ${metadata.encoding}`);
    console.log("");
  });

  stream.on("audio", (packet) => {
    packetCount++;
    totalBytes += packet.audioData.length;

    // Show real-time stats
    process.stdout.write(
      `\r📊 Packets: ${packetCount}, Bytes: ${totalBytes}, Peak: ${packet.peakAmplitude.toFixed(
        3
      )}`
    );
  });

  stream.on("error", (error) => {
    console.error("\n❌ Error:", error.message);
    process.exit(1);
  });

  // Auto-stop after 5 seconds for demo
  setTimeout(() => {
    console.log("\n\n✅ Stopping capture...");
    stream.stop();
  }, 5000);

  console.log("🚀 Starting capture (will run for 5 seconds)...");
  stream.start();
}

// Example 2: Save audio to file
function saveToFile() {
  console.log("\n=== Example 2: Save Audio to File ===\n");

  const stream = new AudioTeeStream({
    format: "binary",
    sampleRate: 44100, // CD quality
    chunkDuration: 0.1,
  });

  const outputFile = "recording.raw";
  const writeStream = fs.createWriteStream(outputFile);

  stream.on("metadata", (metadata) => {
    console.log(`💾 Saving ${metadata.encoding} audio to ${outputFile}`);
    console.log(
      `   Format: ${metadata.sample_rate}Hz, ${metadata.bits_per_channel}-bit`
    );
  });

  stream.on("audio", (packet) => {
    // Write raw audio data to file
    writeStream.write(packet.audioData);
  });

  stream.on("stream_stop", () => {
    writeStream.end();
    console.log(`\n✅ Saved audio to ${outputFile}`);

    // Show file size
    const stats = fs.statSync(outputFile);
    console.log(`📈 File size: ${(stats.size / 1024).toFixed(1)} KB`);
  });

  // Stop after 3 seconds
  setTimeout(() => {
    stream.stop();
  }, 3000);

  console.log("🎵 Recording for 3 seconds...");
  stream.start();
}

// Example 3: Monitor audio levels (VU meter style)
function audioLevelMonitor() {
  console.log("\n=== Example 3: Audio Level Monitor ===\n");

  const stream = new AudioTeeStream({
    format: "json", // JSON format for this example
    chunkDuration: 0.05, // Fast updates for smooth level display
  });

  function drawLevelMeter(level) {
    const maxBars = 20;
    const bars = Math.floor(level * maxBars);
    const meter = "█".repeat(bars) + "░".repeat(maxBars - bars);
    const percentage = (level * 100).toFixed(1);

    process.stdout.write(`\r🔊 ${meter} ${percentage}%`);
  }

  stream.on("audio", (packet) => {
    drawLevelMeter(packet.peakAmplitude);
  });

  // Run for 10 seconds
  setTimeout(() => {
    console.log("\n\n✅ Level monitoring complete");
    stream.stop();
  }, 10000);

  console.log("🎚️  Audio level monitor (10 seconds):");
  console.log("   Play some music to see the levels!\n");
  stream.start();
}

// Example 4: Process-specific capture
function captureSpecificProcess() {
  console.log("\n=== Example 4: Process-Specific Capture ===\n");

  // This would capture only from a specific application
  // You'd need to find the PID first: `pgrep "Music"` or Activity Monitor

  const stream = new AudioTeeStream({
    // includeProcesses: [1234], // Uncomment and set real PID
    mute: true, // Don't play through speakers
    format: "binary",
  });

  stream.on("metadata", () => {
    console.log(
      "🎯 Capturing from specific process (demo mode - all processes)"
    );
    console.log("   To capture from specific app:");
    console.log('   1. Find PID: pgrep "App Name"');
    console.log("   2. Uncomment includeProcesses line above");
  });

  stream.on("audio", (packet) => {
    console.log(
      `📦 Got ${packet.audioData.length} bytes from targeted process`
    );
  });

  // Stop after 3 seconds
  setTimeout(() => {
    stream.stop();
  }, 3000);

  stream.start();
}

// Run examples based on command line argument
const example = process.argv[2] || "1";

switch (example) {
  case "1":
    basicCapture();
    break;
  case "2":
    saveToFile();
    break;
  case "3":
    audioLevelMonitor();
    break;
  case "4":
    captureSpecificProcess();
    break;
  default:
    console.log("Usage: node basic-usage.js [1|2|3|4]");
    console.log("");
    console.log("Examples:");
    console.log("  1 - Basic audio capture");
    console.log("  2 - Save audio to file");
    console.log("  3 - Audio level monitor");
    console.log("  4 - Process-specific capture");
}
