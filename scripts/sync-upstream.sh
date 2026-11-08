#!/bin/bash
# Re-copy the collectors and marks this port uses from an Omarchy checkout.
# The vendored files are never edited; macOS differences live in
# Sources/Agents/Resources/macos/macos_shim.py. Run check-upstream.sh first
# to see what would change.
set -euo pipefail

source "$(dirname "$0")/upstream.sh"
UPSTREAM="${1:-$UPSTREAM_DEFAULT}"
RESOURCES="$(cd "$(dirname "$0")/.." && pwd)/Sources/Agents/Resources"

while read -r from to; do
  # Not every provider ships a light mark, or a mark at all.
  [[ -f $UPSTREAM/$from ]] || continue
  mkdir -p "$(dirname "$RESOURCES/$to")"
  cp "$UPSTREAM/$from" "$RESOURCES/$to"
done < <(vendored_files)

(cd "$UPSTREAM" && git rev-parse HEAD 2>/dev/null || echo unknown) >"$RESOURCES/collectors/UPSTREAM_REVISION"
echo "Synced ${PROVIDERS[*]} from $UPSTREAM"
