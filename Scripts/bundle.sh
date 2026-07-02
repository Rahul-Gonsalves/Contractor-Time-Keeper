#!/bin/bash
# Build Timekeep and wrap the executable into a double-clickable Timekeep.app bundle.
# Usage: ./Scripts/bundle.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/Timekeep"
APP="$ROOT/Timekeep.app"
CONTENTS="$APP/Contents"

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Timekeep"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>Timekeep</string>
    <key>CFBundleDisplayName</key>       <string>Timekeep</string>
    <key>CFBundleIdentifier</key>        <string>io.countercode.timekeep</string>
    <key>CFBundleVersion</key>           <string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleExecutable</key>        <string>Timekeep</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>NSPrincipalClass</key>          <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will launch it locally without Gatekeeper complaints.
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "✓ Built $APP"
echo "  Run with: open \"$APP\"   (or double-click it in Finder)"
