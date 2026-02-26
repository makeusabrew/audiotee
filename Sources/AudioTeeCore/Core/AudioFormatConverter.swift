import AVFoundation
import CoreAudio
import Foundation

/// Simple audio format converter using AVFoundation
public class AudioFormatConverter {
  private let avConverter: AVAudioConverter
  private let sourceFormat: AVAudioFormat
  private let targetFormat: AVAudioFormat

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

    Logger.debug(
      "Audio converter created",
      context: [
        "source_sample_rate": String(sourceAVFormat.sampleRate),
        "target_sample_rate": String(targetAVFormat.sampleRate),
        "source_channels": String(sourceAVFormat.channelCount),
        "target_channels": String(targetAVFormat.channelCount),
      ])

    // Warn about upsampling once during initialization
    if targetAVFormat.sampleRate > sourceAVFormat.sampleRate {
      Logger.info(
        "Upsampling audio - this doesn't add frequency content above the original Nyquist limit",
        context: [
          "source_rate": String(sourceAVFormat.sampleRate),
          "target_rate": String(targetAVFormat.sampleRate),
        ])
    }
  }

  /// Get the target format as AudioStreamBasicDescription
  public var targetFormatDescription: AudioStreamBasicDescription {
    return targetFormat.streamDescription.pointee
  }

  public func transform(_ packet: AudioPacket) -> AudioPacket {
    let inputData = packet.data

    // Calculate frame counts
    let inputFrameCount =
      inputData.count / Int(sourceFormat.streamDescription.pointee.mBytesPerFrame)
    let outputFrameCount = Int(
      Double(inputFrameCount) * (targetFormat.sampleRate / sourceFormat.sampleRate))

    // Create input buffer
    guard
      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(inputFrameCount))
    else {
      Logger.error("Failed to create input buffer")
      return packet
    }

    // Copy input data to buffer
    inputData.withUnsafeBytes { bytes in
      let dest = inputBuffer.audioBufferList.pointee.mBuffers.mData!
      dest.copyMemory(from: bytes.baseAddress!, byteCount: inputData.count)
    }
    inputBuffer.frameLength = AVAudioFrameCount(inputFrameCount)

    // Create output buffer
    guard
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(outputFrameCount))
    else {
      Logger.error("Failed to create output buffer")
      return packet
    }

    // Perform conversion - simpler approach
    var error: NSError?

    let status = avConverter.convert(to: outputBuffer, error: &error) {
      requestedPackets, outStatus in
      // Always provide our input buffer and let converter manage it
      outStatus.pointee = .haveData
      return inputBuffer
    }

    // Check if conversion produced output (regardless of status code)
    guard outputBuffer.frameLength > 0 else {
      Logger.error(
        "Audio conversion produced no output",
        context: [
          "status": String(describing: status),
          "error": String(describing: error),
          "input_frames": String(inputBuffer.frameLength),
          "output_capacity": String(outputBuffer.frameCapacity),
        ])
      return packet
    }

    // Extract converted data
    let outputData = Data(
      bytes: outputBuffer.audioBufferList.pointee.mBuffers.mData!,
      count: Int(outputBuffer.frameLength * targetFormat.streamDescription.pointee.mBytesPerFrame))

    // Return new packet with converted audio (keeping original metadata for simplicity)
    return AudioPacket(
      timestamp: packet.timestamp,
      duration: packet.duration,
      data: outputData
    )
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
