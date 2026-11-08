import Foundation
import os

private let log = Logger(subsystem: "Agents", category: "collect")

enum UpdateKind: Int, Comparable {
  case normal, limits, force

  var flags: [String] {
    switch self {
    case .normal: return []
    case .limits: return ["--limits-only"]
    case .force: return ["--force"]
    }
  }

  static func < (a: UpdateKind, b: UpdateKind) -> Bool { a.rawValue < b.rawValue }
}

// omarchy-agent-usage-update's collect(), without bash 4: runs each collector
// through run_collector.py, checks it printed a JSON object, and moves the
// record into the usage directory atomically so a reader never sees half.
enum CollectorRunner {
  static let timeout: TimeInterval = 120

  // /usr/bin/python3 is only a stub until the Command Line Tools are in;
  // without them it fails (and macOS offers to install them).
  static func pythonAvailable() async -> Bool {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        let process = Process()
        process.executableURL = Paths.python
        process.arguments = ["-I", "-c", "import sqlite3, json"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
          continuation.resume(returning: false)
          return
        }
        process.waitUntilExit()
        continuation.resume(returning: process.terminationStatus == 0)
      }
    }
  }

  static func update(_ ids: [String], kind: UpdateKind) async {
    // Collectors run together share the Codex rollouts they read once, by
    // knowing when this refresh began.
    let refreshAt = String(format: "%.6f", Date().timeIntervalSince1970)
    await withTaskGroup(of: Void.self) { group in
      for id in ids {
        group.addTask { await collect(id, kind: kind, refreshAt: refreshAt) }
      }
    }
  }

  private static func collect(_ id: String, kind: UpdateKind, refreshAt: String) async {
    let output = await run(arguments: ["-I", Paths.runCollector.path, id] + kind.flags, refreshAt: refreshAt)
    guard let output, !output.stdout.isEmpty,
          (try? JSONSerialization.jsonObject(with: output.stdout)) is [String: Any] else {
      log.error("\(id, privacy: .public) collector failed: \(output?.stderr ?? "did not run", privacy: .public)")
      return
    }
    if !output.stderr.isEmpty {
      log.notice("\(id, privacy: .public): \(output.stderr, privacy: .public)")
    }
    write(output.stdout, for: id)
  }

  private static func write(_ record: Data, for id: String) {
    let dir = Paths.usageDir
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let tmp = dir.appendingPathComponent(".\(id).\(UUID().uuidString)")
    let target = dir.appendingPathComponent("\(id).json")
    do {
      try record.write(to: tmp)
      guard rename(tmp.path, target.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    } catch {
      try? FileManager.default.removeItem(at: tmp)
      log.error("Could not write \(target.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
  }

  private struct Output {
    var stdout: Data
    var stderr: String
  }

  private static func run(arguments: [String], refreshAt: String) async -> Output? {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        let process = Process()
        process.executableURL = Paths.python
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = SearchPath.value
        env["XDG_STATE_HOME"] = Paths.stateHome.path
        env["XDG_CACHE_HOME"] = Paths.cacheHome.path
        env["OMARCHY_AGENT_USAGE_REFRESH_AT"] = refreshAt
        process.environment = env

        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        // stderr drains on its own so neither pipe can fill and stall the child.
        let errData = LockedData()
        err.fileHandleForReading.readabilityHandler = { errData.append($0.availableData) }

        do {
          try process.run()
        } catch {
          err.fileHandleForReading.readabilityHandler = nil
          log.error("Could not start \(Paths.python.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
          continuation.resume(returning: nil)
          return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
          if process.isRunning { process.terminate() }
        }
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        err.fileHandleForReading.readabilityHandler = nil
        errData.append(err.fileHandleForReading.readDataToEndOfFile())

        let stderr = String(decoding: errData.value, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        continuation.resume(returning: process.terminationStatus == 0 ? Output(stdout: stdout, stderr: stderr) : Output(stdout: Data(), stderr: stderr))
      }
    }
  }
}

private final class LockedData: @unchecked Sendable {
  private var data = Data()
  private let lock = NSLock()

  func append(_ chunk: Data) {
    lock.lock(); data.append(chunk); lock.unlock()
  }

  var value: Data {
    lock.lock(); defer { lock.unlock() }
    return data
  }
}

// A menu bar app starts with launchd's bare PATH, which finds neither codex
// nor rg. Take the login shell's PATH once, and the usual install places.
enum SearchPath {
  static let value: String = {
    let home = Paths.home.path
    var parts = loginShellPath().split(separator: ":").map(String.init)
    parts += [
      "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
      "\(home)/.local/bin", "\(home)/.npm-global/bin", "\(home)/.bun/bin", "\(home)/.cargo/bin",
      // Node managers that only set PATH in interactive shells (an npm-installed codex).
      "\(home)/.local/share/fnm/aliases/default/bin", "\(home)/.volta/bin",
      "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ]
    var seen = Set<String>()
    return parts.filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: ":")
  }()

  private static func loginShellPath() -> String {
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-lc", "printf %s \"$PATH\""]
    process.standardInput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let out = Pipe()
    process.standardOutput = out
    guard (try? process.run()) != nil else { return "" }
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
      if process.isRunning { process.terminate() }
    }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : ""
  }
}
