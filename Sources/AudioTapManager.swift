//
//  AudioTapManager.swift
//  t2
//
//  Created by Nick Payne on 11/06/2025.
//


import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

struct AudioTapManager {
  static func createSystemAudioTap() -> AudioObjectID {
    MessageWriter.debug("Creating tap description")
    // Create a tap description
    let description = CATapDescription()

    // Configure the tap to capture all system audio
    description.name = "audiotee-tap"
    description.processes = []  // Empty array means capture all processes
    description.isPrivate = true
    description.muteBehavior = .unmuted
    description.isMixdown = true  // We want mono output
    description.isMono = true  // Mono, not stereo
    description.isExclusive = true  // Exclusive mode to capture all processes
    description.deviceUID = nil  // Let the system choose the device
    description.stream = 0  // Main stream

    MessageWriter.debug(
      "Tap description configured",
      context: [
        "name": description.name,
        "private": String(description.isPrivate),
        "mute": String(describing: description.muteBehavior),
        "mixdown": String(description.isMixdown),
        "mono": String(description.isMono),
        "exclusive": String(description.isExclusive),
      ])

    // Create the tap
    MessageWriter.debug("Creating tap with HAL")
    var tapID = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateProcessTap(description, &tapID)

    MessageWriter.debug(
      "AudioHardwareCreateProcessTap completed", context: ["status": String(status)])
    guard status == kAudioHardwareNoError else {
      MessageWriter.error("Failed to create audio tap", context: ["status": String(status)])
      fatalError("Failed to create audio tap: \(status)")
    }

    // Get the format of the audio tap
    var propertyAddress = AudioUtilities.getPropertyAddress(selector: kAudioTapPropertyFormat)
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
    var streamDescription = AudioStreamBasicDescription()
    let formatStatus = AudioObjectGetPropertyData(
      tapID, &propertyAddress, 0, nil, &propertySize, &streamDescription)

    if formatStatus == noErr {
      MessageWriter.debug(
        "Tap format retrieved",
        context: [
          "channels": String(streamDescription.mChannelsPerFrame),
          "sample_rate": String(Int(streamDescription.mSampleRate)),
        ])
    }

    return tapID
  }

  static func createAggregateDevice() -> AudioObjectID {
    let uid = UUID().uuidString
    let description =
      [
        kAudioAggregateDeviceNameKey: "tower-audio-aggregate-device",
        kAudioAggregateDeviceUIDKey: uid,
        kAudioAggregateDeviceSubDeviceListKey: [] as CFArray,
        kAudioAggregateDeviceMasterSubDeviceKey: 0,
        kAudioAggregateDeviceIsPrivateKey: true,
        kAudioAggregateDeviceIsStackedKey: false,
      ] as [String: Any]

    var deviceID: AudioObjectID = 0
    let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)

    guard status == kAudioHardwareNoError else {
      MessageWriter.error("Failed to create aggregate device", context: ["status": String(status)])
      fatalError("Failed to create aggregate device: \(status)")
    }

    return deviceID
  }

  static func addTapToAggregateDevice(tapID: AudioObjectID, deviceID: AudioObjectID) {
    // Get the tap's UID
    var propertyAddress = AudioUtilities.getPropertyAddress(selector: kAudioTapPropertyUID)
    var propertySize = UInt32(MemoryLayout<CFString>.stride)
    var tapUID: CFString = "" as CFString
    _ = withUnsafeMutablePointer(to: &tapUID) { tapUID in
      AudioObjectGetPropertyData(tapID, &propertyAddress, 0, nil, &propertySize, tapUID)
    }

    // Add the tap to the aggregate device
    propertyAddress = AudioUtilities.getPropertyAddress(
      selector: kAudioAggregateDevicePropertyTapList)
    let tapArray = [tapUID] as CFArray
    propertySize = UInt32(MemoryLayout<CFArray>.stride)

    let status = withUnsafePointer(to: tapArray) { ptr in
      AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, ptr)
    }

    guard status == kAudioHardwareNoError else {
      MessageWriter.error(
        "Failed to add tap to aggregate device", context: ["status": String(status)])
      fatalError("Failed to add tap to aggregate device: \(status)")
    }
  }

  static func destroyProcessTap(_ tapID: AudioObjectID) {
    MessageWriter.debug("Destroying process tap", context: ["tap_id": String(tapID)])
    let status = AudioHardwareDestroyProcessTap(tapID)
    
    if status != kAudioHardwareNoError {
      MessageWriter.error("Failed to destroy process tap", context: ["status": String(status)])
    } else {
      MessageWriter.debug("Process tap destroyed successfully")
    }
  }

  static func destroyAggregateDevice(_ deviceID: AudioObjectID) {
    MessageWriter.debug("Destroying aggregate device", context: ["device_id": String(deviceID)])
    let status = AudioHardwareDestroyAggregateDevice(deviceID)
    
    if status != kAudioHardwareNoError {
      MessageWriter.error("Failed to destroy aggregate device", context: ["status": String(status)])
    } else {
      MessageWriter.debug("Aggregate device destroyed successfully")
    }
  }
}
