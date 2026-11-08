import Foundation
import os
import ServiceManagement

private let log = Logger(subsystem: "Agents", category: "login")

// Open at login, through the system's own login items. Only a bundled
// Agents.app can register; `swift run` has nothing to register.
final class LoginItem: ObservableObject {
  @Published private(set) var status = SMAppService.mainApp.status

  var available: Bool { Bundle.main.bundleURL.pathExtension == "app" }
  var enabled: Bool { status == .enabled || status == .requiresApproval }
  var needsApproval: Bool { status == .requiresApproval }

  func set(_ on: Bool) {
    do {
      if on {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      log.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
    }
    status = SMAppService.mainApp.status
  }

  func refresh() {
    status = SMAppService.mainApp.status
  }
}
