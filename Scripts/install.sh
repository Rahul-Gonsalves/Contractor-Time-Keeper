#!/bin/bash
# Build Timekeep and install it into /Applications so it behaves like any other
# Mac app: searchable in Spotlight, launchable from Launchpad, double-click to open.
# Usage: ./Scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Build the .app bundle (release).
"$ROOT/Scripts/bundle.sh" release

DEST="/Applications/Timekeep.app"
echo "▸ Installing to $DEST…"
rm -rf "$DEST"
cp -R "$ROOT/Timekeep.app" "$DEST"

# Belt-and-suspenders: strip any quarantine flag so Gatekeeper never prompts.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "✓ Installed. Launch it from Spotlight/Launchpad, or:"
echo "    open -a Timekeep"
