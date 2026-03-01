import Foundation

// MARK: - Logging protocol

/// Protocol that library consumers implement to receive log output.
/// The library never writes to stderr directly — it calls through this.
public protocol AudioTeeLogger {
  func debug(_ message: String, context: [String: String]?)
  func info(_ message: String, context: [String: String]?)
  func error(_ message: String, context: [String: String]?)

  /// Called for structured lifecycle messages (metadata, stream_start, stream_stop).
  /// Default implementation is a no-op — pure library consumers get metadata
  /// via AudioOutputHandler instead.
  func writeMessage<T: Codable>(_ type: MessageType, data: T?)
}

// MARK: - Defaults

extension AudioTeeLogger {
  /// Library consumers typically don't need structured message output;
  /// they receive metadata via the AudioOutputHandler protocol instead.
  public func writeMessage<T: Codable>(_ type: MessageType, data: T?) {}

  /// Convenience overloads so callers can omit context when it's nil.
  public func debug(_ message: String) { debug(message, context: nil) }
  public func info(_ message: String) { info(message, context: nil) }
  public func error(_ message: String) { error(message, context: nil) }
}

// MARK: - Global logging configuration

/// Global logger instance. Defaults to StderrJSONLogger (CLI behavior).
/// Library consumers can replace this before calling any AudioTeeCore API.
///
///     // Silence all logging:
///     AudioTeeLogging.logger = NullLogger()
///
///     // Custom logging:
///     AudioTeeLogging.logger = MyOSLogLogger()
///
public enum AudioTeeLogging {
  nonisolated(unsafe) public static var logger: AudioTeeLogger = StderrJSONLogger()
}
