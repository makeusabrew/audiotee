import XCTest
@testable import AudioTeeCore

final class AudioPacketTests: XCTestCase {
  func testPacketCreation() {
    let timestamp = Date()
    let duration = 1.0
    let data = Data([0x01, 0x02, 0x03, 0x04])
    
    let packet = AudioPacket(
      timestamp: timestamp,
      duration: duration,
      data: data
    )
    
    XCTAssertEqual(packet.timestamp, timestamp)
    XCTAssertEqual(packet.duration, duration)
    XCTAssertEqual(packet.data, data)
  }
  
  func testPacketDataSize() {
    let packet = AudioPacket(
      timestamp: Date(),
      duration: 0.5,
      data: Data(repeating: 0xFF, count: 1024)
    )
    
    XCTAssertEqual(packet.data.count, 1024)
  }
}