import CoreAudio

public enum TapMuteBehavior: String, CaseIterable {
  case unmuted = "unmuted"
  case muted = "muted"

  public var description: String {
    switch self {
    case .unmuted:
      return "Don't mute processes (default)"
    case .muted:
      return "Mute processes being tapped"
    }
  }

  public var coreAudioValue: CATapMuteBehavior {
    switch self {
    case .unmuted:
      return .unmuted
    case .muted:
      return .muted
    }
  }
}
