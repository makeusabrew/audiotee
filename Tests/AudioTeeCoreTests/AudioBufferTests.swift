import CoreAudio
import XCTest

@testable import AudioTeeCore

// CoreAudio defines its own AudioBuffer struct, which collides with ours.
// Explicit module qualification avoids ambiguity in tests that import both.
private typealias AudioBuffer = AudioTeeCore.AudioBuffer

final class AudioBufferTests: XCTestCase {

  // MARK: - Helpers

  /// Creates a minimal AudioStreamBasicDescription for testing.
  /// 16kHz, 16-bit, mono = 2 bytes per frame, 32000 bytes/sec.
  private func makeFormat(
    sampleRate: Double = 16000,
    bytesPerFrame: UInt32 = 2,
    bitsPerChannel: UInt32 = 16
  ) -> AudioStreamBasicDescription {
    return AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger,
      mBytesPerPacket: bytesPerFrame,
      mFramesPerPacket: 1,
      mBytesPerFrame: bytesPerFrame,
      mChannelsPerFrame: 1,
      mBitsPerChannel: bitsPerChannel,
      mReserved: 0
    )
  }

  /// Creates a repeating byte pattern of the given length.
  private func makeData(byte: UInt8, count: Int) -> Data {
    return Data(repeating: byte, count: count)
  }

  /// Appends Data to an AudioBuffer via the raw pointer path,
  /// matching how processAudio() calls append(from:count:).
  private func appendData(_ data: Data, to buffer: AudioBuffer) {
    data.withUnsafeBytes { bytes in
      buffer.append(from: bytes.baseAddress!, count: bytes.count)
    }
  }

  /// Collects chunks from the buffer as Data objects for test verification.
  private func collectChunks(from buffer: AudioBuffer) -> [Data] {
    var chunks: [Data] = []
    buffer.processChunks { pointer, count in
      chunks.append(Data(bytes: pointer, count: count))
    }
    return chunks
  }

  // MARK: - Basic append + processChunks

  func testSingleChunkExtraction() {
    // 16kHz, 2 bytes/frame, 0.1s chunk = 3200 bytes per chunk
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200  // 16000 * 0.1 * 2

    let data = makeData(byte: 0xAB, count: chunkSize)
    appendData(data, to: buffer)

    let chunks = collectChunks(from: buffer)
    XCTAssertEqual(chunks.count, 1)
    XCTAssertEqual(chunks[0].count, chunkSize)
    XCTAssertEqual(chunks[0], data)
  }

  func testMultipleChunksExtracted() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Append 2.5 chunks worth
    appendData(makeData(byte: 0x01, count: chunkSize * 2 + chunkSize / 2), to: buffer)

    let chunks = collectChunks(from: buffer)
    // Should get 2 complete chunks, remainder stays in buffer
    XCTAssertEqual(chunks.count, 2)
    XCTAssertEqual(chunks[0].count, chunkSize)
    XCTAssertEqual(chunks[1].count, chunkSize)
  }

  func testInsufficientDataReturnsNoChunks() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Append less than one chunk
    appendData(makeData(byte: 0xFF, count: chunkSize - 1), to: buffer)

    let chunks = collectChunks(from: buffer)
    XCTAssertEqual(chunks.count, 0)
  }

  // MARK: - Wrap-around

  func testWrapAroundWrite() {
    // 8kHz, 2 bytes/frame, 0.3s chunks → chunkSize = 4800, maxBuffer = 160000.
    // 160000 / 4800 = 33.33 — chunks do NOT divide evenly into the buffer,
    // so after enough writes the writeIndex will straddle the boundary.
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.3)
    let chunkSize = 4800  // 8000 * 0.3 * 2

    // Write 33 chunks (158400 bytes), drain them all.
    // writeIndex = 158400, readIndex = 158400. 1600 bytes remain before boundary.
    for _ in 0..<33 {
      appendData(makeData(byte: 0x00, count: chunkSize), to: buffer)
    }
    let drained = collectChunks(from: buffer)
    XCTAssertEqual(drained.count, 33)

    // Next write of 4800 bytes starts at 158400. 158400 + 4800 = 163200 > 160000.
    // This MUST take the wrap-around else branch in append():
    //   firstChunkSize = 160000 - 158400 = 1600
    //   secondChunkSize = 4800 - 1600 = 3200
    // Verify by using distinct byte patterns for the portion before and after the boundary.
    var wrappingData = Data()
    wrappingData.append(makeData(byte: 0xAA, count: 1600))  // fills to boundary
    wrappingData.append(makeData(byte: 0xBB, count: 3200))  // wraps to start
    XCTAssertEqual(wrappingData.count, chunkSize)
    appendData(wrappingData, to: buffer)

    let chunks = collectChunks(from: buffer)
    XCTAssertEqual(chunks.count, 1)
    XCTAssertEqual(chunks[0], wrappingData)
  }

  func testWrapAroundRead() {
    // Same setup as above: position readIndex so that a chunk extraction
    // straddles the ring buffer boundary, exercising the else branch in nextChunk().
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.3)
    let chunkSize = 4800

    // Write and drain 33 chunks. Both indices land at 158400.
    for _ in 0..<33 {
      appendData(makeData(byte: 0x00, count: chunkSize), to: buffer)
    }
    _ = collectChunks(from: buffer)

    // Write one chunk starting at 158400. The write itself wraps (tested above),
    // but crucially the READ will also wrap: readIndex = 158400,
    // 158400 + 4800 = 163200 > 160000 → else branch in nextChunk():
    //   firstChunkSize = 160000 - 158400 = 1600 (read from end of buffer)
    //   secondChunkSize = 4800 - 1600 = 3200 (read from start of buffer)
    var crossBoundaryData = Data()
    crossBoundaryData.append(makeData(byte: 0xCC, count: 1600))
    crossBoundaryData.append(makeData(byte: 0xDD, count: 3200))
    appendData(crossBoundaryData, to: buffer)

    let chunks = collectChunks(from: buffer)
    XCTAssertEqual(chunks.count, 1)
    XCTAssertEqual(chunks[0], crossBoundaryData)
  }

  // MARK: - Overflow guard

  func testOverflowPreventsWrite() {
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let maxBuffer = 160000

    // Fill the buffer completely
    appendData(makeData(byte: 0x01, count: maxBuffer), to: buffer)

    // Try to append more — should be silently rejected (overflow guard)
    appendData(makeData(byte: 0x02, count: 100), to: buffer)

    // Drain and verify we only got the original data
    let chunks = collectChunks(from: buffer)
    let totalBytes = chunks.reduce(0) { $0 + $1.count }
    XCTAssertEqual(totalBytes, maxBuffer)

    // Every byte should be 0x01, not 0x02
    for chunk in chunks {
      XCTAssertTrue(chunk.allSatisfy { $0 == 0x01 })
    }
  }

  // MARK: - Incremental appends accumulate correctly

  func testIncrementalAppendsThenChunk() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Simulate many small IO callbacks building up to one chunk
    let callbackSize = 320  // 10 callbacks to fill one chunk
    for i in 0..<10 {
      appendData(makeData(byte: UInt8(i), count: callbackSize), to: buffer)
    }

    let chunks = collectChunks(from: buffer)
    XCTAssertEqual(chunks.count, 1)
    XCTAssertEqual(chunks[0].count, chunkSize)

    // Verify the data is in the correct order
    for i in 0..<10 {
      let slice = chunks[0].subdata(in: (i * callbackSize)..<((i + 1) * callbackSize))
      XCTAssertTrue(slice.allSatisfy { $0 == UInt8(i) })
    }
  }

  // MARK: - Chunk size

  func testBytesPerChunkIsCorrect() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)

    // 16kHz * 0.1s * 2 bytes/frame = 3200
    XCTAssertEqual(buffer.bytesPerChunk, 3200)
  }
}
