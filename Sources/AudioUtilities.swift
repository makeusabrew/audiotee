//
//  AudioUtilities.swift
//  t2
//
//  Created by Nick Payne on 11/06/2025.
//


import AudioToolbox
import CoreAudio
import Foundation

// TODO: can this just be a func?

class AudioUtilities {
  static func getPropertyAddress(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
  ) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
  }
}
