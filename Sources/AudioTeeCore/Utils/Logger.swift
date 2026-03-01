import Foundation

/// Default logger implementation that writes JSON messages to stderr.
/// This is the CLI-appropriate logger; library consumers can replace it
/// via AudioTeeLogging.logger.
public class StderrJSONLogger: AudioTeeLogger {
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime,
      .withFractionalSeconds,
    ]
    return formatter
  }()

  private let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    return encoder
  }()

  public init() {
    // Configured in init because stored property initializers can't
    // reference other instance properties (self.dateFormatter).
    jsonEncoder.dateEncodingStrategy = .custom { [dateFormatter] date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(dateFormatter.string(from: date))
    }
  }

  // Write any message with the unified envelope to stderr
  public func writeMessage<T: Codable>(_ type: MessageType, data: T?) {
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
  public func info(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.info, data: logData)
  }

  public func error(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.error, data: logData)
  }

  public func debug(_ message: String, context: [String: String]? = nil) {
    let logData = LogData(message: message, context: context)
    writeMessage(.debug, data: logData)
  }
}
