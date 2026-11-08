import SwiftUI

// The settings Omarchy's manifest offers — how often to refresh and which
// providers to show — plus Open at Login, in a standard grouped form.
struct SettingsView: View {
  @Bindable var prefs: Preferences
  let store: UsageStore
  let scheduler: Scheduler
  let notifier: LimitNotifier
  @ObservedObject var login: LoginItem

  private static let intervals = [300, 600, 900, 1800, 3600]
  private static let names = ["claude": "Claude Code", "codex": "Codex", "cursor": "Cursor", "opencode": "OpenCode"]

  var body: some View {
    Form {
      Section("General") {
        Picker("Refresh every", selection: $prefs.refreshIntervalSec) {
          ForEach(Self.intervals, id: \.self) { seconds in
            Text(Self.intervalLabel(seconds)).tag(seconds)
          }
          // A value set with `defaults write` stays selectable.
          if !Self.intervals.contains(prefs.refreshIntervalSec) {
            Text(Self.intervalLabel(prefs.refreshIntervalSec)).tag(prefs.refreshIntervalSec)
          }
        }
        if LimitNotifier.available {
          Toggle("Notify when a limit reaches 90%", isOn: $prefs.notifyNearLimit)
          if prefs.notifyNearLimit && notifier.denied {
            Text("Notifications are off for Agents in System Settings › Notifications.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        if login.available {
          Toggle("Open at Login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
          if login.needsApproval {
            Text("Allow Agents in System Settings › General › Login Items.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      Section {
        ForEach(Scheduler.providers, id: \.self) { id in
          Toggle(isOn: enabled(id)) {
            HStack(spacing: 8) {
              ProviderMark(id: id, size: 20)
              Text(name(of: id))
            }
          }
        }
      } header: {
        Text("Providers")
      } footer: {
        Text("A provider that's off isn't collected or shown.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 400)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      login.refresh()
      notifier.refreshPermission()
    }
  }

  // Switching a provider back on collects it right away.
  private func enabled(_ id: String) -> Binding<Bool> {
    Binding(
      get: { prefs.isEnabled(id) },
      set: { on in
        prefs.setEnabled(id, on)
        if on { scheduler.run(.limits, only: [id]) }
      }
    )
  }

  private func name(of id: String) -> String {
    store.records.first { $0.id == id }?.name ?? Self.names[id] ?? id
  }

  private static func intervalLabel(_ seconds: Int) -> String {
    if seconds % 3600 == 0 { return seconds == 3600 ? "1 hour" : "\(seconds / 3600) hours" }
    if seconds % 60 == 0 { return seconds == 60 ? "1 minute" : "\(seconds / 60) minutes" }
    return "\(seconds) seconds"
  }
}
