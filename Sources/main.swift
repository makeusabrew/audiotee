//

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

func run() {
    MessageWriter.info("Starting program...")
    
    let tapID = AudioTapManager.createSystemAudioTap()
    let deviceID = AudioTapManager.createAggregateDevice()
    
    AudioTapManager.addTapToAggregateDevice(tapID: tapID, deviceID: deviceID)
    // TODO
    //    signal(SIGINT, { _ -> })
    
    
    let recorder = AudioRecorder(deviceID: deviceID)
    recorder.startRecording()
    
    // Keep running until signal
    RunLoop.main.run()
    
}

run( )

