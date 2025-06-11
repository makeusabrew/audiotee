//
//  AudioPacket.swift
//  t2
//
//  Created by Nick Payne on 11/06/2025.
//

import Foundation

public struct AudioPacket: Codable {
  let timestamp: Date
  let duration: Double
  let peakAmplitude: Float
  let rmsAmplitude: Float
  let zeroCrossings: Int
  let dcOffset: Float
  let clippingRatio: Float  // percentage of samples near max amplitude
  let audioData: String  // base64 encoded audio data

  enum CodingKeys: String, CodingKey {
    case timestamp
    case duration
    case peakAmplitude = "peak_amplitude"
    case rmsAmplitude = "rms_amplitude"
    case zeroCrossings = "zero_crossings"
    case dcOffset = "dc_offset"
    case clippingRatio = "clipping_ratio"
    case audioData = "audio_data"
  }
}
