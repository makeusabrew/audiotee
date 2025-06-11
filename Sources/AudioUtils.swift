import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

// MARK: - Audio Device Utilities

/// Checks if an audio device is valid and alive
func isAudioDeviceValid(_ deviceID: AudioObjectID) -> Bool {
  var address = getPropertyAddress(selector: kAudioDevicePropertyDeviceIsAlive)

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

/// Creates an AudioObjectPropertyAddress with the given selector and optional scope/element
func getPropertyAddress(
  selector: AudioObjectPropertySelector,
  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
  element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
  return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}
