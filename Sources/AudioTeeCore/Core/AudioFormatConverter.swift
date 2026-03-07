import AVFoundation
import CoreAudio
import Foundation

/// Audio format converter using AVFoundation's AVAudioConverter.
///
/// Pre-allocates input/output buffers on first use and reuses them across
/// transform() calls. This eliminates two AVAudioPCMBuffer heap allocations
/// per chunk — significant when chunks are small (50ms = 20 calls/sec).
public class AudioFormatConverter {
  private let avConverter: AVAudioConverter
  private let sourceFormat: AVAudioFormat
  private let targetFormat: AVAudioFormat

  /// Pre-allocated buffers reused across transform() calls. Lazily created
  /// on first transform() since we need the actual input frame count to
  /// size them correctly.
  private var cachedInputBuffer: AVAudioPCMBuffer?
  private var cachedOutputBuffer: AVAudioPCMBuffer?

  public init(sourceFormat: AudioStreamBasicDescription, targetFormat: AudioStreamBasicDescription)
    throws
  {
    var mutableSourceFormat = sourceFormat
    var mutableTargetFormat = targetFormat

    guard let sourceAVFormat = AVAudioFormat(streamDescription: &mutableSourceFormat),
      let targetAVFormat = AVAudioFormat(streamDescription: &mutableTargetFormat)
    else {
      throw AudioConverterError.invalidFormat
    }

    guard let converter = AVAudioConverter(from: sourceAVFormat, to: targetAVFormat) else {
      throw AudioConverterError.creationFailed
    }

    self.sourceFormat = sourceAVFormat
    self.targetFormat = targetAVFormat
    self.avConverter = converter

    AudioTeeLogging.logger.debug(
      "Audio converter created",
      context: [
        "source_sample_rate": String(sourceAVFormat.sampleRate),
        "target_sample_rate": String(targetAVFormat.sampleRate),
        "source_channels": String(sourceAVFormat.channelCount),
        "target_channels": String(targetAVFormat.channelCount),
      ])

    // Warn about upsampling once during initialization
    if targetAVFormat.sampleRate > sourceAVFormat.sampleRate {
      AudioTeeLogging.logger.info(
        "Upsampling audio - this doesn't add frequency content above the original Nyquist limit",
        context: [
          "source_rate": String(sourceAVFormat.sampleRate),
          "target_rate": String(targetAVFormat.sampleRate),
        ])
    }
  }

  /// The source format this converter reads from.
  public var sourceFormatDescription: AudioStreamBasicDescription {
    return sourceFormat.streamDescription.pointee
  }

  /// The target format this converter produces.
  public var targetFormatDescription: AudioStreamBasicDescription {
    return targetFormat.streamDescription.pointee
  }

  /// Returns pre-allocated input and output buffers sized for the given
  /// input frame count. Allocates once on first call; reuses on subsequent
  /// calls when capacity is sufficient. Re-allocates if a larger frame
  /// count arrives (shouldn't happen with fixed chunk sizes, but handled
  /// gracefully).
  private func getBuffers(inputFrameCount: AVAudioFrameCount)
    -> (input: AVAudioPCMBuffer, output: AVAudioPCMBuffer)?
  {
    // ceil() prevents float-to-int truncation from undersizing the buffer
    // by one frame (e.g. 3199.9999 → 3199 instead of 3200).
    let outputFrameCount = AVAudioFrameCount(
      ceil(Double(inputFrameCount) * (targetFormat.sampleRate / sourceFormat.sampleRate))
    )

    // Reuse cached buffers if they have sufficient capacity
    if let inputBuf = cachedInputBuffer,
      let outputBuf = cachedOutputBuffer,
      inputBuf.frameCapacity >= inputFrameCount,
      outputBuf.frameCapacity >= outputFrameCount
    {
      // Reset frame lengths for reuse — the underlying memory is retained,
      // we just tell AVAudioPCMBuffer how many frames are valid this time.
      inputBuf.frameLength = 0
      outputBuf.frameLength = 0
      return (inputBuf, outputBuf)
    }

    // Allocate new buffers (first call, or unexpected capacity increase)
    guard
      let inputBuf = AVAudioPCMBuffer(
        pcmFormat: sourceFormat, frameCapacity: inputFrameCount)
    else {
      AudioTeeLogging.logger.error("Failed to create input buffer")
      return nil
    }

    guard
      let outputBuf = AVAudioPCMBuffer(
        pcmFormat: targetFormat, frameCapacity: outputFrameCount)
    else {
      AudioTeeLogging.logger.error("Failed to create output buffer")
      return nil
    }

    // Cache for reuse on subsequent calls
    cachedInputBuffer = inputBuf
    cachedOutputBuffer = outputBuf

    AudioTeeLogging.logger.debug(
      "Allocated converter buffers",
      context: [
        "input_frame_capacity": String(inputFrameCount),
        "output_frame_capacity": String(outputFrameCount),
      ])

    return (inputBuf, outputBuf)
  }

