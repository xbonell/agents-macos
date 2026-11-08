#!/bin/bash
# Re-copy the collectors and marks this port uses from an Omarchy checkout.
# The vendored files are never edited; macOS differences live in
# Sources/Agents/Resources/macos/macos_shim.py.
set -euo pipefail

UPSTREAM="${1:-$HOME/Work/99.misc/omarchy}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)/Sources/Agents"
PROVIDERS=(claude codex cursor)

vendor="$ROOT/Resources/collectors"
mkdir -p "$vendor/bin" "$vendor/shell/plugins/agents" "$ROOT/Resources/assets"

cp "$UPSTREAM/shell/plugins/agents/collectors.py" "$vendor/shell/plugins/agents/"
for id in "${PROVIDERS[@]}"; do
  cp "$UPSTREAM/bin/omarchy-agent-usage-$id" "$vendor/bin/"
  for mark in "$id.svg" "$id-light.svg"; do
    [[ -f $UPSTREAM/shell/plugins/agents/assets/$mark ]] && cp "$UPSTREAM/shell/plugins/agents/assets/$mark" "$ROOT/Resources/assets/"
  done
done

(cd "$UPSTREAM" && git rev-parse HEAD 2>/dev/null || echo unknown) >"$vendor/UPSTREAM_REVISION"
echo "Synced ${PROVIDERS[*]} from $UPSTREAM"
