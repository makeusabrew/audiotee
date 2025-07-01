#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const os = require("os");

// Default to parent directory (when in same repo), allow override via env var
const DEFAULT_BINARY_PATH = path.join(
  __dirname,
  "..",
  "..",
  ".build",
  "release",
  "audiotee"
);
const AUDIOTEE_BINARY_PATH =
  process.env.AUDIOTEE_BINARY_PATH || DEFAULT_BINARY_PATH;

function build() {
  const arch = os.arch();
  const platform = os.platform();

  console.log(`Building for platform: ${platform}, architecture: ${arch}`);

  if (platform !== "darwin") {
    throw new Error("AudioTee only supports macOS");
  }

  // Create bin directory
  const binDir = path.join(__dirname, "..", "bin");
  if (!fs.existsSync(binDir)) {
    fs.mkdirSync(binDir, { recursive: true });
    console.log(`Created bin directory: ${binDir}`);
  }

  // Resolve the source binary path
  const sourcePath = path.resolve(AUDIOTEE_BINARY_PATH);
  const targetPath = path.join(binDir, "audiotee");

  console.log(`Looking for AudioTee binary at: ${sourcePath}`);

  if (!fs.existsSync(sourcePath)) {
    console.error(`AudioTee binary not found at: ${sourcePath}`);
    console.error("Please ensure AudioTee is built first:");
    console.error("  cd ../audiotee && swift build -c release");
    console.error("Or set AUDIOTEE_BINARY_PATH environment variable");
    throw new Error(`AudioTee binary not found at: ${sourcePath}`);
  }

  console.log(`Copying AudioTee binary from ${sourcePath} to ${targetPath}`);
  fs.copyFileSync(sourcePath, targetPath);

  // Make executable
  fs.chmodSync(targetPath, 0o755);

  // Verify the binary works
  console.log("Verifying binary...");
  const { execSync } = require("child_process");
  try {
    execSync(`"${targetPath}" --help`, { stdio: "pipe" });
    console.log("Binary verification successful");
  } catch (error) {
    console.warn("Binary verification failed, but continuing...");
  }

  console.log("Build completed successfully");
}

function clean() {
  const binDir = path.join(__dirname, "..", "bin");
  if (fs.existsSync(binDir)) {
    fs.rmSync(binDir, { recursive: true, force: true });
    console.log("Cleaned bin directory");
  }
}

if (require.main === module) {
  const command = process.argv[2];

  switch (command) {
    case "clean":
      clean();
      break;
    default:
      build();
  }
}

module.exports = { build, clean };
