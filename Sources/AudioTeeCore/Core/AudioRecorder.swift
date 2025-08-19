import AudioToolbox
import CoreAudio
import Foundation

public class AudioRecorder {
  private var deviceID: AudioObjectID
  private var ioProcID: AudioDeviceIOProcID?
  private var finalFormat: AudioStreamBasicDescription!
  private var audioBuffer: AudioBuffer?
  private var outputHandler: AudioOutputHandler
  private var converter: AudioFormatConverter?

  public init(
    deviceID: AudioObjectID, outputHandler: AudioOutputHandler, convertToSampleRate: Double? = nil,
    chunkDuration: Double = 0.2
  ) {
    self.deviceID = deviceID
    self.outputHandler = outputHandler

    // Get source format and set up conversion if requested
    let sourceFormat = AudioFormatManager.getDeviceFormat(deviceID: deviceID)

    // Set up the audio buffer using source format and configurable chunk duration
    self.audioBuffer = AudioBuffer(format: sourceFormat, chunkDuration: chunkDuration)

    if let targetSampleRate = convertToSampleRate {
      // Validate sample rate
      guard AudioFormatConverter.isValidSampleRate(targetSampleRate) else {
        Logger.error("Invalid sample rate", context: ["sample_rate": String(targetSampleRate)])
        self.converter = nil
        self.finalFormat = sourceFormat
        return
      }

      do {
        let converter = try AudioFormatConverter.toSampleRate(targetSampleRate, from: sourceFormat)
        self.converter = converter
        self.finalFormat = converter.targetFormatDescription
        Logger.info(
          "Audio conversion enabled", context: ["target_sample_rate": String(targetSampleRate)])
      } catch {
        Logger.error(
          "Failed to create audio converter, using original format",
          context: ["error": String(describing: error)])
        self.converter = nil
        self.finalFormat = sourceFormat
      }
    } else {
      self.converter = nil
      self.finalFormat = sourceFormat
    }
  }

  public func startRecording() {
    Logger.debug("Starting audio recording")

    // Log format info and send metadata for final format
    AudioFormatManager.logFormatInfo(finalFormat)
    let metadata = AudioFormatManager.createMetadata(for: finalFormat)
    outputHandler.handleMetadata(metadata)
    outputHandler.handleStreamStart()

    setupAndStartIOProc()

    Logger.info("Audio device started successfully")
  }

  // Note to self, what about installTap? Would require audio engine and a node?
  // No; AudioEngine.installTap() can only fire as often as 100ms. too slow for us
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

    processAudioBuffer()

    return noErr
  }

  public func stopRecording() {
    processAudioBuffer()
    outputHandler.handleStreamStop()
    cleanupIOProc()
  }

  private func processAudioBuffer() {
    // Process and send complete chunks, applying conversion if needed
    audioBuffer?.processChunks().forEach { packet in
      let processedPacket = converter?.transform(packet) ?? packet
      outputHandler.handleAudioPacket(processedPacket)
    }
  }

  private func cleanupIOProc() {
    if let ioProcID = ioProcID {
      AudioDeviceStop(deviceID, ioProcID)
      AudioDeviceDestroyIOProcID(deviceID, ioProcID)
      self.ioProcID = nil
    }
  }
}
