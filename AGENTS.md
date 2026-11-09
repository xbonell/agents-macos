# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

A native macOS menu bar app (an AppKit `NSStatusItem` with SwiftUI views, macOS 14+) that ports Omarchy's `omarchy.agents` panel: rate limits, reset times, and token stats for AI coding subscriptions. Upstream is [omacom/omarchy](https://github.com/omacom/omarchy); the scripts find a local checkout at `$OMARCHY_CHECKOUT` (default `~/Work/99.misc/omarchy`). The plugin is its `shell/plugins/agents` (QML panel), with its collectors at `bin/omarchy-agent-usage-*`, and the record format is its `docs/agent-usage-collectors.md`. It covers Claude Code, Codex, Cursor, Grok Bot (metered apart from Cursor on the same account; hidden without an allowance), and OpenCode (Zen/Go; hidden until used).

## Commands

The project builds with Apple's Command Line Tools only (no Xcode).

```sh
swift build                       # debug build
swift run                         # run from source (no Dock icon)
scripts/build-app.sh              # release build → dist/Agents.app, ad-hoc signed
scripts/build-app.sh --install    # and copy it to ~/Applications
scripts/check-upstream.sh [--fetch] [--ref <ref>] [omarchy-checkout]   # vendored files vs Omarchy; exit 1 when out of date
scripts/sync-upstream.sh [omarchy-checkout]   # re-copy collectors + SVG marks from Omarchy
scripts/make-icon.sh              # regenerate Icon/AppIcon.icns (robot on a tile); build-app.sh bundles it

# Run one collector by itself (prints its JSON record)
/usr/bin/python3 Sources/Agents/Resources/macos/run_collector.py claude --force | jq

# Render the panel to a PNG without running collectors (the only way to check UI without screen access)
.build/debug/Agents --snapshot /path/out.png [--dark]
scripts/make-samples.py /dir      # made-up records for every provider, resets relative to now
AGENTS_USAGE_DIR=/dir .build/debug/Agents --snapshot /path/out.png [-AppleLocale en_US]

# Print the limit notifications the records would trigger (remembered in the
# com.xbonell.agents.dryrun defaults domain; `defaults delete` it to start over)
AGENTS_USAGE_DIR=/dir/with/sample/records .build/debug/Agents --notify-dry-run

# App logs
log show --predicate 'subsystem == "Agents"' --last 10m --style compact

# Settings (also in the Settings window; read at launch, so relaunch after defaults write)
defaults write com.xbonell.agents refreshIntervalSec -int 300      # 30…3600, default 900
defaults write com.xbonell.agents disabledProviders -array cursor  # providers switched off
defaults write com.xbonell.agents notifyNearLimit -bool false      # limit notifications
```

