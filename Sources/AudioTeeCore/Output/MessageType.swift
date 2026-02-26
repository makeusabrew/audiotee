import Foundation

// Unified message types for all AudioTee output
public enum MessageType: String, Codable {
  // Stream lifecycle
  case metadata
  case streamStart = "stream_start"
  case streamStop = "stream_stop"

  // Logging
  case info
  case error
  case debug
}

// Base message envelope that wraps all outputs
public struct Message<T: Codable>: Codable {
  public let timestamp: Date
  public let type: MessageType
  public let data: T?

  public enum CodingKeys: String, CodingKey {
    case timestamp
    case type = "message_type"
    case data
  }

  public init(type: MessageType, data: T? = nil) {
    self.timestamp = Date()
    self.type = type
    self.data = data
  }
}

// Simple log data for logging messages
public struct LogData: Codable {
  public let message: String
  public let context: [String: String]?

  public init(message: String, context: [String: String]? = nil) {
    self.message = message
    self.context = context
  }
}
