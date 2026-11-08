import AppKit
import Observation
import os
import UserNotifications

private let log = Logger(subsystem: "Agents", category: "notify")

// Posts a notification when a window reaches 90% (Presentation.
// notificationsDue decides what's due). What's been sent is kept in
// UserDefaults, so a relaunch doesn't repeat it, and tracked even while the
// setting is off, so switching it on doesn't post a burst of old news.
@MainActor
@Observable
final class LimitNotifier: NSObject, UNUserNotificationCenterDelegate {
  // Shown in Settings when the user has turned Agents' notifications off.
  private(set) var denied = false

  @ObservationIgnored private let store: UsageStore
  @ObservationIgnored private let prefs: Preferences
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let onOpen: () -> Void
  @ObservationIgnored private var sent: Set<String>

  private static let sentKey = "notifiedLimits"

  // UNUserNotificationCenter needs a bundled app; `swift run` gets none.
  static var available: Bool { Bundle.main.bundleURL.pathExtension == "app" }

  init(store: UsageStore, prefs: Preferences, defaults: UserDefaults = .standard, onOpen: @escaping () -> Void) {
    self.store = store
    self.prefs = prefs
    self.defaults = defaults
    self.onOpen = onOpen
    // On a first launch, whatever is already at the line counts as sent.
    if let stored = defaults.stringArray(forKey: Self.sentKey) {
      sent = Set(stored)
    } else {
      sent = Presentation.notificationsDue(store.visible, now: Date(), sent: []).sent
      defaults.set(sent.sorted(), forKey: Self.sentKey)
    }
    super.init()

    guard Self.available else { return }
    UNUserNotificationCenter.current().delegate = self
    prefs.onNotifyChange = { [weak self] in
      guard let self, self.prefs.notifyNearLimit else { return }
      self.requestPermission()
    }
    if prefs.notifyNearLimit { requestPermission() }
    observe()
  }

  func refreshPermission() {
    guard Self.available else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let denied = settings.authorizationStatus == .denied
      // What macOS will do with a notification, for when one doesn't show.
      log.notice("Notification settings: authorization \(settings.authorizationStatus.rawValue), alertStyle \(settings.alertStyle.rawValue), alerts \(settings.alertSetting.rawValue), notificationCenter \(settings.notificationCenterSetting.rawValue), sound \(settings.soundSetting.rawValue)")
      Task { @MainActor in self.denied = denied }
    }
  }

  private func requestPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
      if let error { log.error("Notification permission failed: \(error.localizedDescription, privacy: .public)") }
      Task { @MainActor in self.refreshPermission() }
    }
  }

  private func observe() {
    withObservationTracking {
      evaluate()
    } onChange: { [weak self] in
      Task { @MainActor in self?.observe() }
    }
  }

  private func evaluate() {
    let due = Presentation.notificationsDue(store.visible, now: Date(), sent: sent)
    if due.sent != sent {
      sent = due.sent
      defaults.set(sent.sorted(), forKey: Self.sentKey)
    }
    guard prefs.notifyNearLimit else { return }
    for alert in due.alerts { post(alert) }
  }

  private func post(_ alert: Presentation.LimitAlert) {
    let content = UNMutableNotificationContent()
    content.title = alert.title
    content.body = alert.body
    content.sound = .default
    let request = UNNotificationRequest(identifier: alert.key, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      guard let error else { return }
      log.error("Notification failed: \(error.localizedDescription, privacy: .public)")
      // Not delivered (no permission yet, say), so not sent: the next
      // refresh tries again.
      Task { @MainActor in
        self.sent.remove(alert.key)
        self.defaults.set(self.sent.sorted(), forKey: Self.sentKey)
      }
    }
    log.notice("Notified: \(alert.title, privacy: .public) — \(alert.body, privacy: .public)")
  }

  // Clicking a notification opens the panel.
  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Task { @MainActor in self.onOpen() }
    completionHandler()
  }

  // Shown as a banner even when Agents counts as the frontmost app.
  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  // `Agents --notify-dry-run`: prints what would be sent for the records on
  // disk (AGENTS_USAGE_DIR for samples) and remembers it in a separate
  // defaults domain, so a second run shows the once-per-reset rule.
  static func dryRun(store: UsageStore) {
    let defaults = UserDefaults(suiteName: "com.xbonell.agents.dryrun")!
    let sent = Set(defaults.stringArray(forKey: sentKey) ?? [])
    let due = Presentation.notificationsDue(store.visible, now: Date(), sent: sent)
    for alert in due.alerts { print("\(alert.title)\(alert.body.isEmpty ? "" : " — \(alert.body)")") }
    if due.alerts.isEmpty { print("(nothing to send)") }
    defaults.set(due.sent.sorted(), forKey: sentKey)
  }
}