  /// Converts audio data in-place through the pre-allocated converter buffers.
  /// Calls `handler` with a pointer to the converted output, valid only for
  /// the duration of that call. Returns false on failure (caller should
  /// pass through the original data or drop it).
  @discardableResult
  public func transform(
    from source: UnsafeRawPointer, count: Int,
    handler: (UnsafeRawPointer, Int) -> Void
  ) -> Bool {
    let bytesPerFrame = Int(sourceFormat.streamDescription.pointee.mBytesPerFrame)
    let inputFrameCount = AVAudioFrameCount(count / bytesPerFrame)

    guard let (inputBuffer, outputBuffer) = getBuffers(inputFrameCount: inputFrameCount) else {
      return false
    }

    // Copy source data into the reusable input buffer
    let dest = inputBuffer.audioBufferList.pointee.mBuffers.mData!
    dest.copyMemory(from: source, byteCount: count)
    inputBuffer.frameLength = inputFrameCount

    // Perform conversion — we do NOT call avConverter.reset() between
    // calls because the resampler maintains internal state for continuity
    // across chunks (avoiding discontinuity artifacts).
    var error: NSError?

    let status = avConverter.convert(to: outputBuffer, error: &error) {
      requestedPackets, outStatus in
      outStatus.pointee = .haveData
      return inputBuffer
    }

    guard outputBuffer.frameLength > 0 else {
      AudioTeeLogging.logger.error(
        "Audio conversion produced no output",
        context: [
          "status": String(describing: status),
          "error": String(describing: error),
          "input_frames": String(inputBuffer.frameLength),
          "output_capacity": String(outputBuffer.frameCapacity),
        ])
      return false
    }

    let outputCount = Int(
      outputBuffer.frameLength * targetFormat.streamDescription.pointee.mBytesPerFrame)
    handler(outputBuffer.audioBufferList.pointee.mBuffers.mData!, outputCount)
    return true
  }

  public static func toSampleRate(
    _ sampleRate: Double, from sourceFormat: AudioStreamBasicDescription
  ) throws -> AudioFormatConverter {
    var targetFormat = AudioStreamBasicDescription()
    targetFormat.mSampleRate = sampleRate
    targetFormat.mFormatID = kAudioFormatLinearPCM
    targetFormat.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger
    targetFormat.mFramesPerPacket = 1
    targetFormat.mBitsPerChannel = 16
    targetFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame
    targetFormat.mBytesPerFrame =
      (targetFormat.mBitsPerChannel / 8) * sourceFormat.mChannelsPerFrame
    targetFormat.mBytesPerPacket = targetFormat.mFramesPerPacket * targetFormat.mBytesPerFrame

    return try AudioFormatConverter(sourceFormat: sourceFormat, targetFormat: targetFormat)
  }

  public static func isValidSampleRate(_ sampleRate: Double) -> Bool {
    return [8000, 16000, 22050, 24000, 32000, 44100, 48000].contains(sampleRate)
  }
}
