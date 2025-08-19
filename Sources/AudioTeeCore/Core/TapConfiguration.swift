public struct TapConfiguration {
  public let processes: [Int32]
  public let muteBehavior: TapMuteBehavior
  public let isExclusive: Bool
  public let isMono: Bool

  public init(processes: [Int32], muteBehavior: TapMuteBehavior, isExclusive: Bool, isMono: Bool) {
    self.processes = processes
    self.muteBehavior = muteBehavior
    self.isExclusive = isExclusive
    self.isMono = isMono
  }
}
