import Foundation

enum MessageType: String, Codable {
  // Audio-related messages
  case metadata
  case streamStart = "stream_start"
  case audio

  // Logging messages
  case info
  case error
  case debug
}

struct LogMessage: Codable {
  let timestamp: Date
  let type: MessageType
  let message: String
  let context: [String: String]?

  enum CodingKeys: String, CodingKey {
    case timestamp
    case type = "message_type"
    case message
    case context
  }
}

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

  // Write any Codable message to stdout
  static func writeMessage<T: Codable>(_ message: T) throws {
    let jsonData = try jsonEncoder.encode(message)
    FileHandle.standardOutput.write(jsonData)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
  }

  // Write a log message to stdout
  static func log(_ type: MessageType, _ message: String, context: [String: String]? = nil) {
    let logMessage = LogMessage(
      timestamp: Date(),
      type: type,
      message: message,
      context: context
    )

    do {
      try writeMessage(logMessage)
    } catch {
      // If JSON encoding fails, fall back to plain text on stderr
      FileHandle.standardError.write("Error encoding log message: \(error)\n".data(using: .utf8)!)
    }
  }

  // Convenience methods for different log levels
  static func info(_ message: String, context: [String: String]? = nil) {
    log(.info, message, context: context)
  }

  static func error(_ message: String, context: [String: String]? = nil) {
    // Write structured error to stdout
    log(.error, message, context: context)

    // Also write to stderr for traditional error handling
    FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
  }

  static func debug(_ message: String, context: [String: String]? = nil) {
    log(.debug, message, context: context)
  }
}
