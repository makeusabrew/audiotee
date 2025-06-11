import AudioToolbox
import CoreAudio
import Foundation

public class AudioFormatManager {
  public static func getDeviceFormat(deviceID: AudioObjectID) -> AudioStreamBasicDescription {
    var propertyAddress = getPropertyAddress(
      selector: kAudioDevicePropertyStreamFormat,
      scope: kAudioDevicePropertyScopeInput)
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
    var streamFormat = AudioStreamBasicDescription()
    let status = AudioObjectGetPropertyData(
      deviceID, &propertyAddress, 0, nil, &propertySize, &streamFormat)

    guard status == noErr else {
      fatalError("Failed to get stream format: \(status)")
    }

    return streamFormat
  }

  public static func writeMetadata(for format: AudioStreamBasicDescription) {
    let metadata = AudioStreamMetadata(
      sampleRate: format.mSampleRate,
      channelsPerFrame: format.mChannelsPerFrame,
      bitsPerChannel: format.mBitsPerChannel,
      isFloat: format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
      captureMode: "audio",
      deviceName: nil,  // TODO: Get device name if needed
      deviceUID: nil,  // TODO: Get device UID if needed
      encoding: format.mFormatFlags & kAudioFormatFlagIsFloat != 0 ? "pcm_f32le" : "pcm_s16le"
    )

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
