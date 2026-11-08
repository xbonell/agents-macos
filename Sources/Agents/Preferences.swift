import Foundation
import Observation

// The settings Omarchy's manifest offers: the refresh interval and which
// providers are switched on. Stored in UserDefaults (the app's domain,
// com.xbonell.agents when bundled), so `defaults write` works as well.
@MainActor
@Observable
final class Preferences {
  static let intervalRange = 30...3600

  private enum Key {
    static let refreshIntervalSec = "refreshIntervalSec"
    static let disabledProviders = "disabledProviders"
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored var onIntervalChange: (() -> Void)?

  // Omarchy's refreshIntervalSec: 900 by default, 30…3600.
  var refreshIntervalSec: Int {
    didSet {
      let clamped = min(max(refreshIntervalSec, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
      if clamped != refreshIntervalSec { refreshIntervalSec = clamped; return }
      defaults.set(refreshIntervalSec, forKey: Key.refreshIntervalSec)
      if refreshIntervalSec != oldValue { onIntervalChange?() }
    }
  }

  // Omarchy's providers.<id>.enabled, kept as the ids switched off so a new
  // provider starts on.
  var disabledProviders: Set<String> {
    didSet { defaults.set(disabledProviders.sorted(), forKey: Key.disabledProviders) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.integer(forKey: Key.refreshIntervalSec)
    refreshIntervalSec = stored == 0 ? 900 : min(max(stored, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
    disabledProviders = Set(defaults.stringArray(forKey: Key.disabledProviders) ?? [])
  }

  func isEnabled(_ id: String) -> Bool { !disabledProviders.contains(id) }

  func setEnabled(_ id: String, _ on: Bool) {
    if on { disabledProviders.remove(id) } else { disabledProviders.insert(id) }
  }
}
