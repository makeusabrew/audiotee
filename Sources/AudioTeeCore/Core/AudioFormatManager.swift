import AudioToolbox
import CoreAudio
import Foundation

public class AudioFormatManager {
  public static func getDeviceFormat(deviceID: AudioObjectID) -> AudioStreamBasicDescription {
    // First, wait for the device to become alive/ready
    let deviceReadyTimeout = 2.0  // 2 seconds max wait
    let pollInterval = 0.1  // 100ms poll interval
    let maxPolls = Int(deviceReadyTimeout / pollInterval)

    Logger.debug(
      "Waiting for audio device to become ready", context: ["device_id": String(deviceID)])

    // Poll device readiness
    for poll in 1...maxPolls {
      if isAudioDeviceValid(deviceID) {
        Logger.debug(
          "Audio device is ready", context: ["device_id": String(deviceID), "polls": String(poll)])
        break
      }

      if poll == maxPolls {
        Logger.info(
          "Device did not become ready within timeout, proceeding anyway",
          context: [
            "device_id": String(deviceID),
            "timeout_seconds": String(deviceReadyTimeout),
          ])
        break
      }

      Logger.info("------- not ready; retrying...")

      Thread.sleep(forTimeInterval: pollInterval)
    }

    // Now attempt to get the stream format with limited retries
    let maxRetries = 3  // Reduced since device should be ready
    let retryDelayMs = 20  // Shorter delay since we've already waited for readiness

    for attempt in 1...maxRetries {
      var propertyAddress = getPropertyAddress(
        selector: kAudioDevicePropertyStreamFormat,
        scope: kAudioDevicePropertyScopeInput)
      var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
      var streamFormat = AudioStreamBasicDescription()
      let status = AudioObjectGetPropertyData(
        deviceID, &propertyAddress, 0, nil, &propertySize, &streamFormat)

      if status == noErr {
        Logger.debug("Successfully retrieved device format", context: ["attempt": String(attempt)])
        return streamFormat
      }

      Logger.info(
        "------- Failed to get stream format after device ready check, retrying...",
        context: [
          "attempt": String(attempt),
          "max_retries": String(maxRetries),
          "status": String(status),
          "device_id": String(deviceID),
        ])

      // Don't delay on the last attempt
      if attempt < maxRetries {
        Thread.sleep(forTimeInterval: Double(retryDelayMs) / 1000.0)
      }
    }

    // If all attempts failed after device readiness confirmation, this is a genuine error
    Logger.error(
      "Failed to get device format after device readiness check and retries",
      context: [
        "device_id": String(deviceID),
        "device_was_ready": "true",
      ])

    fatalError(
      "Failed to get stream format from ready device: \(deviceID). This indicates a Core Audio subsystem error."
    )
  }

  static func createMetadata(for format: AudioStreamBasicDescription) -> AudioStreamMetadata {
    return AudioStreamMetadata(
      sampleRate: format.mSampleRate,
      channelsPerFrame: format.mChannelsPerFrame,
      bitsPerChannel: format.mBitsPerChannel,
      isFloat: format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
      captureMode: "audio",
      deviceName: nil,  // TODO: Get device name if needed
      deviceUID: nil,  // TODO: Get device UID if needed
      encoding: format.mFormatFlags & kAudioFormatFlagIsFloat != 0 ? "pcm_f32le" : "pcm_s16le"
    )
  }

  public static func writeMetadata(for format: AudioStreamBasicDescription) {
    let metadata = createMetadata(for: format)
    Logger.writeMessage(.metadata, data: metadata)
    Logger.writeMessage(.streamStart, data: Optional<String>.none)
  }

  public static func logFormatInfo(_ format: AudioStreamBasicDescription) {
    Logger.debug(
      "Using device's native format",
      context: [
        "channels": String(format.mChannelsPerFrame),
        "sample_rate": String(format.mSampleRate),
        "bits_per_channel": String(format.mBitsPerChannel),
        "format_id": String(format.mFormatID),
        "format_flags": String(format: "0x%08x", format.mFormatFlags),
        "bytes_per_frame": String(format.mBytesPerFrame),
      ]
    )
  }
}
