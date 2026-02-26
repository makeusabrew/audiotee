import Foundation

/// Protocol for handling audio output in different formats
public protocol AudioOutputHandler {
  func handleAudioPacket(_ packet: AudioPacket)
  func handleMetadata(_ metadata: AudioStreamMetadata)
  func handleStreamStart()
  func handleStreamStop()
}
