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
  /// Pre-allocated buffer for linearizing chunks that straddle the ring
  /// buffer boundary. Avoids a heap allocation on the wrap-around path.
  private let linearizationBuffer: UnsafeMutableRawPointer
  private var writeIndex: Int = 0
  private var readIndex: Int = 0
  private var availableBytes: Int = 0
  private let maxBufferSize: Int

  public let bytesPerChunk: Int

  public init(format: AudioStreamBasicDescription, chunkDuration: Double = 0.2) {
    // Pre-calculate chunk parameters
    let bytesPerFrame = Int(format.mBytesPerFrame)
    let samplesPerChunk = Int(format.mSampleRate * chunkDuration)
    self.bytesPerChunk = samplesPerChunk * bytesPerFrame

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

    self.linearizationBuffer = UnsafeMutableRawPointer.allocate(
      byteCount: bytesPerChunk,
      alignment: MemoryLayout<UInt8>.alignment
    )
  }

  deinit {
    buffer.deallocate()
    linearizationBuffer.deallocate()
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

  /// Calls `handler` once for each complete chunk available in the buffer.
  /// The pointer passed to the handler is valid only for the duration of
  /// that call. In the common (contiguous) case this points directly into
  /// the ring buffer — zero copies. In the wrap-around case the chunk is
  /// linearized into a pre-allocated scratch buffer — one memcpy, zero
  /// heap allocations.
  public func processChunks(_ handler: (UnsafeRawPointer, Int) -> Void) {
    while availableBytes >= bytesPerChunk {
      if readIndex + bytesPerChunk <= maxBufferSize {
        // Contiguous: point directly into the ring buffer
        handler(buffer.advanced(by: readIndex), bytesPerChunk)
        readIndex = (readIndex + bytesPerChunk) % maxBufferSize
      } else {
        // Wrap-around: linearize into the pre-allocated scratch buffer
        let firstChunkSize = maxBufferSize - readIndex
        let secondChunkSize = bytesPerChunk - firstChunkSize

        linearizationBuffer.copyMemory(
          from: buffer.advanced(by: readIndex), byteCount: firstChunkSize)
        linearizationBuffer.advanced(by: firstChunkSize).copyMemory(
          from: buffer, byteCount: secondChunkSize)

        handler(linearizationBuffer, bytesPerChunk)
        readIndex = secondChunkSize
      }

      availableBytes -= bytesPerChunk
    }
  }
}
