#!/bin/bash
# Builds dist/Agents.app: a release build of the menu bar extra, its resource
# bundle (collectors, shim, marks) under Contents/Resources where Bundle.module
# looks first, an Info.plist with LSUIElement, and an ad-hoc signature.
#
#   scripts/build-app.sh            # build dist/Agents.app
#   scripts/build-app.sh --install  # and copy it to ~/Applications
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Agents.app"
VERSION="0.2.0"
BUNDLE_ID="com.xbonell.agents"

cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Agents" "$APP/Contents/MacOS/Agents"
cp -R "$BIN/Agents_Agents.bundle" "$APP/Contents/Resources/"
cp "$ROOT/Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat >"$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>Agents</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Agents</string>
  <key>CFBundleDisplayName</key><string>Agents</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Port of Omarchy's agents panel (MIT).</string>
</dict>
</plist>
EOF

# The nested resource bundle first, then the app around it.
codesign --force --sign - "$APP/Contents/Resources/Agents_Agents.bundle"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"

if [[ ${1:-} == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Agents.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed $HOME/Applications/Agents.app"
fi
