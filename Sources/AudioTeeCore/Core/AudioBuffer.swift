import CoreAudio
import Foundation

/// Ring buffer for accumulating raw audio data and extracting fixed-size chunks.
///
/// Uses a raw heap-allocated pointer rather than Swift Array to avoid
/// copy-on-write reference-count checks on every mutation. This buffer
/// lives on the real-time audio IO thread and is never shared, so COW
/// semantics are pure overhead.
public class AudioBuffer {
  /// Raw heap-allocated ring buffer backing store.
  private let buffer: UnsafeMutableRawPointer
  private var writeIndex: Int = 0
  private var readIndex: Int = 0
  private var availableBytes: Int = 0
  private let maxBufferSize: Int

  private let bytesPerChunk: Int
  private let chunkDuration: Double

  public init(format: AudioStreamBasicDescription, chunkDuration: Double = 0.2) {
    // Pre-calculate chunk parameters
    let bytesPerFrame = Int(format.mBytesPerFrame)
    let samplesPerChunk = Int(format.mSampleRate * chunkDuration)
    self.bytesPerChunk = samplesPerChunk * bytesPerFrame
    self.chunkDuration = Double(samplesPerChunk) / format.mSampleRate

    // Calculate max buffer size to hold ~10 seconds of audio (safety limit)
    let bytesPerSecond = Int(format.mSampleRate) * bytesPerFrame
    self.maxBufferSize = bytesPerSecond * 10

    // Allocate raw memory. We use UnsafeMutableRawPointer instead of [UInt8]
    // to eliminate Swift Array's COW ref-count check on every write/read.
    self.buffer = UnsafeMutableRawPointer.allocate(
      byteCount: maxBufferSize,
      alignment: MemoryLayout<UInt8>.alignment
    )
    buffer.initializeMemory(as: UInt8.self, repeating: 0, count: maxBufferSize)
  }

  deinit {
    buffer.deallocate()
  }

  /// Appends audio data directly from a raw pointer into the ring buffer.
  /// This is the fast path used by the IO proc callback: one memcpy from
  /// the Core Audio buffer into our ring buffer, with no intermediate
  /// Data allocation.
  public func append(from source: UnsafeRawPointer, count: Int) {
    guard count >= 0 else {
      AudioTeeLogging.logger.error(
        "Audio buffer append called with negative count",
        context: ["count": String(count)])
      return
    }

    guard availableBytes + count <= maxBufferSize else {
      AudioTeeLogging.logger.error(
        "Audio buffer overflow",
        context: [
          "requested": String(count),
          "available": String(maxBufferSize - availableBytes),
        ])
      return
    }

    if writeIndex + count <= maxBufferSize {
      // Single contiguous write — no wrap-around needed
      buffer.advanced(by: writeIndex).copyMemory(from: source, byteCount: count)
      writeIndex = (writeIndex + count) % maxBufferSize
    } else {
      // Two writes needed due to wrap-around at the end of the ring buffer
      let firstChunkSize = maxBufferSize - writeIndex
      let secondChunkSize = count - firstChunkSize

      buffer.advanced(by: writeIndex).copyMemory(from: source, byteCount: firstChunkSize)
      buffer.copyMemory(from: source.advanced(by: firstChunkSize), byteCount: secondChunkSize)

      writeIndex = secondChunkSize
    }

    availableBytes += count
  }

  /// Extracts all complete chunks currently available in the buffer.
  public func processChunks() -> [AudioPacket] {
    var packets: [AudioPacket] = []

    while let packet = nextChunk() {
      packets.append(packet)
    }

    return packets
  }

  private func nextChunk() -> AudioPacket? {
    // Check if we have enough data for a complete chunk
    guard availableBytes >= bytesPerChunk else { return nil }

    let chunkData: Data

    // Check if we can copy in one block (no wrap-around)
    if readIndex + bytesPerChunk <= maxBufferSize {
      // one copy needed
      chunkData = Data(bytes: buffer.advanced(by: readIndex), count: bytesPerChunk)
      readIndex = (readIndex + bytesPerChunk) % maxBufferSize
    } else {
      // two copies needed due to wrap-around
      let firstChunkSize = maxBufferSize - readIndex
      let secondChunkSize = bytesPerChunk - firstChunkSize

      var assembled = Data(capacity: bytesPerChunk)
      assembled.append(
        buffer.advanced(by: readIndex).assumingMemoryBound(to: UInt8.self),
        count: firstChunkSize)
      assembled.append(
        buffer.assumingMemoryBound(to: UInt8.self),
        count: secondChunkSize)
      chunkData = assembled

      readIndex = secondChunkSize
    }

    availableBytes -= bytesPerChunk

    return AudioPacket(
      timestamp: Date(),
      duration: chunkDuration,
      data: chunkData
    )
  }
}
