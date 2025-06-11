//
//  AudioRecorder.swift
//  t2
//
//  Created by Nick Payne on 11/06/2025.
//

import AudioToolbox
import CoreAudio
import Foundation

public class AudioRecorder {
  private var deviceID: AudioObjectID
  private var ioProcID: AudioDeviceIOProcID?
  private var streamFormat: AudioStreamBasicDescription?

  // Buffer to accumulate audio data
  private var audioBuffer: Data = Data()
  private let targetChunkDuration = 0.2  // 200ms chunks for optimal ASR accuracy

  public init(deviceID: AudioObjectID) {
    self.deviceID = deviceID
  }

  private func writeMetadata() {
    guard let format = streamFormat else {
      "Error: No stream format available".print(to: .standardError)
      return
    }

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

    // Send metadata and stream start using the unified API
    Logger.writeMessage(.metadata, data: metadata)
    Logger.writeMessage(.streamStart, data: Optional<String>.none)
  }

  public func startRecording() {
    Logger.debug("Getting device format")
    // Get the device's native stream format
    var propertyAddress = getPropertyAddress(
      selector: kAudioDevicePropertyStreamFormat,
      scope: kAudioDevicePropertyScopeInput)
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
    var streamFormat = AudioStreamBasicDescription()
    var status = AudioObjectGetPropertyData(
      deviceID, &propertyAddress, 0, nil, &propertySize, &streamFormat)

    guard status == noErr else {
      fatalError("Failed to get stream format: \(status)")
    }

    // Store and use the device's native format - no conversion
    self.streamFormat = streamFormat

    Logger.debug(
      "Using device's native format",
      context: [
        "channels": String(streamFormat.mChannelsPerFrame),
        "sample_rate": String(streamFormat.mSampleRate),
        "bits_per_channel": String(streamFormat.mBitsPerChannel),
        "format_id": String(streamFormat.mFormatID),
        "format_flags": String(format: "0x%08x", streamFormat.mFormatFlags),
        "bytes_per_frame": String(streamFormat.mBytesPerFrame),
      ]
    )

    // Write metadata before starting the audio stream
    writeMetadata()

    // Start the IO proc
    Logger.debug("Creating IO proc")
    status = AudioDeviceCreateIOProcID(
      deviceID,
      {
        (
          inDevice, inNow, inInputData, inInputTime,
          outOutputData, inOutputTime, inClientData
        ) -> OSStatus in
        let recorder = Unmanaged<AudioRecorder>.fromOpaque(inClientData!)
          .takeUnretainedValue()
        return recorder.processAudio(inInputData)
      }, Unmanaged.passUnretained(self).toOpaque(), &ioProcID)

    guard status == noErr else {
      fatalError("Failed to create IO proc: \(status)")
    }

    // Start the device
    Logger.debug("Starting audio device")
    status = AudioDeviceStart(deviceID, ioProcID)
    if status != noErr {
      // Clean up if we failed to start
      if let proc = ioProcID {
        AudioDeviceDestroyIOProcID(deviceID, proc)
        ioProcID = nil
      }
      fatalError("Failed to start audio device: \(status). Device ID: \(deviceID)")
    }

    Logger.info("Audio device started successfully")
  }

  private func processAudioChunk() -> AudioPacket? {
    guard let streamFormat = streamFormat else { return nil }

    let bytesPerFrame = Int(streamFormat.mBytesPerFrame)
    let samplesPerChunk = Int(streamFormat.mSampleRate * targetChunkDuration)
    let bytesPerChunk = samplesPerChunk * bytesPerFrame

    guard audioBuffer.count >= bytesPerChunk else { return nil }

    // Get the chunk data without any conversion
    let chunkData = audioBuffer.prefix(bytesPerChunk)

    // Create the audio packet with raw data
    let packet = AudioPacket(
      timestamp: Date(),
      duration: Double(samplesPerChunk) / streamFormat.mSampleRate,
      peakAmplitude: 0.0,  // No analysis in raw mode
      rmsAmplitude: 0.0,  // No analysis in raw mode
      zeroCrossings: 0,  // No analysis in raw mode
      dcOffset: 0.0,  // No analysis in raw mode
      clippingRatio: 0.0,  // No analysis in raw mode
      audioData: chunkData.base64EncodedString()
    )

    // Remove the processed data
    audioBuffer.removeFirst(bytesPerChunk)

    return packet
  }

  private func processAudio(_ inputData: UnsafePointer<AudioBufferList>) -> OSStatus {
    let bufferList = inputData.pointee
    let firstBuffer = bufferList.mBuffers

    if firstBuffer.mData == nil || firstBuffer.mDataByteSize == 0 {
      "Warning: Received empty audio buffer".print(to: .standardError)
      return noErr
    }

    // Simply append the raw audio data without any conversion
    let audioData = Data(bytes: firstBuffer.mData!, count: Int(firstBuffer.mDataByteSize))
    audioBuffer.append(audioData)

    // Process complete chunks
    while let packet = processAudioChunk() {
      // Send audio packet using the unified API
      Logger.audio(packet)
    }

    return noErr
  }

  public func stopRecording() {
    // Send any remaining buffered audio
    if !audioBuffer.isEmpty {
      // Process the final chunk with whatever data we have
      let packet = AudioPacket(
        timestamp: Date(),
        duration: 0.0,  // Unknown duration for final chunk
        peakAmplitude: 0.0,
        rmsAmplitude: 0.0,
        zeroCrossings: 0,
        dcOffset: 0.0,
        clippingRatio: 0.0,
        audioData: audioBuffer.base64EncodedString()
      )

      // Send final audio packet using the unified API
      Logger.audio(packet)
    }

    if let ioProcID = ioProcID {
      AudioDeviceStop(deviceID, ioProcID)
      AudioDeviceDestroyIOProcID(deviceID, ioProcID)
      self.ioProcID = nil
    }
  }
}
