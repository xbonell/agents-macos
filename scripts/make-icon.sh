#!/bin/bash
# Regenerates Icon/AppIcon.icns from the robot mark; build-app.sh copies it
# into the app. Run after changing scripts/make-icon.swift or robot.svg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/make-icon.swift" "$ROOT/Sources/Agents/Resources/assets/robot.svg" "$WORK/icon_1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$ROOT/Icon"
iconutil -c icns "$ICONSET" -o "$ROOT/Icon/AppIcon.icns"
cp "$WORK/icon_1024.png" "$ROOT/Icon/AppIcon.png"
echo "Wrote $ROOT/Icon/AppIcon.icns"
