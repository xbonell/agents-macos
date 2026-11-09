# Contributing

Thanks for helping. This is a small port of Omarchy's agents panel, so most
of the rules below are about keeping it close to upstream. For how the app is
put together, read [AGENTS.md](AGENTS.md) first; it's written for coding
agents, but it's the architecture guide for people too.

## Setup

- macOS 14 or later, and Apple's Command Line Tools
  (`xcode-select --install`). Xcode isn't needed, and the project must keep
  building without it.
- `swift build`, then `swift run` to try it from source, or
  `scripts/build-app.sh` for `dist/Agents.app`.
- No AI subscriptions needed for UI work: `scripts/make-samples.py <dir>`
  writes made-up records for every provider, and
  `AGENTS_USAGE_DIR=<dir> .build/debug/Agents --snapshot panel.png [--dark]`
  draws the panel from them.

## Where a fix goes

- **Never edit `Sources/Agents/Resources/collectors/`.** Those are Omarchy's
  files, vendored unmodified, and `scripts/sync-upstream.sh` overwrites them.
  - A collector bug that also happens on Omarchy belongs upstream, in
    [omacom/omarchy](https://github.com/omacom/omarchy). It comes back here
    with the next sync.
  - A difference that only matters on macOS (a path, a Keychain item) goes in
    `Sources/Agents/Resources/macos/macos_shim.py`.
- Panel logic (what a window shows, statuses, the alarm and notification
  rules) goes in `Model/Presentation.swift`, ported from Omarchy's
  `Panel.qml` where it can be. Views only lay it out.
- A new provider has to exist upstream first. Then follow "Adding a
  provider" in [AGENTS.md](AGENTS.md#adding-a-provider).

## Checking a change

There's no test target, so say in the pull request how you checked it:

- **Collectors and the shim:**
  `/usr/bin/python3 Sources/Agents/Resources/macos/run_collector.py <id> --force | jq`,
  and look for errors or a changed record.
- **UI:** attach `--snapshot`s, light and `--dark`. `--snapshot` can't draw
  AppKit-backed controls (see [AGENTS.md](AGENTS.md#gotchas)), so check
  those in the real app.
- **Notifications:** `AGENTS_USAGE_DIR=<dir> .build/debug/Agents --notify-dry-run`.
- Then `scripts/build-app.sh` and use the app for a bit. Don't `swift run`
  with `AGENTS_USAGE_DIR` pointing at samples: the app runs the real
  collectors and overwrites them.
- If the change is visible in the README's screenshots, re-render
  `docs/panel.png` and `docs/panel-dark.png` from `make-samples.py`'s records
  with `-AppleLocale en_US`.

## Toolchain gotchas

The Command Line Tools SDK is missing a few things Xcode has; AGENTS.md's
[Gotchas](AGENTS.md#gotchas) has the details. The ones that bite first:

- `@State` doesn't build. Use `@StateObject` with a small `ObservableObject`.
- The package is in Swift 5 language mode, so regex literals need `#/…/#`.
- Don't move the menu bar item to `MenuBarExtra`.

## Style

- Match the code around you: its naming, its idiom, and how much it
  comments. Comments say why, not what.
- One change per pull request.
- Commit messages have a short imperative subject ("Add the Grok Bot
  provider") and, when there's more to say, a body wrapped at 72 columns
  that explains why. `git log` has plenty of examples.
- If the change affects what AGENTS.md or the README describe, update them in
  the same pull request.

## Reporting issues

Include your macOS version, which providers you use, what you expected, and
what happened. Logs help:

```sh
log show --predicate 'subsystem == "Agents"' --last 30m --style compact
```

**Before pasting logs or a collector's JSON, read through them** and remove
anything that identifies you: access tokens, account emails, organization
names.

## Security

This app reads credentials, so please report anything that could leak or
misuse them privately, through
[GitHub's private vulnerability reporting](https://github.com/xbonell/agents-macos/security/advisories/new),
not in a public issue.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
