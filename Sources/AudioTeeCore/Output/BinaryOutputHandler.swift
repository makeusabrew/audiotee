import Foundation

public class BinaryAudioOutputHandler: AudioOutputHandler {
  private let flushAfterWrite: Bool

  public init(flushAfterWrite: Bool = false) {
    self.flushAfterWrite = flushAfterWrite
  }
  public func handleAudioPacket(_ packet: AudioPacket) {
    // Write raw binary audio data directly to stdout
    FileHandle.standardOutput.write(packet.data)
    if flushAfterWrite {
      fflush(stdout)
    }
  }

  public func handleMetadata(_ metadata: AudioStreamMetadata) {
    Logger.writeMessage(.metadata, data: metadata)
  }

  public func handleStreamStart() {
    Logger.writeMessage(.streamStart, data: Optional<String>.none)
  }

  public func handleStreamStop() {
    Logger.writeMessage(.streamStop, data: Optional<String>.none)
  }
}
