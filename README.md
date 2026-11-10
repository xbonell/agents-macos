# Agents for macOS

A native macOS menu bar port of [Omarchy](https://github.com/omacom/omarchy)'s
`omarchy.agents` panel: one robot in the menu bar, and a panel with each AI
subscription's rate limits, reset times, and what your token counts add up
to: Claude Code, Codex, Cursor, Grok Bot (included with Cursor and metered
apart from it; the card appears when your account has an allowance),
OpenCode (its own Zen/Go service), and every other provider Omarchy collects:
Antigravity (Google's Gemini plan), GitHub Copilot, DeepSeek, Devin,
Fireworks, Grok, Hermes, Kimchi, Kimi, local models, MiniMax, Muse, Ollama
Cloud, OpenRouter, Qwen Code, Synthetic, Mistral Vibe, and Z.ai. A card
appears only once its provider has something to show.

<p align="center">
  <img src="docs/panel.png#gh-light-mode-only" width="320" alt="The panel: cards for Claude Code, Codex, Cursor, Grok Bot, and OpenCode, each with its limits">
  <img src="docs/panel-dark.png#gh-dark-mode-only" width="320" alt="The panel in dark mode">
</p>

<sub>Drawn from made-up records (`scripts/make-samples.py`).</sub>

Prefer the terminal, or on Linux? [agents-tui](https://github.com/xbonell/agents-tui) is the same panel as a TUI, and it can display this app's records instead of collecting again.

## How it works

The Omarchy plugin is split into collectors (Python) that write one JSON
record per agent, and a panel that only draws those records. This port keeps
that split:

- **Collectors** are Omarchy's own, vendored unmodified in
  `Sources/Agents/Resources/collectors/` (`collectors.py` plus
  `omarchy-agent-usage-<id>` for each provider). Their record format is
  Omarchy's `docs/agent-usage-collectors.md`.
- **`Resources/macos/run_collector.py`** runs one of them on macOS:
  it points `OMARCHY_PATH`, `XDG_STATE_HOME` and `XDG_CACHE_HOME` at the app's
  folders, gives the system Python 3.9 the vendored `tomli` as `tomllib`, and
  applies `macos_shim.py`, which reads Claude Code's, cursor-agent's and
  Antigravity's sign-ins from the Keychain (read only) and Cursor's editor
  database from `~/Library/Application Support`. Collectors also get your
  login shell's environment, so an API key exported in your shell profile
  (`OPENROUTER_API_KEY`, `DEEPSEEK_API_KEY`, `ZAI_API_KEY`…) reaches them.
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
  which providers to collect and show. Every provider is on by default; ones
  not detected yet sit in a collapsed group and appear by themselves once used. Open at Login is offered only when
  running as `Agents.app`.
- **Sign In…** appears next to "Sign-in required" and opens your terminal
  running that CLI's login (`claude auth login`, `codex login`,
  `cursor-agent login` for both Cursor and Grok Bot, `opencode auth login`,
  `gh auth login` for Copilot, `devin auth login`, `grok login`, `kimi login`,
  `muse login`).
- The robot turns **red** while any limit is at 90% or more, and a
  **notification** says so once per window (switch it off in Settings).
  Clicking the notification opens the panel.

Collector cache: `~/Library/Caches/Agents`. App logs:
`log show --predicate 'subsystem == "Agents"' --last 1h`.

## Privacy

- Credentials are only ever read, never written or refreshed: Claude Code's,
  cursor-agent's and Antigravity's tokens from the Keychain (macOS may ask
  once to allow it), API keys from your shell's environment, the others from
  each agent's own files, and the Cursor editor's sign-in from its database.
- Each token goes only to its own provider: Claude Code's to
  `api.anthropic.com`, Cursor's (also used for Grok Bot) to `api2.cursor.sh`,
  OpenCode's to `opencode.ai`, and so on for the others (see Omarchy's
  `shell/plugins/agents/README.md` for each one's endpoint). Codex's limits
  come from the `codex` CLI itself. The app makes no network requests of its
  own.
- The records the panel draws stay on your Mac, in
  `~/Library/Application Support/Agents`. There's no telemetry or analytics.

## Sharing it

There's no Developer ID signature, so the easiest way for someone else to run
it is to build it themselves; an app built on their own Mac isn't quarantined
and opens without a Gatekeeper prompt:

```sh
git clone https://github.com/xbonell/agents-macos.git && cd agents-macos
scripts/build-app.sh --install
```

To send a built copy instead, zip it so the signature survives
(`ditto -c -k --keepParent dist/Agents.app Agents.zip`). macOS blocks it the
first time it's opened: allow it under System Settings › Privacy & Security ›
Open Anyway, or run `xattr -dr com.apple.quarantine /Applications/Agents.app`.

Either way it needs macOS 14 or later on Apple silicon (the build is arm64
only), Apple's Command Line Tools for `/usr/bin/python3`, and each agent's CLI
signed in; macOS may ask once to allow Keychain access for the Claude and
Cursor tokens.

## Development

```sh
# Run one collector on its own
/usr/bin/python3 Sources/Agents/Resources/macos/run_collector.py claude --force | jq

# Draw the panel into a PNG without running collectors
.build/debug/Agents --snapshot panel.png [--dark]

# Made-up records for every provider, for UI work without signing in anywhere
scripts/make-samples.py /tmp/agents-samples
AGENTS_USAGE_DIR=/tmp/agents-samples .build/debug/Agents --snapshot panel.png
```

The README's screenshots are `--snapshot`s of those samples, rendered with
`-AppleLocale en_US`.

`@State` is avoided: on the Command Line Tools, SwiftUI's macro plugin is
missing and `@State` doesn't build. View-local state uses `@StateObject`.

## Updating from Omarchy

Omarchy's collectors change often, and this port carries copies of them. To
take upstream fixes:

1. `scripts/check-upstream.sh --fetch` fetches your Omarchy checkout (clone
   [omacom/omarchy](https://github.com/omacom/omarchy) anywhere and pass its
   path or set `OMARCHY_CHECKOUT`; the default is `~/Work/99.misc/omarchy`)
   and lists which vendored files
   differ from its tracked branch, plus the upstream commits that touched them
   since the last sync. It never changes the checkout's files. Without
   `--fetch` it compares with the checkout's files as they are; `--ref <ref>`
   compares with any ref (`upstream/master` if your checkout is a fork).
2. Update the checkout itself (`git pull`), then `scripts/sync-upstream.sh`
   copies the files over and records the revision.
3. `swift build`, run each collector with `run_collector.py … --force | jq`
   and look for errors or a changed record, draw a `--snapshot`, then
   `scripts/build-app.sh --install`.

A change that breaks on macOS gets its fix in `macos/macos_shim.py`, never in
the vendored files.

## Not ported yet

Other providers (each needs its id in `PROVIDERS` in `scripts/upstream.sh`, a
sync, its id in `Scheduler.providers`, and any shim it needs), multiple accounts and
autoswitch, the add-subscription sign-in flow, starter prompts, reordering,
and cross-device sync.

## Contributing

Issues and pull requests are welcome; [CONTRIBUTING.md](CONTRIBUTING.md) has
the ground rules, and [AGENTS.md](AGENTS.md) explains how it's put together.

## License

MIT, see [LICENSE](LICENSE), which also credits Omarchy (the collectors and
the design this ports), LobeHub Icons (the OpenAI mark), and tomli.
