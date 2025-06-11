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

func signalHandler(_ signal: Int32) {
    Logger.info("Received signal \(signal), initiating graceful shutdown...")
    CFRunLoopStop(CFRunLoopGetMain())
}

func run() {
    Logger.info("Starting program...")

    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)

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

    Logger.info("Shutting down...")
    recorder.stopRecording()

}

run()
