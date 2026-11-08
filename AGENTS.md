# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

A native macOS menu bar app (SwiftUI `MenuBarExtra`, macOS 14+) that ports Omarchy's `omarchy.agents` panel: rate limits, reset times, and token stats for AI coding subscriptions. The upstream plugin lives at `~/Work/99.misc/omarchy/shell/plugins/agents` (QML panel), with its collectors at `~/Work/99.misc/omarchy/bin/omarchy-agent-usage-*`. The record format is `omarchy/docs/agent-usage-collectors.md`. The first release covers Claude Code, Codex, and Cursor.

## Commands

The project builds with Apple's Command Line Tools only (no Xcode).

```sh
swift build                       # debug build
swift run                         # run from source (no Dock icon)
scripts/build-app.sh              # release build → dist/Agents.app, ad-hoc signed
scripts/build-app.sh --install    # and copy it to ~/Applications
scripts/sync-upstream.sh [omarchy-checkout]   # re-copy collectors + SVG marks from Omarchy
scripts/make-icon.sh              # regenerate Icon/AppIcon.icns (robot on a tile); build-app.sh bundles it

# Run one collector by itself (prints its JSON record)
/usr/bin/python3 Sources/Agents/Resources/macos/run_collector.py claude --force | jq

# Render the panel to a PNG without running collectors (the only way to check UI without screen access)
.build/debug/Agents --snapshot /path/out.png [--dark]
AGENTS_USAGE_DIR=/dir/with/sample/records .build/debug/Agents --snapshot /path/out.png

# App logs
log show --predicate 'subsystem == "Agents"' --last 10m --style compact
```

There is no test target. Verify collector changes by running `run_collector.py`, and UI changes with `--snapshot`. When swapping a running instance, kill it by pid, then `open dist/Agents.app`.

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
  - `Scheduler.providers` is the list of collectors run, and also the panel's sort order.
- `Model/UsageStore.swift` watches the usage dir (`DispatchSource`) and decodes records with `Model/Record.swift`, which is deliberately lenient: every field is optional or defaulted. `visible` applies upstream's `providerHasData`.
- `Model/Presentation.swift` is the SwiftUI-free port of `Panel.qml`'s logic:
  - limit windows, with expired ones reset to 0;
  - model-scoped windows ("X Weekly"/"X Monthly") attached to their parent window;
  - statuses and usage notes, the alarm rule (≥ 90%, or balance ≤ 10%);
  - the rotating summary phrases, `friendlyModelName`, and token formatting.
  Port further `Panel.qml` behavior here, not in views.
- `Theme.swift` and `UI/` are the view layer. It follows **Control Center style** rather than Omarchy's look: a card per provider, 13/11 pt system text, and accent-colored meters that turn red at ≥ 90%. Model-scoped allowances show as labelled sub-rows under their window, not as Omarchy's unlabelled ticks.
- `Paths.swift` holds every location. `AGENTS_USAGE_DIR` overrides the records dir for development.

## Gotchas

- **No `@State`**: on the Command Line Tools SDK, SwiftUI's macro plugin is missing and `@State` doesn't build. Use `@StateObject` with a small `ObservableObject` (see `HoverState`, `PhraseRotator`). `@Observable` does work, because `ObservationMacros` ships with the toolchain.
- The package uses **Swift 5 language mode** (`swift-tools-version:5.9`): regex literals need the `#/…/#` form.
- **Never put a `TimelineView` (or anything that re-renders on its own) in the `MenuBarExtra` label**: it re-lays out the status button in a loop and starves the main actor, so the scheduler never runs. `StatusItemIcon` recomputes only when the records change.
- **Panel sizing**: the window takes the content's ideal height. Don't wrap the content in `ViewThatFits` or a fixed-height `ScrollView`, or the window grows to that frame. `PanelView` measures the content and switches to a `ScrollView` only past `Theme.maxPanelHeight`.
- **`--snapshot` uses `ImageRenderer`**: it can't draw AppKit-backed controls (`ScrollView`, `ProgressView`, `.borderless` buttons, checkboxes), which come out blank or as a yellow 🚫 placeholder. That's why meters are drawn shapes, not `ProgressView`. Tooltips (`.help`) and the real material background aren't visible in snapshots either.
- **Icons**: in the panel each mark sits on a white app-icon tile (`ProviderMark`), always using the dark-ink `-light.svg` variant. `Icons.substitutes` swaps a mark that doesn't hold up at 24 pt for another asset: Codex shows `assets/openai.svg` (OpenAI's mark from LobeHub's MIT icon set, added by this port, so `sync-upstream.sh` leaves it alone). `NSImage` reads the SVG marks natively. `Icons.image(named:)` scales marks with tiny declared sizes (Codex's `1em`) up to a 64 pt working size. The menu bar robot (`assets/robot.svg`, the Omarchy bar glyph U+F16A3, regenerated with `scripts/extract-glyph.swift`, which needs a Nerd Font) is then pinned to 16 pt high as a template image.
- `SwiftPM` resources live in `Sources/Agents/Resources` (copied as `Bundle.module`). `build-app.sh` places `Agents_Agents.bundle` in `Contents/Resources`, where the generated accessor looks first.

## Adding a provider

Add its id to `PROVIDERS` in `scripts/sync-upstream.sh` and re-sync, then add it to `Scheduler.providers`. Run the collector by itself, and add any macOS path or Keychain differences to `macos_shim.py`. An `assets/<id>.svg` mark is optional; the robot stands in for a missing one.