There is no test target. Verify collector changes by running `run_collector.py`, and UI changes with `--snapshot`. `docs/panel.png` and `docs/panel-dark.png` (the README's screenshots) are `--snapshot`s of `make-samples.py`'s records with `-AppleLocale en_US`; re-render them after a visible change. Don't run the app itself (`swift run`) with `AGENTS_USAGE_DIR` set to samples: its scheduler runs the real collectors and overwrites them. When swapping a running instance, kill it by pid, then `open dist/Agents.app`.

## Architecture

There are two halves, split the same way as upstream: Python collectors write one JSON record per agent, and the Swift app only displays those records.

**Collector side (Python, `Sources/Agents/Resources/`)**
- `collectors/` holds Omarchy's files, **vendored unmodified** (`collectors.py` plus `bin/omarchy-agent-usage-<id>`). Never edit them, because `sync-upstream.sh` overwrites them. Every macOS difference goes in `macos/macos_shim.py`.
- `macos/run_collector.py` is the only entry point:
  - It sets `OMARCHY_PATH` to the vendor dir, so the collectors' own `sys.path` insert resolves.
  - It points `XDG_STATE_HOME` and `XDG_CACHE_HOME` at `~/Library/Application Support/Agents` and `~/Library/Caches/Agents`.
  - It installs the vendored `macos/vendor/tomli` as `tomllib`, because the system Python is 3.9.6 and nothing else in the collectors needs a newer version.
  - It then imports `collectors`, applies the shim, and `runpy`s the collector script.
- The shim monkeypatches names on the `collectors` module **before** the collector script runs, so the script's `from collectors import …` picks up the patched versions. Current patches:
  - `read_json` falls back to the Keychain: `Claude Code-credentials` for `.credentials.json`, and `cursor-access-token` for cursor-agent's `auth.json`.
  - `cursor_state_db` points at `~/Library/Application Support/Cursor/...`.
  Credentials are only ever read, as the collector contract requires.
- Collectors must never write into the app bundle, or the signature breaks. `-I` and `sys.dont_write_bytecode` keep `__pycache__` out.

**App side (Swift, `Sources/Agents/`)**
- `Collect/CollectorRunner.swift` replaces upstream's bash `omarchy-agent-usage-update`, which needs bash 4:
  - It runs the collectors in parallel through `/usr/bin/python3 -I run_collector.py <id>`, with a 120 s kill.
  - It checks that stdout is a JSON object, then writes `<usageDir>/<id>.json` atomically (tmp file plus `rename`).
  - GUI apps get launchd's bare `PATH`, so `SearchPath` merges the login shell's `PATH` with the usual install folders. The collectors need `codex` and `rg`.
- `Collect/Scheduler.swift` ports `Main.qml`'s refresh logic:
  - A full refresh every `refreshIntervalSec` (default 900, triggered on start), and every 180 s near a limit for multi-account agents.
  - `--limits-only` when the panel opens, `--force` from the refresh button.
  - A 30 s limits retry, only for records with `retryAdvised`.
  - One update runs at a time; queued requests collapse into one, with `force` taking precedence.
  - `Scheduler.providers` is the list of collectors, and also the panel's sort order; providers switched off in `Preferences` aren't run.
- `Model/UsageStore.swift` watches the usage dir (`DispatchSource`) and decodes records with `Model/Record.swift`, which is deliberately lenient: every field is optional or defaulted. `visible` applies upstream's `providerHasData` and hides providers switched off in `Preferences`.
- `Model/Presentation.swift` is the SwiftUI-free port of `Panel.qml`'s logic:
  - limit windows, with expired ones reset to 0;
  - model-scoped windows ("X Weekly"/"X Monthly") attached to their parent window;
  - statuses and usage notes, the alarm rule (≥ 90%, or balance ≤ 10%), the footer's "Updated …" line;
  - `notificationsDue`, the notification rule: each window at 90% (and a balance at its last 10%) once per window per reset, keyed on the reset time rounded to the minute (Claude's moves in microseconds), staying sent above 85% so a figure hovering at the line doesn't repeat;
  - the sign-in command allow-list (`signInCommands`), the only commands `SignIn.swift` ever runs, via a `.command` file in `~/Library/Caches/Agents` opened in the default terminal;
  - the rotating summary phrases, `friendlyModelName`, and token formatting.
  Port further `Panel.qml` behavior here, not in views.
- `StatusBarController.swift` owns the menu bar item. It's AppKit because SwiftUI's `MenuBarExtra` can't tell right clicks from left:
  - Left click toggles `PanelWindow`, a borderless non-activating `NSPanel` (popover material, 10 pt corners) hosting `PanelView` through an `NSHostingController` with `.preferredContentSize`, positioned under the robot. A click outside (global monitor) or Esc closes it, and opening it runs a limits refresh.
  - Right click shows an `NSMenu` (Refresh, Settings…, Open at Login, Quit). The red alarm robot is a non-template image, re-evaluated through `withObservationTracking` on `store.visible` and once a minute.
  - It also owns the Settings window (`UI/SettingsView.swift`, a grouped `Form` in a plain `NSWindow`, not a SwiftUI `Settings` scene).
- `LimitNotifier.swift` posts `notificationsDue`'s alerts with `UNUserNotificationCenter`, re-evaluating through `withObservationTracking` on `store.visible`. What's been sent is kept in `UserDefaults` (`notifiedLimits`, seeded on first launch so nothing old fires) and tracked even while notifications are off. Clicking one opens the panel. It's inert unless bundled: `UNUserNotificationCenter` crashes under `swift run`.
- `Preferences.swift` is the `@Observable` settings model over `UserDefaults` (`refreshIntervalSec`, `disabledProviders`, `notifyNearLimit`). An interval change restarts the scheduler's wait without an extra run. `AgentsApp.swift` is an AppKit `@main` that builds preferences, store, scheduler and controller; `--snapshot` exits before any UI is created.
- `Theme.swift` and `UI/` are the view layer. It follows **Control Center style** rather than Omarchy's look: a card per provider, 13/11 pt system text, and accent-colored meters that turn red at ≥ 90%. Model-scoped allowances show as labelled sub-rows under their window, not as Omarchy's unlabelled ticks.
- `Paths.swift` holds every location. `AGENTS_USAGE_DIR` overrides the records dir for development.

## Gotchas

- **No `@State`**: on the Command Line Tools SDK, SwiftUI's macro plugin is missing and `@State` doesn't build. Use `@StateObject` with a small `ObservableObject` (see `HoverState`, `PhraseRotator`). `@Observable` does work, because `ObservationMacros` ships with the toolchain.
- The package uses **Swift 5 language mode** (`swift-tools-version:5.9`): regex literals need the `#/…/#` form.
- **Don't go back to `MenuBarExtra`**: besides lacking right clicks, a `TimelineView` in its label re-lays out the status button in a loop and starves the main actor, so the scheduler never runs.
- **Panel sizing**: the panel window follows the hosting controller's `preferredContentSize`, which is the content's ideal height. Don't wrap the content in `ViewThatFits` or a fixed-height `ScrollView`, or the window grows to that frame. `PanelView` measures the content and switches to a `ScrollView` only past `Theme.maxPanelHeight`.
- **A notification that doesn't show** is usually a Focus mode holding banners, not a bug: the `notify` log category records each post (`Notified: …`) and, at launch, the settings macOS reports for Agents (authorization, alert style, banners, Notification Center).
- `PanelView` stays alive between openings, so `.onAppear` fires once: put per-opening work in `StatusBarController.showPanel()`.
- **`--snapshot` uses `ImageRenderer`**: it can't draw AppKit-backed controls (`ScrollView`, `ProgressView`, `.borderless` buttons, checkboxes), which come out blank or as a yellow 🚫 placeholder. That's why meters are drawn shapes, not `ProgressView`, and why the footer's gear menu is a bare image when there's no scheduler (snapshot mode). Tooltips (`.help`) and the real material background aren't visible in snapshots either.
- **Icons**: in the panel each mark sits on a white app-icon tile (`ProviderMark`), always using the dark-ink `-light.svg` variant. `Icons.substitutes` swaps a mark that doesn't hold up at 24 pt for another asset: Codex shows `assets/openai.svg` (OpenAI's mark from LobeHub's MIT icon set, added by this port, so `sync-upstream.sh` leaves it alone). `NSImage` reads the SVG marks natively. `Icons.image(named:)` scales marks with tiny declared sizes (Codex's `1em`) up to a 64 pt working size. The menu bar robot (`assets/robot.svg`, the Omarchy bar glyph U+F16A3, regenerated with `scripts/extract-glyph.swift`, which needs a Nerd Font) is then pinned to 16 pt high as a template image.
- `SwiftPM` resources live in `Sources/Agents/Resources` (copied as `Bundle.module`). `build-app.sh` places `Agents_Agents.bundle` in `Contents/Resources`, where the generated accessor looks first.

## Adding a provider

Add its id to `PROVIDERS` in `scripts/upstream.sh` (shared by the sync and check scripts) and re-sync, then add it to `Scheduler.providers`. Run the collector by itself, and add any macOS path or Keychain differences to `macos_shim.py`. An `assets/<id>.svg` mark is optional; the robot stands in for a missing one. Add its display name to `SettingsView.names`, and its login command to `Presentation.signInCommands` if it has one.
