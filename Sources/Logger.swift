import Foundation

class Logger {
  nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime,
      .withFractionalSeconds,
    ]
    return formatter
  }()

  private static let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(dateFormatter.string(from: date))
    }
    return encoder
  }()

  // Write any message with the unified envelope
  static func writeMessage<T: Codable>(_ type: MessageType, data: T? = nil) {
    let message = Message(type: type, data: data)
    do {
      let jsonData = try jsonEncoder.encode(message)
      FileHandle.standardOutput.write(jsonData)
      FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    } catch {
      // TODO: handle at some point
    }
  }

  // Convenience methods for different message types
  static func info(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.info, data: logData)
  }

  static func error(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.error, data: logData)
  }

  static func debug(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.debug, data: logData)
  }

  // Send stream metadata
  static func metadata(_ metadata: AudioStreamMetadata) {
    writeMessage(.metadata, data: metadata)
  }

  // Send stream start signal
  static func streamStart() {
    writeMessage(.streamStart, data: Optional<String>.none)
  }

  // Send stream stop signal
  static func streamStop() {
    writeMessage(.streamStop, data: Optional<String>.none)
  }

  // Send audio packet
  static func audio(_ packet: AudioPacket) {
    writeMessage(.audio, data: packet)
  }
}
