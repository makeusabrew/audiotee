import AudioTeeCore
import Foundation

/// CLI-specific output handler that writes raw PCM audio to stdout
/// and lifecycle messages to stderr via the logger.
class BinaryAudioOutputHandler: AudioOutputHandler {
  private let flushAfterWrite: Bool

  init(flushAfterWrite: Bool = false) {
    self.flushAfterWrite = flushAfterWrite
  }

  func handleAudioPacket(_ packet: AudioPacket) {
    // Write raw binary audio data directly to stdout
    FileHandle.standardOutput.write(packet.data)
    if flushAfterWrite {
      fflush(stdout)
    }
  }

  func handleMetadata(_ metadata: AudioStreamMetadata) {
    AudioTeeLogging.logger.writeMessage(.metadata, data: metadata)
  }

  func handleStreamStart() {
    AudioTeeLogging.logger.writeMessage(.streamStart, data: Optional<String>.none)
  }

  func handleStreamStop() {
    AudioTeeLogging.logger.writeMessage(.streamStop, data: Optional<String>.none)
  }
}
