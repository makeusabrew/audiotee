//
//  AudioStreamMetadata.swift
//  t2
//
//  Created by Nick Payne on 11/06/2025.
//

import Foundation

struct AudioStreamMetadata: Codable {
  let sampleRate: Double
  let channelsPerFrame: UInt32
  let bitsPerChannel: UInt32
  let isFloat: Bool
  let captureMode: String
  let deviceName: String?
  let deviceUID: String?
  let encoding: String

  enum CodingKeys: String, CodingKey {
    case sampleRate = "sample_rate"
    case channelsPerFrame = "channels_per_frame"
    case bitsPerChannel = "bits_per_channel"
    case isFloat = "is_float"
    case captureMode = "capture_mode"
    case deviceName = "device_name"
    case deviceUID = "device_uid"
    case encoding
  }
}
