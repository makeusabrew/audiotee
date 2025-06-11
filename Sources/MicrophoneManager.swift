//
//  MicrophoneManager.swift
//  AudioTee
//
//  Created for microphone recording with echo cancellation
//

import AudioToolbox
import CoreAudio
import Foundation

class MicrophoneManager {
  private var audioUnit: AudioUnit?
  private var defaultInputDeviceID: AudioObjectID?

  init() {
    // Empty init - setup happens in setupMicrophone()
  }

  deinit {
    Logger.debug("Cleaning up microphone manager")
    cleanup()
  }

  /// Sets up the microphone with echo cancellation
  func setupMicrophone() throws {
    Logger.debug("Setting up microphone with echo cancellation")

    // Get the default input device
    try setupDefaultInputDevice()

    // Set up the audio unit for microphone input with echo cancellation
    try setupAudioUnit()

    Logger.debug("Microphone setup complete with echo cancellation enabled")
  }

  /// Returns the default input device ID for recording
  func getDeviceID() -> AudioObjectID? {
    return defaultInputDeviceID
  }

  /// Returns the actual audio format used by the AudioUnit
  func getAudioFormat() -> AudioStreamBasicDescription? {
    guard let audioUnit = audioUnit else { return nil }

    var audioFormat = AudioStreamBasicDescription()
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

    let status = AudioUnitGetProperty(
      audioUnit,
      kAudioUnitProperty_StreamFormat,
      kAudioUnitScope_Output,
      1,  // Input bus output scope
      &audioFormat,
      &propertySize
    )

    guard status == noErr else {
      Logger.error("Failed to get audio unit format", context: ["status": String(status)])
      return nil
    }

    return audioFormat
  }

  private func setupDefaultInputDevice() throws {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var deviceID: AudioObjectID = 0
    var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceID
    )

    guard status == noErr && deviceID != kAudioObjectUnknown else {
      Logger.error(
        "Failed to get default input device or no microphone available",
        context: ["status": String(status)])
      throw MicrophoneError.noInputDeviceAvailable
    }

    self.defaultInputDeviceID = deviceID
    Logger.debug("Default input device configured", context: ["deviceID": String(deviceID)])
  }

  private func setupAudioUnit() throws {
    // For echo cancellation, we use VoiceProcessingIO AudioUnit
    var componentDescription = AudioComponentDescription()
    componentDescription.componentType = kAudioUnitType_Output
    componentDescription.componentSubType = kAudioUnitSubType_VoiceProcessingIO
    componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple
    componentDescription.componentFlags = 0
    componentDescription.componentFlagsMask = 0

    // Find the component
    guard let component = AudioComponentFindNext(nil, &componentDescription) else {
      Logger.error("Failed to find VoiceProcessingIO audio component")
      throw MicrophoneError.audioUnitCreationFailed
    }

    // Create the audio unit
    var status = AudioComponentInstanceNew(component, &audioUnit)
    guard status == noErr, let audioUnit = audioUnit else {
      Logger.error("Failed to create audio unit instance", context: ["status": String(status)])
      throw MicrophoneError.audioUnitCreationFailed
    }

    // Enable input on the VoiceProcessingIO unit
    var enableInput: UInt32 = 1
    status = AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Input,
      1,  // Input bus
      &enableInput,
      UInt32(MemoryLayout<UInt32>.size)
    )

    guard status == noErr else {
      Logger.error("Failed to enable input on audio unit", context: ["status": String(status)])
      throw MicrophoneError.audioUnitConfigurationFailed(status)
    }

    // Disable output (we're only recording, not playing back)
    var disableOutput: UInt32 = 0
    status = AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Output,
      0,  // Output bus
      &disableOutput,
      UInt32(MemoryLayout<UInt32>.size)
    )

    if status != noErr {
      Logger.debug("Could not disable output on audio unit", context: ["status": String(status)])
    }

    // Set the current device as the input device for the audio unit
    if defaultInputDeviceID != nil {
      status = AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &defaultInputDeviceID,
        UInt32(MemoryLayout<AudioObjectID>.size)
      )

      if status == noErr {
        Logger.debug("Audio unit configured to use default input device")
      } else {
        Logger.debug(
          "Could not set current device on audio unit", context: ["status": String(status)])
      }
    }

    // Enable voice processing (echo cancellation) by setting BypassVoiceProcessing to 0 (false)
    var bypassVoiceProcessing: UInt32 = 0
    status = AudioUnitSetProperty(
      audioUnit,
      kAUVoiceIOProperty_BypassVoiceProcessing,
      kAudioUnitScope_Global,
      0,
      &bypassVoiceProcessing,
      UInt32(MemoryLayout<UInt32>.size)
    )

    if status == noErr {
      Logger.debug("Voice processing (echo cancellation) enabled on audio unit")
    } else {
      Logger.debug(
        "Voice processing not available on this audio unit", context: ["status": String(status)])
    }

    // Don't force a format - let VoiceProcessingIO use its default format

    // Initialize the audio unit
    status = AudioUnitInitialize(audioUnit)
    guard status == noErr else {
      Logger.error("Failed to initialize audio unit", context: ["status": String(status)])
      throw MicrophoneError.audioUnitInitializationFailed(status)
    }

    Logger.debug("Audio unit configured and initialized successfully")
  }

  private func cleanup() {
    if let audioUnit = audioUnit {
      AudioUnitUninitialize(audioUnit)
      AudioComponentInstanceDispose(audioUnit)
      self.audioUnit = nil
    }

  }
}

// MARK: - Error Types

enum MicrophoneError: Error {
  case noInputDeviceAvailable
  case audioUnitCreationFailed
  case audioUnitConfigurationFailed(OSStatus)
  case audioUnitInitializationFailed(OSStatus)
}
