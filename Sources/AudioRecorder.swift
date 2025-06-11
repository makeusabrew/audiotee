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
  private var audioBuffer: AudioBuffer?
  private var customFormat: AudioStreamBasicDescription?

  public init(deviceID: AudioObjectID, customFormat: AudioStreamBasicDescription? = nil) {
    self.deviceID = deviceID
    self.customFormat = customFormat
  }

  public func startRecording() {
    Logger.debug("Getting device format")

    // Use custom format if provided, otherwise get the device's native stream format
    let format = customFormat ?? AudioFormatManager.getDeviceFormat(deviceID: deviceID)
    self.streamFormat = format

    // Set up the audio buffer
    self.audioBuffer = AudioBuffer(format: format)

    // Log format info and write metadata
    AudioFormatManager.logFormatInfo(format)
    AudioFormatManager.writeMetadata(for: format)

    // Set up and start the IO proc
    setupAndStartIOProc()

    Logger.info("Audio device started successfully")
  }

  private func setupAndStartIOProc() {
    Logger.debug("Creating IO proc")
    var status = AudioDeviceCreateIOProcID(
      deviceID,
      {
        (inDevice, inNow, inInputData, inInputTime, outOutputData, inOutputTime, inClientData)
          -> OSStatus in
        let recorder = Unmanaged<AudioRecorder>.fromOpaque(inClientData!).takeUnretainedValue()
        return recorder.processAudio(inInputData)
      },
      Unmanaged.passUnretained(self).toOpaque(),
      &ioProcID
    )

    guard status == noErr else {
      fatalError("Failed to create IO proc: \(status)")
    }

    Logger.debug("Starting audio device")
    status = AudioDeviceStart(deviceID, ioProcID)

    if status != noErr {
      cleanupIOProc()
      fatalError("Failed to start audio device: \(status). Device ID: \(deviceID)")
    }
  }

  private func processAudio(_ inputData: UnsafePointer<AudioBufferList>) -> OSStatus {
    let bufferList = inputData.pointee
    let firstBuffer = bufferList.mBuffers

    guard firstBuffer.mData != nil && firstBuffer.mDataByteSize > 0 else {
      "Warning: Received empty audio buffer".print(to: .standardError)
      return noErr
    }

    // Append raw audio data to buffer
    let audioData = Data(bytes: firstBuffer.mData!, count: Int(firstBuffer.mDataByteSize))
    audioBuffer?.append(audioData)

    // Process and send complete chunks
    audioBuffer?.processChunks().forEach { packet in
      Logger.audio(packet)
    }

    return noErr
  }

  public func stopRecording() {
    // Send any remaining buffered audio
    if let finalPacket = audioBuffer?.flushRemaining() {
      Logger.audio(finalPacket)
    }

    cleanupIOProc()
  }

  private func cleanupIOProc() {
    if let ioProcID = ioProcID {
      AudioDeviceStop(deviceID, ioProcID)
      AudioDeviceDestroyIOProcID(deviceID, ioProcID)
      self.ioProcID = nil
    }
  }
}
