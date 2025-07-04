import CoreAudio
import Foundation

public class AudioBuffer {
  private var buffer = Data()
  private let targetChunkDuration: Double
  private let streamFormat: AudioStreamBasicDescription

  public init(format: AudioStreamBasicDescription, chunkDuration: Double = 0.2) {
    self.streamFormat = format
    self.targetChunkDuration = chunkDuration
  }

  public func append(_ data: Data) {
    buffer.append(data)
  }

  public func processChunks() -> [AudioPacket] {
    var packets: [AudioPacket] = []

    while let packet = nextChunk() {
      packets.append(packet)
    }

    return packets
  }

  public func flushRemaining() -> AudioPacket? {
    guard !buffer.isEmpty else { return nil }

    let packet = AudioPacket(
      timestamp: Date(),
      duration: 0.0,  // Unknown duration for final chunk
      peakAmplitude: 0.0,
      rawAudioData: buffer
    )

    buffer.removeAll()
    return packet
  }

  private func nextChunk() -> AudioPacket? {
    let bytesPerFrame = Int(streamFormat.mBytesPerFrame)
    let samplesPerChunk = Int(streamFormat.mSampleRate * targetChunkDuration)
    let bytesPerChunk = samplesPerChunk * bytesPerFrame

    guard buffer.count >= bytesPerChunk else { return nil }

    let chunkData = buffer.prefix(bytesPerChunk)

    let packet = AudioPacket(
      timestamp: Date(),
      duration: Double(samplesPerChunk) / streamFormat.mSampleRate,
      peakAmplitude: 0.0,  // No analysis in raw mode
      rawAudioData: Data(chunkData)
    )

    buffer.removeFirst(bytesPerChunk)
    return packet
  }
}
