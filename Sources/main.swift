import AudioToolbox
import Foundation

extension FileHandle {
    static let standardError = FileHandle.standardError
}

extension String {
    func print(to fileHandle: FileHandle) {
        if let data = (self + "\n").data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

enum RecordingMode: String, CaseIterable {
    case systemAudio = "system"
    case microphone = "mic"
}

func signalHandler(_ signal: Int32) {
    Logger.info("Received signal \(signal), initiating graceful shutdown...")
    CFRunLoopStop(CFRunLoopGetMain())
}

func printUsage() {
    print("Usage: audiotee [mode]")
    print("Modes:")
    print("  system  - Record system audio (default)")
    print("  mic     - Record microphone with echo cancellation")
}

func parseArguments() -> RecordingMode {
    let arguments = CommandLine.arguments

    // If no arguments provided, default to system audio
    guard arguments.count > 1 else {
        return .systemAudio
    }

    let modeArg = arguments[1].lowercased()

    if let mode = RecordingMode(rawValue: modeArg) {
        return mode
    } else {
        printUsage()
        exit(1)
    }
}

func runSystemAudioMode() {
    Logger.info("Starting in system audio mode...")

    let audioTapManager = AudioTeeManager()
    do {
        try audioTapManager.setupAudioTap()
    } catch {
        Logger.error(
            "Failed to setup audio tap", context: ["error": String(describing: error)])
        return
    }

    guard let deviceID = audioTapManager.getDeviceID() else {
        Logger.error("Failed to get device ID from audio tap manager")
        return
    }

    let recorder = AudioRecorder(deviceID: deviceID)
    recorder.startRecording()

    // Run until the run loop is stopped (by signal handler)
    while true {
        let result = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.1, false)
        if result == CFRunLoopRunResult.stopped || result == CFRunLoopRunResult.finished {
            break
        }
    }

    Logger.info("Shutting down system audio mode...")
    recorder.stopRecording()
}

func runMicrophoneMode() {
    Logger.info("Starting in microphone mode with echo cancellation...")

    let microphoneManager = MicrophoneManager()
    do {
        try microphoneManager.setupMicrophone()
    } catch {
        Logger.error(
            "Failed to setup microphone", context: ["error": String(describing: error)])
        return
    }

    guard let deviceID = microphoneManager.getDeviceID() else {
        Logger.error("Failed to get device ID from microphone manager")
        return
    }

    guard let audioFormat = microphoneManager.getAudioFormat() else {
        Logger.error("Failed to get audio format from microphone manager")
        return
    }

    let recorder = AudioRecorder(deviceID: deviceID, customFormat: audioFormat)
    recorder.startRecording()

    // Run until the run loop is stopped (by signal handler)
    while true {
        let result = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.1, false)
        if result == CFRunLoopRunResult.stopped || result == CFRunLoopRunResult.finished {
            break
        }
    }

    Logger.info("Shutting down microphone mode...")
    recorder.stopRecording()
}

func run() {
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)

    let mode = parseArguments()

    switch mode {
    case .systemAudio:
        runSystemAudioMode()
    case .microphone:
        runMicrophoneMode()
    }
}

run()
