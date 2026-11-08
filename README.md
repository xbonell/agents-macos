# Agents for macOS

A native macOS menu bar port of Omarchy's `omarchy.agents` panel: one robot
in the menu bar, and a panel with each AI subscription's rate limits, reset
times, and what your token counts add up to: Claude Code, Codex, Cursor, and
OpenCode (its own Zen/Go service; the card appears once you use it).

## How it works

The Omarchy plugin is split into collectors (Python) that write one JSON
record per agent, and a panel that only draws those records. This port keeps
that split:

- **Collectors** are Omarchy's own, vendored unmodified in
  `Sources/Agents/Resources/collectors/` (`collectors.py` plus
  `omarchy-agent-usage-{claude,codex,cursor,opencode}`). Their record format is
  Omarchy's `docs/agent-usage-collectors.md`.
- **`Resources/macos/run_collector.py`** runs one of them on macOS:
  it points `OMARCHY_PATH`, `XDG_STATE_HOME` and `XDG_CACHE_HOME` at the app's
  folders, gives the system Python 3.9 the vendored `tomli` as `tomllib`, and
  applies `macos_shim.py`, which reads Claude Code's and cursor-agent's
  tokens from the Keychain (read only) and Cursor's editor database from
  `~/Library/Application Support`.
- **The app** (an AppKit menu bar item with a SwiftUI panel) runs the collectors with
  `/usr/bin/python3`, writes each record atomically to
  `~/Library/Application Support/Agents/omarchy/agents/usage/`, watches that
  folder, and draws the panel. Refresh timings are Omarchy's: every 15
  minutes, a limits-only refresh when the panel opens, a forced one from the
  refresh button, and a 30-second retry for an agent whose endpoint couldn't
  be reached.

The panel's logic (`Model/Presentation.swift`: windows, model-scoped ticks,
statuses, the rotating summary line) is ported from `Panel.qml`; its look
follows Control Center (`Theme.swift`, `UI/`): a card per provider, system
text sizes, and accent-colored meters that turn red near a limit. The marks
are Omarchy's SVGs, and the menu bar robot is its bar glyph (U+F16A3)
extracted to `assets/robot.svg`.

## Requirements

- macOS 14 or later.
- Apple's Command Line Tools (`xcode-select --install`), for `swift` to build
  and `/usr/bin/python3` to run the collectors. Xcode isn't needed.

## Build and run

```sh
swift run                       # run from source (no Dock icon)
scripts/build-app.sh            # build dist/Agents.app (ad-hoc signed)
scripts/build-app.sh --install  # and copy it to ~/Applications
```

## Using it

- **Click** the robot for the panel: a card per provider with its limits, and
  in the footer how long ago the numbers were updated.
- **Right-click** it (or Control-click) for Refresh, Settings…, Open at Login,
  and Quit. The gear in the panel's footer has Settings… and Quit too.
- **Settings** sets how often to refresh (5 minutes to 1 hour; default 15) and
  which providers to collect and show. Open at Login is offered only when
  running as `Agents.app`.
- **Sign In…** appears next to "Sign-in required" and opens your terminal
  running that CLI's login (`claude auth login`, `codex login`,
  `cursor-agent login`).
- The robot turns **red** while any limit is at 90% or more, and a
  **notification** says so once per window (switch it off in Settings).
  Clicking the notification opens the panel.

Collector cache: `~/Library/Caches/Agents`. App logs:
`log show --predicate 'subsystem == "Agents"' --last 1h`.

## Development

```sh
# Run one collector on its own
/usr/bin/python3 Sources/Agents/Resources/macos/run_collector.py claude --force | jq

# Draw the panel into a PNG without running collectors
.build/debug/Agents --snapshot panel.png [--dark]

# Point the panel at other records (sample data)
AGENTS_USAGE_DIR=/path/to/records .build/debug/Agents --snapshot panel.png

# Pull collector and mark updates from an Omarchy checkout
scripts/sync-upstream.sh ~/Work/99.misc/omarchy
```

`@State` is avoided: on the Command Line Tools, SwiftUI's macro plugin is
missing and `@State` doesn't build. View-local state uses `@StateObject`.

## Not ported yet

Other providers (each needs its collector copied in `sync-upstream.sh`, its id
in `Scheduler.providers`, and any shim it needs), multiple accounts and
autoswitch, the add-subscription sign-in flow, starter prompts, reordering,
and cross-device sync.
