import AppKit
import Observation
import SwiftUI

// The menu bar item, in AppKit rather than SwiftUI's MenuBarExtra, which
// can't tell a right click from a left one. A left click toggles the panel,
// a borderless window under the robot hosting PanelView; a right click
// opens the menu. The robot is lit red while a window is nearly out.
@MainActor
final class StatusBarController: NSObject {
  private let store: UsageStore
  private let scheduler: Scheduler
  private let prefs: Preferences
  private let login = LoginItem()

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var panel: PanelWindow?
  private var hosting: NSHostingController<PanelView>?
  private var settingsWindow: NSWindow?
  private var monitors: [Any] = []
  private var sizeObservation: NSKeyValueObservation?
  private var iconTimer: Timer?

  init(store: UsageStore, scheduler: Scheduler, prefs: Preferences) {
    self.store = store
    self.scheduler = scheduler
    self.prefs = prefs
    super.init()

    if let button = statusItem.button {
      button.image = Icons.robot
      button.target = self
      button.action = #selector(clicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    observeAlarm()
    // Windows reset with time as well as with new records.
    iconTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.updateIcon() }
    }
  }

  // MARK: Icon

  private func observeAlarm() {
    withObservationTracking {
      updateIcon()
    } onChange: { [weak self] in
      Task { @MainActor in self?.observeAlarm() }
    }
  }

  private func updateIcon() {
    let alarming = Presentation.alarming(store.visible, now: Date())
    statusItem.button?.image = alarming ? Self.urgentRobot : Icons.robot
    statusItem.button?.setAccessibilityLabel(alarming ? "Agents: a limit is nearly used" : "Agents")
  }

  // Menu bar images draw as templates unless told otherwise, so the lit
  // robot is painted in the urgent color and marked as not a template.
  private static let urgentRobot: NSImage = {
    let base = Icons.robot
    let image = NSImage(size: base.size, flipped: false) { rect in
      base.draw(in: rect)
      NSColor.systemRed.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    image.isTemplate = false
    return image
  }()

  // MARK: Clicks

  @objc private func clicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
      showMenu()
    } else if panel?.isVisible == true {
      closePanel()
    } else {
      showPanel()
    }
  }

  private func showMenu() {
    closePanel()
    let menu = NSMenu()
    menu.addItem(item("Refresh", key: "r", action: #selector(refresh)))
    menu.addItem(item("Settings…", key: ",", action: #selector(openSettings)))
    if login.available {
      menu.addItem(.separator())
      login.refresh()
      let open = item("Open at Login", key: "", action: #selector(toggleLogin))
      open.state = login.enabled ? .on : .off
      menu.addItem(open)
    }
    menu.addItem(.separator())
    menu.addItem(item("Quit Agents", key: "q", action: #selector(quit)))
    // The standard way to drop a menu from a status item on demand.
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  private func item(_ title: String, key: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }

  @objc private func refresh() { scheduler.refresh() }
  @objc private func toggleLogin() { login.set(!login.enabled) }
  @objc private func quit() { NSApp.terminate(nil) }

  // MARK: Panel

  private func showPanel() {
    let panel = self.panel ?? makePanel()
    position(panel)
    panel.makeKeyAndOrderFront(nil)
    statusItem.button?.highlight(true)
    // Opening the panel wants the numbers that go stale on the wire, not
    // another walk over every transcript on disk.
    scheduler.refreshLimits()

    // A click anywhere else, in any app, closes it, as a menu would.
    if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
      MainActor.assumeIsolated { self?.closePanel() }
    }) {
      monitors.append(outside)
    }
  }

  private func closePanel() {
    guard let panel, panel.isVisible else { return }
    panel.orderOut(nil)
    statusItem.button?.highlight(false)
    monitors.forEach(NSEvent.removeMonitor)
    monitors = []
  }

  private func makePanel() -> PanelWindow {
    let view = PanelView(store: store, scheduler: scheduler, openSettings: { [weak self] in self?.openSettings() })
    let hosting = NSHostingController(rootView: view)
    hosting.sizingOptions = [.preferredContentSize]
    let panel = PanelWindow(content: hosting.view)
    panel.onCancel = { [weak self] in self?.closePanel() }
    // The panel follows its content's height, keeping its top under the robot.
    sizeObservation = hosting.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
      MainActor.assumeIsolated {
        guard let self, let panel = self.panel, panel.isVisible else { return }
        self.position(panel)
      }
    }
    self.hosting = hosting
    self.panel = panel
    return panel
  }

  // Under the robot, centred on it, kept on screen.
  private func position(_ panel: PanelWindow) {
    guard let button = statusItem.button, let buttonWindow = button.window, let hosting else { return }
    var size = hosting.preferredContentSize
    if size.width == 0 || size.height == 0 { size = hosting.view.fittingSize }
    let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
    var x = anchor.midX - size.width / 2
    x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
    let y = anchor.minY - 6 - size.height
    panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
  }

  // MARK: Settings

  @objc private func openSettings() {
    closePanel()
    if settingsWindow == nil {
      let view = SettingsView(prefs: prefs, store: store, scheduler: scheduler, login: login)
      let hosting = NSHostingController(rootView: view)
      hosting.sizingOptions = [.preferredContentSize]
      let window = NSWindow(contentViewController: hosting)
      window.title = "Agents Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }
}

// The panel's window: borderless, translucent like a popover, with rounded
// corners. It takes key so its controls and Esc work, without activating
// the app or taking focus from the one in front.
final class PanelWindow: NSPanel {
  var onCancel: (() -> Void)?

  init(content: NSView) {
    super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    isFloatingPanel = true
    level = .popUpMenu
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

    let effect = NSVisualEffectView()
    effect.material = .popover
    effect.blendingMode = .behindWindow
    effect.state = .active
    effect.wantsLayer = true
    effect.layer?.cornerRadius = 10
    effect.layer?.masksToBounds = true
    contentView = effect

    content.translatesAutoresizingMaskIntoConstraints = false
    effect.addSubview(content)
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
      content.topAnchor.constraint(equalTo: effect.topAnchor),
      content.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
    ])
  }

  override var canBecomeKey: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }
}
