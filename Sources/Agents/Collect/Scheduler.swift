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
  static let providers = ["claude", "codex", "cursor"]

  private(set) var running = false
  // Checked before every update, so installing the tools later recovers.
  private(set) var pythonMissing = false

  @ObservationIgnored private let store: UsageStore
  @ObservationIgnored private var pending: UpdateKind?
  @ObservationIgnored private var timerTask: Task<Void, Never>?
  @ObservationIgnored private var retryTask: Task<Void, Never>?
  @ObservationIgnored private var retryIds: [String] = []

  // Omarchy's refreshIntervalSec setting: 900 by default, never under 30.
  var refreshInterval: TimeInterval {
    let configured = UserDefaults.standard.integer(forKey: "refreshIntervalSec")
    return TimeInterval(max(30, configured == 0 ? 900 : configured))
  }

  init(store: UsageStore) {
    self.store = store
    store.onChange = { [weak self] in self?.scheduleLimitsRetry() }
    scheduleLimitsRetry()
    startTimer()
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
        await CollectorRunner.update(ids ?? Self.providers, kind: kind)
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

  private func startTimer() {
    timerTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let near = self.nearLimit
        self.run(near ? .limits : .normal)
        let interval = near ? min(180, self.refreshInterval) : self.refreshInterval
        try? await Task.sleep(for: .seconds(interval))
      }
    }
  }

  // Only the advising agents rerun, so an outage at one provider doesn't put
  // every collector on a 30-second treadmill.
  private func scheduleLimitsRetry() {
    let advising = store.records.filter(\.retryAdvised).map(\.id).filter(Self.providers.contains)
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
