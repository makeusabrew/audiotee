import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

public class AudioTapManager {
  private var tapID: AudioObjectID?
  private var deviceID: AudioObjectID?

  public init() {}

  deinit {
    AudioTeeLogging.logger.debug("Cleaning up audio tap manager")

    if let tapID = tapID {
      AudioHardwareDestroyProcessTap(tapID)
      self.tapID = nil
    }

    if let deviceID = deviceID {
      AudioHardwareDestroyAggregateDevice(deviceID)
      self.deviceID = nil
    }
  }

  /// Sets up the audio tap and aggregate device
  public func setupAudioTap(with config: TapConfiguration) throws {
    AudioTeeLogging.logger.debug("Setting up audio tap manager")

    let (createdTapID, tapUUID) = try createSystemAudioTap(with: config)
    tapID = createdTapID
    deviceID = try createAggregateDevice(tapUUID: tapUUID)

    guard tapID != nil, deviceID != nil else {
      throw AudioTeeError.setupFailed
    }

    AudioTeeLogging.logger.debug("Audio tap manager setup complete")
  }

  /// Returns the aggregate device ID for recording
  public func getDeviceID() -> AudioObjectID? {
    return deviceID
  }

  private func createSystemAudioTap(with config: TapConfiguration) throws -> (AudioObjectID, String) {
    AudioTeeLogging.logger.debug("Creating tap description")
    let description = CATapDescription()

    description.name = "audiotee-tap"
    description.processes = try translatePIDsToProcessObjects(config.processes)  // Properly translate PIDs
    description.isPrivate = true
    description.muteBehavior = config.muteBehavior.coreAudioValue
    description.isMixdown = true
    description.isMono = config.isMono
    description.isExclusive = config.isExclusive
    description.deviceUID = nil  // system default
    description.stream = 0  // first stream of output device

    // Get the UUID from the description before creating the tap
    let tapUUID = description.uuid.uuidString

    AudioTeeLogging.logger.debug(
      "Tap description configured",
      context: [
        "name": description.name,
        "processes": String(describing: config.processes),
        "mute": String(describing: description.muteBehavior),
        "mono": String(description.isMono),
        "exclusive": String(description.isExclusive),
        "uuid": tapUUID,
      ])

    // Create the tap
    AudioTeeLogging.logger.debug("Creating tap")
    var tapID = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateProcessTap(description, &tapID)

    AudioTeeLogging.logger.debug(
      "AudioHardwareCreateProcessTap completed", context: ["status": String(status)])
    guard status == kAudioHardwareNoError else {
      AudioTeeLogging.logger.error(
        "Failed to create audio tap", context: ["status": String(status)])
      throw AudioTeeError.tapCreationFailed(status)
    }

    // Get the format of the audio tap
    var propertyAddress = getPropertyAddress(selector: kAudioTapPropertyFormat)
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
    var streamDescription = AudioStreamBasicDescription()
    let formatStatus = AudioObjectGetPropertyData(
      tapID, &propertyAddress, 0, nil, &propertySize, &streamDescription)

    if formatStatus == noErr {
      AudioTeeLogging.logger.debug(
        "Tap format retrieved",
        context: [
          "channels": String(streamDescription.mChannelsPerFrame),
          "sample_rate": String(Int(streamDescription.mSampleRate)),
        ])
    }

    return (tapID, tapUUID)
  }

  private func createAggregateDevice(tapUUID: String) throws -> AudioObjectID {
    let uid = UUID().uuidString

    // Include the tap in the aggregate device creation dictionary using
    // structured sub-tap dictionaries. This is required on macOS 26+ where
    // adding the tap via AudioObjectSetPropertyData after creation no longer
    // delivers audio data.
    let tapList: [[String: Any]] = [
      [
        kAudioSubTapUIDKey: tapUUID,
        kAudioSubTapDriftCompensationKey: true,
      ]
    ]

    let description: [String: Any] = [
      kAudioAggregateDeviceNameKey: "audiotee-aggregate-device",
      kAudioAggregateDeviceUIDKey: uid,
      kAudioAggregateDeviceTapListKey: tapList,
      kAudioAggregateDeviceTapAutoStartKey: false,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
    ]

    var deviceID: AudioObjectID = 0
    let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)

    guard status == kAudioHardwareNoError else {
      AudioTeeLogging.logger.error(
        "Failed to create aggregate device", context: ["status": String(status)])
      throw AudioTeeError.aggregateDeviceCreationFailed(status)
    }

    return deviceID
  }
}
