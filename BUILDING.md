# Timekeep — Build & Run

A native macOS SwiftUI app built from the handoff spec in [`README.md`](README.md).
It's structured as a Swift Package so it builds and runs with the Command Line
Tools toolchain (no full Xcode required).

## Requirements
- macOS 13+ (Ventura or later)
- Swift 5.9+ (`swift --version`) — bundled with Xcode or the Command Line Tools

## Run in one step
```bash
./Scripts/bundle.sh          # builds release + assembles Timekeep.app
open Timekeep.app            # launch (or double-click it in Finder)
```

## Install like a normal Mac app
```bash
./Scripts/install.sh         # builds + copies to /Applications
```
After this, Timekeep shows up in Spotlight and Launchpad and opens with a
double-click — no Gatekeeper prompt, because a locally-built app carries no
download-quarantine flag. (A right-click ▸ Open is only ever needed if you
*download/transfer* the .app to a different Mac.) Fully warning-free
distribution to other machines would require signing + notarizing with a paid
Apple Developer account.

## Develop from the CLI
```bash
swift build                  # debug build
swift run Timekeep           # build & run
swift run Timekeep --selftest   # run the logic self-tests (merge, recap, persistence…)
```

## Open in Xcode (optional)
If you have full Xcode installed, just open the package directly:
```bash
xed .                        # or: File ▸ Open ▸ Package.swift
```

## Data & persistence
Entries are stored locally as JSON at:
```
~/Library/Application Support/Timekeep/entries.json
```
No accounts, no sync, no network.

## Project layout
```
Package.swift                 SwiftPM manifest (macOS 13, executable target)
Sources/Timekeep/
  TimekeepApp.swift           @main App entry + window config
  ContentView.swift           header + layout + the four cards
  Widgets.swift               EntryRow, ClientRowView, MonthPicker, buttons
  Components.swift            Card, SectionLabel, InsetField, HoverTextButton
  TimeEntry.swift             the Codable model
  TimeStore.swift             persistence + core behavior rules
  Formatting.swift            hours + date formatting helpers
  Theme.swift                 design tokens (colors, radii, fonts)
  SelfTest.swift              `--selftest` logic checks
Scripts/bundle.sh             wraps the binary into Timekeep.app
```
