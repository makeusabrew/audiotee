import Foundation

public struct AudioPacket {
  public let timestamp: Date
  public let duration: Double
  public let data: Data

  public init(
    timestamp: Date,
    duration: Double,
    data: Data
  ) {
    self.timestamp = timestamp
    self.duration = duration
    self.data = data
  }
}
