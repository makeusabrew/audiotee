import Foundation

public class Logger {
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
  public static func writeMessage<T: Codable>(_ type: MessageType, data: T? = nil) {
    let message = Message(type: type, data: data)
    do {
      let jsonData = try jsonEncoder.encode(message)
      FileHandle.standardError.write(jsonData)
      FileHandle.standardError.write("\n".data(using: .utf8)!)
    } catch {
      // TODO: handle at some point
    }
  }

  // Convenience methods for different message types
  public static func info(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.info, data: logData)
  }

  public static func error(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.error, data: logData)
  }

  public static func debug(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.debug, data: logData)
  }
}
