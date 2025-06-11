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
    MessageWriter.info("Received signal \(signal), initiating graceful shutdown...")
    CFRunLoopStop(CFRunLoopGetMain())
}

func run() {
    MessageWriter.info("Starting program...")
    
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)
    
    let tapID = AudioTapManager.createSystemAudioTap()
    let deviceID = AudioTapManager.createAggregateDevice()
    
    AudioTapManager.addTapToAggregateDevice(tapID: tapID, deviceID: deviceID)
    
    let recorder = AudioRecorder(deviceID: deviceID)
    recorder.startRecording()
    
    // Run until the run loop is stopped (by signal handler)
    while true {
        let result = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.1, false)
        if result == CFRunLoopRunResult.stopped || result == CFRunLoopRunResult.finished {
            break
        }
    }

    MessageWriter.info("Shutting down...")
    recorder.stopRecording()
    AudioTapManager.destroyProcessTap(tapID)
    AudioTapManager.destroyAggregateDevice(deviceID)
}

run()