import CoreAudio
import XCTest

@testable import AudioTeeCore

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

  // MARK: - Basic append + processChunks

  func testSingleChunkExtraction() {
    // 16kHz, 2 bytes/frame, 0.1s chunk = 3200 bytes per chunk
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200  // 16000 * 0.1 * 2

    // Append exactly one chunk worth of data via Data path
    let data = makeData(byte: 0xAB, count: chunkSize)
    buffer.append(data)

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data.count, chunkSize)
    XCTAssertEqual(packets[0].data, data)
  }

  func testMultipleChunksExtracted() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Append 2.5 chunks worth
    buffer.append(makeData(byte: 0x01, count: chunkSize * 2 + chunkSize / 2))

    let packets = buffer.processChunks()
    // Should get 2 complete chunks, remainder stays in buffer
    XCTAssertEqual(packets.count, 2)
    XCTAssertEqual(packets[0].data.count, chunkSize)
    XCTAssertEqual(packets[1].data.count, chunkSize)
  }

  func testInsufficientDataReturnsNoChunks() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Append less than one chunk
    buffer.append(makeData(byte: 0xFF, count: chunkSize - 1))

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 0)
  }

  // MARK: - Zero-copy append(from:count:)

  func testZeroCopyAppend() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let chunkSize = 3200

    // Simulate what processAudio does: pass a raw pointer directly
    let source = makeData(byte: 0xCD, count: chunkSize)
    source.withUnsafeBytes { bytes in
      buffer.append(from: bytes.baseAddress!, count: bytes.count)
    }

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data, source)
  }

  // MARK: - Wrap-around

  func testWrapAroundWrite() {
    // 8kHz, 2 bytes/frame, 0.3s chunks → chunkSize = 4800, maxBuffer = 160000.
    // 160000 / 4800 = 33.33 — chunks do NOT divide evenly into the buffer,
    // so after enough writes the writeIndex will straddle the boundary.
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.3)
    let chunkSize = 4800  // 8000 * 0.3 * 2
    let maxBuffer = 160000  // 8000 * 2 * 10

    // Write 33 chunks (158400 bytes), drain them all.
    // writeIndex = 158400, readIndex = 158400. 1600 bytes remain before boundary.
    for _ in 0..<33 {
      buffer.append(makeData(byte: 0x00, count: chunkSize))
    }
    let drained = buffer.processChunks()
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
    buffer.append(wrappingData)

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data, wrappingData)
  }

  func testWrapAroundRead() {
    // Same setup as above: position readIndex so that a chunk extraction
    // straddles the ring buffer boundary, exercising the else branch in nextChunk().
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.3)
    let chunkSize = 4800

    // Write and drain 33 chunks. Both indices land at 158400.
    for _ in 0..<33 {
      buffer.append(makeData(byte: 0x00, count: chunkSize))
    }
    _ = buffer.processChunks()

    // Write one chunk starting at 158400. The write itself wraps (tested above),
    // but crucially the READ will also wrap: readIndex = 158400,
    // 158400 + 4800 = 163200 > 160000 → else branch in nextChunk():
    //   firstChunkSize = 160000 - 158400 = 1600 (read from end of buffer)
    //   secondChunkSize = 4800 - 1600 = 3200 (read from start of buffer)
    var crossBoundaryData = Data()
    crossBoundaryData.append(makeData(byte: 0xCC, count: 1600))
    crossBoundaryData.append(makeData(byte: 0xDD, count: 3200))
    buffer.append(crossBoundaryData)

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data, crossBoundaryData)
  }

  func testZeroCopyAppendWrapAround() {
    // Verify that the raw-pointer append path also wraps correctly,
    // since it has its own copy logic separate from the Data-based path.
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.3)
    let chunkSize = 4800

    // Position writeIndex at 158400 via write + drain
    for _ in 0..<33 {
      let data = makeData(byte: 0x00, count: chunkSize)
      data.withUnsafeBytes { bytes in
        buffer.append(from: bytes.baseAddress!, count: bytes.count)
      }
    }
    _ = buffer.processChunks()

    // Write a wrapping chunk via the raw-pointer path
    var wrappingData = Data()
    wrappingData.append(makeData(byte: 0xEE, count: 1600))
    wrappingData.append(makeData(byte: 0xFF, count: 3200))

    wrappingData.withUnsafeBytes { bytes in
      buffer.append(from: bytes.baseAddress!, count: bytes.count)
    }

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data, wrappingData)
  }

  // MARK: - Overflow guard

  func testOverflowPreventsWrite() {
    let format = makeFormat(sampleRate: 8000)
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)
    let maxBuffer = 160000

    // Fill the buffer completely
    buffer.append(makeData(byte: 0x01, count: maxBuffer))

    // Try to append more — should be silently rejected (overflow guard)
    buffer.append(makeData(byte: 0x02, count: 100))

    // Drain and verify we only got the original data
    let packets = buffer.processChunks()
    let totalBytes = packets.reduce(0) { $0 + $1.data.count }
    XCTAssertEqual(totalBytes, maxBuffer)

    // Every byte should be 0x01, not 0x02
    for packet in packets {
      XCTAssertTrue(packet.data.allSatisfy { $0 == 0x01 })
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
      buffer.append(makeData(byte: UInt8(i), count: callbackSize))
    }

    let packets = buffer.processChunks()
    XCTAssertEqual(packets.count, 1)
    XCTAssertEqual(packets[0].data.count, chunkSize)

    // Verify the data is in the correct order
    for i in 0..<10 {
      let slice = packets[0].data.subdata(in: (i * callbackSize)..<((i + 1) * callbackSize))
      XCTAssertTrue(slice.allSatisfy { $0 == UInt8(i) })
    }
  }

  // MARK: - Packet metadata

  func testChunkDurationIsCorrect() {
    let format = makeFormat()
    let buffer = AudioBuffer(format: format, chunkDuration: 0.1)

    buffer.append(makeData(byte: 0x00, count: 3200))
    let packets = buffer.processChunks()

    XCTAssertEqual(packets[0].duration, 0.1, accuracy: 0.001)
  }
}
