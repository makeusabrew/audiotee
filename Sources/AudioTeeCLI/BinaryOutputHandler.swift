import AudioTeeCore
import Foundation

/// CLI-specific output handler that writes raw PCM audio to stdout
/// and lifecycle messages to stderr via the logger.
class BinaryAudioOutputHandler: AudioOutputHandler {
  private let fd = STDOUT_FILENO

  func handleAudioData(_ pointer: UnsafeRawPointer, count: Int) {
    var written = 0
    while written < count {
      let result = write(fd, pointer.advanced(by: written), count - written)
      if result >= 0 {
        written += result
      } else if errno == EINTR {
        continue
      } else {
        break  // EPIPE, EIO, etc — consumer gone or real error
      }
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
