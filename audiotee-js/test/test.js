#!/usr/bin/env node
const { AudioTeeStream } = require("../index");

function runBasicTest() {
  console.log("=== AudioTee.js Basic Test ===\n");

  const stream = new AudioTeeStream({
    format: "binary",
    sampleRate: 16000,
    chunkDuration: 0.1,
  });

  let audioPacketCount = 0;
  let totalAudioBytes = 0;

  stream.on("metadata", (metadata) => {
    console.log("📊 Audio Metadata:");
    console.log(`   Sample Rate: ${metadata.sample_rate} Hz`);
    console.log(`   Channels: ${metadata.channels_per_frame}`);
    console.log(`   Bits per Channel: ${metadata.bits_per_channel}`);
    console.log(`   Encoding: ${metadata.encoding}`);
    console.log(`   Float: ${metadata.is_float}\n`);
  });

  stream.on("stream_start", () => {
    console.log("🎵 Audio stream started\n");
  });

  stream.on("audio", (packet) => {
    audioPacketCount++;
    totalAudioBytes += packet.audioData.length;

    process.stdout.write(
      `\r📦 Packets: ${audioPacketCount} | Audio bytes: ${totalAudioBytes} | Peak: ${packet.peakAmplitude.toFixed(
        3
      )} | Duration: ${packet.duration.toFixed(3)}s`
    );
  });

  stream.on("stream_stop", () => {
    console.log("\n\n🛑 Audio stream stopped");
    console.log(
      `📈 Final stats: ${audioPacketCount} packets, ${totalAudioBytes} bytes total\n`
    );
  });

  stream.on("log", (log) => {
    if (log.level === "error") {
      console.error(`\n❌ ${log.level.toUpperCase()}: ${log.message}`);
      if (log.context) {
        console.error(`   Context:`, log.context);
      }
    }
  });

  stream.on("error", (error) => {
    console.error(`\n💥 Error: ${error.message}`);
    process.exit(1);
  });

  stream.on("close", ({ code, signal }) => {
    console.log(
      `👋 AudioTee process closed (code: ${code}, signal: ${signal})`
    );
    process.exit(code || 0);
  });

  // Handle Ctrl+C gracefully
  process.on("SIGINT", () => {
    console.log("\n\n🛑 Received SIGINT, stopping AudioTee...");
    stream.stop();
  });

  console.log("🚀 Starting AudioTee stream...");
  console.log("💡 Play some audio and watch the packets stream in!");
  console.log("⏹️  Press Ctrl+C to stop\n");

  try {
    stream.start();
  } catch (error) {
    console.error(`Failed to start: ${error.message}`);
    process.exit(1);
  }
}

function runQuickTest() {
  console.log("=== AudioTee.js Quick Test ===\n");

  const stream = new AudioTeeStream({
    format: "json",
    chunkDuration: 0.2,
  });

  let packetCount = 0;
  const maxPackets = 5;

  stream.on("metadata", (metadata) => {
    console.log("✅ Received metadata:", metadata);
  });

  stream.on("audio", () => {
    packetCount++;
    console.log(`✅ Received audio packet ${packetCount}/${maxPackets}`);

    if (packetCount >= maxPackets) {
      console.log("✅ Quick test complete!");
      stream.stop();
    }
  });

  stream.on("error", (error) => {
    console.error("❌ Test failed:", error.message);
    process.exit(1);
  });

  stream.on("close", () => {
    console.log("👋 Test finished");
    process.exit(0);
  });

  setTimeout(() => {
    console.log("⏰ Test timeout - AudioTee might not be working");
    stream.stop();
    process.exit(1);
  }, 10000);

  console.log("🚀 Running quick test (capturing 5 audio packets)...");
  stream.start();
}

// Run the appropriate test based on command line args
const testType = process.argv[2] || "basic";

switch (testType) {
  case "quick":
    runQuickTest();
    break;
  case "basic":
  default:
    runBasicTest();
    break;
}
