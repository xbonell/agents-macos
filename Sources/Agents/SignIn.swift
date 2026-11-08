import AppKit
import os

private let log = Logger(subsystem: "Agents", category: "signin")

// Signs an agent's CLI in again in the user's terminal. The command is
// written to a .command file and opened, so it runs in whichever terminal
// opens those (Terminal by default) without asking for Apple Events access.
enum SignIn {
  static func run(_ id: String) {
    guard let command = Presentation.signInCommands[id] else { return }
    let dir = Paths.cacheHome
    let script = dir.appendingPathComponent("signin-\(id).command")
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try "#!/bin/zsh -l\n\(command)\n".write(to: script, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    } catch {
      log.error("Could not write \(script.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
      return
    }
    NSWorkspace.shared.open(script)
  }
}
