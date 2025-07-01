const path = require("path");
const binary = require("node-pre-gyp");

// Get the path to the downloaded binary
const bindingPath = binary.find(
  path.resolve(path.join(__dirname, "package.json"))
);
const binaryPath = path.join(path.dirname(bindingPath), "audiotee");

const AudioTeeStream = require("./lib/AudioTeeStream");

module.exports = {
  AudioTeeStream,
  getBinaryPath: () => binaryPath,
};
