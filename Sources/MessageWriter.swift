import Foundation

class MessageWriter {
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
  static func writeMessage<T: Codable>(_ type: MessageType, data: T? = nil) throws {
    let message = Message(type: type, data: data)
    let jsonData = try jsonEncoder.encode(message)
    FileHandle.standardOutput.write(jsonData)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
  }

  // Convenience methods for different message types
  static func info(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    do {
      try writeMessage(.info, data: logData)
    } catch {
      fallbackError("Error encoding info message: \(error)")
    }
  }

  static func error(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    do {
      try writeMessage(.error, data: logData)
    } catch {
      fallbackError("Error encoding error message: \(error)")
    }

    // Also write to stderr for traditional error handling
    FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
  }

  static func debug(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    do {
      try writeMessage(.debug, data: logData)
    } catch {
      fallbackError("Error encoding debug message: \(error)")
    }
  }

  // Send stream metadata
  static func metadata(_ metadata: AudioStreamMetadata) {
    do {
      try writeMessage(.metadata, data: metadata)
    } catch {
      fallbackError("Error encoding metadata: \(error)")
    }
  }

  // Send stream start signal
  static func streamStart() {
    do {
      try writeMessage(.streamStart, data: Optional<String>.none)
    } catch {
      fallbackError("Error encoding stream start: \(error)")
    }
  }

  // Send stream stop signal
  static func streamStop() {
    do {
      try writeMessage(.streamStop, data: Optional<String>.none)
    } catch {
      fallbackError("Error encoding stream stop: \(error)")
    }
  }

  // Send audio packet
  static func audio(_ packet: AudioPacket) {
    do {
      try writeMessage(.audio, data: packet)
    } catch {
      fallbackError("Error encoding audio packet: \(error)")
    }
  }

  private static func fallbackError(_ message: String) {
    FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
  }
}
