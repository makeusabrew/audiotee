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

  Logger.debug(
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

/// Translates an array of process IDs to AudioObjectIDs using Core Audio
/// Returns an array of AudioObjectIDs for valid processes
/// Throws an error if any PIDs cannot be translated
func translatePIDsToProcessObjects(_ pids: [Int32]) throws -> [AudioObjectID] {
  guard !pids.isEmpty else {
    return []
  }

  var processObjects: [AudioObjectID] = []
  var failedPIDs: [Int32] = []

  for pid in pids {
    var address = getPropertyAddress(selector: kAudioHardwarePropertyTranslatePIDToProcessObject)
    var processObject: AudioObjectID = 0
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var mutablePid = pid  // Create mutable copy for the API call

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      UInt32(MemoryLayout<pid_t>.size),
      &mutablePid,
      &size,
      &processObject
    )

    if status == kAudioHardwareNoError && processObject != kAudioObjectUnknown {
      processObjects.append(processObject)
      Logger.debug(
        "Translated PID to process object",
        context: [
          "pid": String(pid),
          "process_object": String(processObject),
        ])
    } else {
      failedPIDs.append(pid)
      Logger.debug(
        "Failed to translate PID to process object",
        context: [
          "pid": String(pid),
          "status": String(status),
        ])
    }
  }

  // Throw error if any PIDs failed to translate
  if !failedPIDs.isEmpty {
    throw AudioTeeError.pidTranslationFailed(failedPIDs)
  }

  return processObjects
}

extension String {
  func print(to fileHandle: FileHandle) {
    if let data = (self + "\n").data(using: .utf8) {
      fileHandle.write(data)
    }
  }
}
