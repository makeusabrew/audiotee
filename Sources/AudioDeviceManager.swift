import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

struct AudioDeviceManager {
  static func isDeviceValid(_ deviceID: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsAlive,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)

    var isAlive: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isAlive)

    let valid = status == kAudioHardwareNoError && isAlive == 1

    MessageWriter.debug(
      "Checked device validity",
      context: [
        "device_id": String(deviceID),
        "status": String(status),
        "is_alive": String(isAlive),
        "valid": String(valid),
      ])
    return valid
  }

  static func getDefaultInputDevice() -> AudioObjectID {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)

    var deviceID = kAudioObjectUnknown
    var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceID)

    guard status == kAudioHardwareNoError else {
      MessageWriter.error("Failed to get default input device", context: ["status": String(status)])
      fatalError("Failed to get default input device: \(status)")
    }

    MessageWriter.debug("Retrieved default input device", context: ["device_id": String(deviceID)])
    return deviceID
  }
}
