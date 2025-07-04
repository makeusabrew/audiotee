import CoreFoundation
import Foundation

/// Handles audio recording permissions for the CLI, including checking status and requesting permissions.
/// Uses exit codes to communicate permission status:
/// - 0: granted (authorized)
/// - 1: unknown
/// - 2: denied
struct PermissionsHandler {
  private let shouldRequest: Bool

  init(shouldRequest: Bool) {
    self.shouldRequest = shouldRequest
  }

  /// Handles the permissions workflow and exits with appropriate exit code
  func handle() -> Never {
    let permissionHandler = AudioRecordingPermission()

    if shouldRequest {
      print("Requesting audio recording permissions...")
      permissionHandler.request()

      // Wait for the permission request to complete
      while permissionHandler.status == .unknown {
        // Run the main run loop to allow DispatchQueue.main.async to execute
        let result = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.1, true)
        if result == CFRunLoopRunResult.stopped || result == CFRunLoopRunResult.finished {
          break
        }
      }
    }

    // Get final status and exit with appropriate code
    let status = permissionHandler.status
    print("Audio recording permission status: \(status.rawValue)")

    switch status {
    case .authorized:
      exit(0)  // granted
    case .unknown:
      exit(1)  // unknown
    case .denied:
      exit(2)  // denied
    }
  }
}
