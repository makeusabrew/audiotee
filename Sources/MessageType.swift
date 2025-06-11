import Foundation

// Unified message types for all AudioTee output
enum MessageType: String, Codable {
  // Stream lifecycle
  case metadata
  case streamStart = "stream_start"
  case streamStop = "stream_stop"

  // Audio data
  case audio

  // Logging
  case info
  case error
  case debug
}

// Base message envelope that wraps all outputs
struct Message<T: Codable>: Codable {
  let timestamp: Date
  let type: MessageType
  let data: T?

  enum CodingKeys: String, CodingKey {
    case timestamp
    case type = "message_type"
    case data
  }

  init(type: MessageType, data: T? = nil) {
    self.timestamp = Date()
    self.type = type
    self.data = data
  }
}

// Simple log data for logging messages
struct LogData: Codable {
  let message: String
  let context: [String: String]?
}
