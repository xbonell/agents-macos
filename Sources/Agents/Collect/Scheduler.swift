import Foundation
import Observation

// Main.qml's refresh section: a full update on a timer (triggered on start),
// a limits-only one when the panel opens, a forced one from the refresh
// button, and one sooner limits retry for agents whose endpoint couldn't be
// reached. Only one update runs at a time; requests made meanwhile collapse
// into one rerun, a forced refresh outranking the cheaper kinds.
@MainActor
@Observable
final class Scheduler {
  // The collectors this release ships.
  static let providers = ["claude", "codex", "cursor", "opencode"]

  private(set) var running = false
  // Checked before every update, so installing the tools later recovers.
  private(set) var pythonMissing = false

  @ObservationIgnored private let store: UsageStore
  @ObservationIgnored private let prefs: Preferences
  @ObservationIgnored private var pending: UpdateKind?
  @ObservationIgnored private var timerTask: Task<Void, Never>?
  @ObservationIgnored private var retryTask: Task<Void, Never>?
  @ObservationIgnored private var retryIds: [String] = []

  private var refreshInterval: TimeInterval { TimeInterval(prefs.refreshIntervalSec) }

  // Omarchy's --except: a provider switched off in settings isn't collected.
  private var enabledProviders: [String] { Self.providers.filter(prefs.isEnabled) }

  init(store: UsageStore, prefs: Preferences) {
    self.store = store
    self.prefs = prefs
    store.onChange = { [weak self] in self?.scheduleLimitsRetry() }
    // A new interval starts a new wait, without an extra run of its own.
    prefs.onIntervalChange = { [weak self] in self?.startTimer(runNow: false) }
    scheduleLimitsRetry()
    startTimer(runNow: true)
  }

  func refresh() { run(.force) }
  func refreshLimits() { run(.limits) }

  func run(_ kind: UpdateKind, only ids: [String]? = nil) {
    if running {
      pending = max(pending ?? kind, kind)
      return
    }
    running = true
    Task {
      pythonMissing = !(await CollectorRunner.pythonAvailable())
      if !pythonMissing {
        await CollectorRunner.update((ids ?? Self.providers).filter(prefs.isEnabled), kind: kind)
      }
      running = false
      store.reload()
      if let next = pending {
        pending = nil
        run(next)
      }
    }
  }

  // A fifteen-minute interval can't catch an account crossing its switch
  // threshold, so while an agent with several accounts has its active one
  // within 15 points of it, limits are checked every three minutes.
  private var nearLimit: Bool {
    store.records.contains { record in
      guard record.accounts.count >= 2 else { return false }
      let threshold = record.accountSwitch?.threshold ?? 95
      let from = min(0.8, (threshold - 15) / 100)
      return record.limits.contains { $0.percent >= from }
    }
  }

  private func startTimer(runNow: Bool) {
    timerTask?.cancel()
    timerTask = Task { [weak self] in
      var first = true
      while !Task.isCancelled {
        guard let self else { return }
        let near = self.nearLimit
        if !first || runNow { self.run(near ? .limits : .normal) }
        first = false
        let interval = near ? min(180, self.refreshInterval) : self.refreshInterval
        try? await Task.sleep(for: .seconds(interval))
      }
    }
  }

  // Only the advising agents rerun, so an outage at one provider doesn't put
  // every collector on a 30-second treadmill.
  private func scheduleLimitsRetry() {
    let advising = store.records.filter(\.retryAdvised).map(\.id).filter(enabledProviders.contains)
    retryIds = advising
    retryTask?.cancel()
    guard !advising.isEmpty else { return }
    retryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(30))
      guard !Task.isCancelled, let self else { return }
      self.run(.limits, only: self.retryIds)
    }
  }
}
