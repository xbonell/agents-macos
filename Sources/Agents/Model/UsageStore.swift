import Foundation
import Observation
import os

private let log = Logger(subsystem: "Agents", category: "store")

// The display side's view of the usage directory, as Main.qml and Agent.qml
// keep it: every *.json there is an agent, whoever wrote it. The directory is
// watched, and the updater also reloads after each run, since an atomic mv
// replaces files underneath any watch.
@MainActor
@Observable
final class UsageStore {
  private(set) var records: [UsageRecord] = []
  private(set) var revision = 0

  // The agents worth a section: Main.qml's enabledProviders, switched on in
  // settings and with numbers to show.
  var visible: [UsageRecord] { records.filter { $0.hasData && prefs.isEnabled($0.id) } }

  @ObservationIgnored private let prefs: Preferences
  @ObservationIgnored private var texts: [String: Data] = [:]
  @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
  @ObservationIgnored var onChange: (() -> Void)?

  init(prefs: Preferences) {
    self.prefs = prefs
    try? FileManager.default.createDirectory(at: Paths.usageDir, withIntermediateDirectories: true)
    reload()
    watch()
  }

  func reload() {
    let files = (try? FileManager.default.contentsOfDirectory(
      at: Paths.usageDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? []

    var next: [UsageRecord] = []
    var nextTexts: [String: Data] = [:]
    for file in files where file.pathExtension == "json" {
      let id = file.deletingPathExtension().lastPathComponent
      guard let data = try? Data(contentsOf: file) else { continue }
      // Same text, same record: no need to hand listeners an identical one.
      if data == texts[id], let kept = records.first(where: { $0.id == id }) {
        next.append(kept)
        nextTexts[id] = data
        continue
      }
      do {
        var record = try JSONDecoder().decode(UsageRecord.self, from: data)
        if record.id.isEmpty { record.id = id }
        next.append(record)
        nextTexts[id] = data
      } catch {
        log.warning("Ignoring bad usage record \(file.path, privacy: .public)")
      }
    }
    next.sort { $0.id < $1.id }
    texts = nextTexts
    guard next != records else { return }
    records = next
    revision += 1
    onChange?()
  }

  private func watch() {
    let fd = open(Paths.usageDir.path, O_EVTONLY)
    guard fd >= 0 else { return }
    let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.reload() }
    }
    source.setCancelHandler { close(fd) }
    source.resume()
    watcher = source
  }
}
