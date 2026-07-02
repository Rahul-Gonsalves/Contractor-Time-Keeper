# Handoff: Timekeep — Personal Time Tracker for a Contractor

## Overview
Timekeep is a single-user time tracker for a freelance contractor on macOS. The user logs hours against clients (client name + hours + optional note; date is captured automatically), views a per-day timeline, filters by client, and generates a plain-text monthly recap that can be copied into an email or exported as a `.txt` file.

**Your task: build this from start to finish as a native macOS app in Swift/SwiftUI**, targeting recent macOS. The bundled HTML file is a working, high-fidelity design reference — not code to ship. Recreate its look and behavior natively with SwiftUI's idioms (e.g. `NSVisualEffectView`/material backgrounds are optional; the flat dark palette below is the source of truth). If any behavior is ambiguous, the HTML prototype is the spec — open `Time Tracker.dc.html` in a browser (keep `support.js` next to it) and interact with it.

## About the Design Files
- `Time Tracker.dc.html` — the full working prototype (dark theme, all interactions, localStorage persistence). Design reference only.
- `support.js` — runtime the HTML file needs to render; irrelevant to the Swift build.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, and copy are final. Match them closely (translated sensibly to macOS: use SF Pro in place of Hanken Grotesk if you prefer platform-native type, and SF Mono in place of JetBrains Mono — but keep the size/weight hierarchy).

## Data Model
```swift
struct TimeEntry: Identifiable, Codable {
    let id: UUID
    var client: String     // canonical casing (see merge rules)
    var date: Date         // day precision; set automatically at creation
    var hours: Double      // 0.25 granularity encouraged, any positive value allowed
    var note: String       // optional, may be empty
}
```
Persistence: local only. SwiftData, Core Data, or a JSON file in Application Support are all acceptable — no sync, no accounts, no network.

## Core Behavior Rules
1. **Add entry**: requires non-empty client and hours > 0. Date is always "today" — the user never picks it at entry time.
2. **Client canonicalization**: match client names case-insensitively against existing clients; if a match exists, use the existing casing (typing "acme co" when "Acme Co" exists logs to "Acme Co").
3. **Same client + same day merge**: if an entry already exists for that client today, add the hours to it (do not create a second row) and join notes with `"; "`. After a merge, show a transient confirmation: `Merged into today's Acme Co entry — now 5h.` (auto-dismiss ~4s).
4. **Edit**: any past entry's hours and note can be edited inline. Hours must remain > 0 to save.
5. **Delete**: any entry can be deleted (a confirm is optional; the prototype deletes immediately).
6. **Client filter**: clicking a client in the Clients panel filters the timeline to that client; a pill above the timeline (`Acme Co · clear`) clears it. Clicking the active client again also clears.
7. **Hours formatting** everywhere: round to 2 decimals; drop trailing decimals for whole numbers; suffix `h` → `5h`, `2.5h`, `0.75h`.

## Monthly Recap (the key feature)
- Covers one **calendar month**, selected via a picker listing every month from the earliest entry to the current month (newest first), defaulting to the current month.
- Plain-text output, clients sorted by hours descending, **no notes**, exactly this format:

```
Time recap — July 2026

Acme Co — 42.5h
Beta LLC — 12h

Total — 54.5h
```

- Empty month: `Time recap — July 2026` + blank line + `No hours logged.`
- The em-dashes (`—`) are literal. Text is shown in a monospaced preview box.
- **Copy** button: puts the recap on the pasteboard; button label becomes `Copied!` on a green background for ~2s.
- **Export .txt** button: saves the recap as `recap-2026-07.txt` (native: NSSavePanel defaulting to that filename).

## Screens / Layout
One window, one screen. Three layout variants existed in the prototype; **build the default: "Clients right"** — a two-column grid, max content width 1160px centered, 20px gutters, 24–32px page padding.

### Header (full width, bottom border `#1D2632`)
- Left: app name **Timekeep** (20px / bold) + today's date, long form, e.g. `Wednesday, July 2, 2026` (13px, muted `#8C9AAC`).
- Right: label `This month` (13px muted) + current-month total hours (15px semibold, mono, accent `#7DA7F2`).

### Main column (left, flexible width)
**Card 1 — Log time**
- Section label `LOG TIME` (12px, semibold, 0.08em tracking, uppercase, `#8C9AAC`).
- 2-column form grid (client field 1fr, hours field 110px; note spans below client; Add button below hours). 10px gaps.
- Client field autocompletes from existing client names.
- Hours: numeric, step 0.25, min 0. Note: single line, placeholder `Note (optional)`.
- Inputs: bg `#0F1620`, border 1px `#26313F`, radius 9px, padding 11×13, 15px text.
- Add button: bg accent `#7DA7F2`, text `#0D1420`, bold, radius 9px. Hover: lighten to `#93B7F7`.
- Submit on Return.

**Card 2 — Entries (timeline)**
- Section label `ENTRIES`; active-filter pill on the right when filtering (accent-tinted pill, radius 999).
- Entries grouped by day, newest day first. Day header row: `Wed, Jul 2` (13px semibold `#AEB9C9`, year appended only if not current year) with the day's total hours right-aligned (12.5px mono, faint `#5C6B7E`); 1px underline `#1D2632`.
- Entry row (11px vertical padding, 1px separator `#171F2A`): client name (14.5px semibold) · note (13px muted, single line, ellipsized) · spacer · hours (14px mono `#CFD9E6`) · `Edit` / `Delete` text buttons (12.5px, faint; hover: Edit turns accent, Delete turns red `#F28B8B`, each with a soft tinted bg).
- Inline edit state replaces the row with: hours field (90px), note field (1fr), Save (accent) and Cancel (ghost) buttons.
- Empty state (no entries / no matches): centered muted text `No entries yet. Log your first hours above — the date is filled in automatically.`

### Side column (right, 380px)
**Card 3 — Clients**
- Section label `CLIENTS`. One row per client, sorted by current-month hours desc, then all-time desc.
- Row: name (14px semibold, ellipsized, 1fr) · month hours (13px mono, accent) · all-time (`123h all`, 11.5px mono, faint). Radius 9px, border 1px `#1D2632`, padding 10×12.
- Selected (filter active): bg `rgba(125,167,242,.14)`, border `rgba(125,167,242,.45)`. Hover: bg `rgba(125,167,242,.08)`.
- Empty state: `Clients appear here as you log time.`

**Card 4 — Monthly recap**
- Section label `MONTHLY RECAP` + month picker (compact select, input styling).
- Recap preview: monospaced block, 12.5px / 1.7 line-height, bg `#0F1620`, border `#1D2632`, radius 9px, padding 14×16, text `#CFD9E6`.
- Buttons row: `Copy recap` (primary, flexes to fill; becomes `Copied!` on green `#69D29A`) + `Export .txt` (ghost: transparent, 1px border `#26313F`; hover: accent text/border).

### Cards (all)
bg `#161D27`, border 1px `#232D3B`, radius 14px, padding 20px.

## Design Tokens
Colors (dark slate/blue-gray, single blue accent):
- Page background `#0E131A`
- Card `#161D27`, card border `#232D3B`
- Inset/input background `#0F1620`, input border `#26313F`, hairline `#1D2632`, row separator `#171F2A`
- Text primary `#E6ECF4`, secondary `#AEB9C9`, muted `#8C9AAC`, faint `#5C6B7E`, placeholder `#55647A`
- Accent blue `#7DA7F2` (hover `#93B7F7`), accent tint bgs at 8/12/14% alpha
- Success green `#69D29A`, danger red `#F28B8B`
- On-accent text `#0D1420`

Typography:
- UI: Hanken Grotesk (or SF Pro) — 20/700 app title; 15/400 inputs; 14–14.5/600 names; 13/400 secondary; 12/600 uppercase section labels (+0.08em tracking); 12.5 small actions.
- Numbers & recap: JetBrains Mono (or SF Mono) — 15/600 header total, 14 entry hours, 13 client month, 12.5 recap body, 11.5 all-time.

Spacing & shape: 20px card padding and grid gaps; radii 14 (cards), 9 (inputs/buttons), 7 (inline-edit controls), 999 (pills). No shadows — borders carry the elevation.

## State Management
- `entries: [TimeEntry]` — persisted locally.
- Form state: client / hours / note text; cleared after add.
- `filterClient: String?`
- `recapMonth` — defaults to current month.
- `editingEntryID: UUID?` + draft hours/note.
- Transient: merge-hint message (4s), copied flag (2s).

## macOS-Native Expectations (beyond the prototype)
- Menu bar app or regular window app — regular window is fine; a menu-bar quick-log extra is a welcome bonus, not required.
- Keyboard: Return submits the log form; Esc cancels inline edit.
- ⌘C-friendly: recap text selectable; Copy uses NSPasteboard.
- Standard window sizing; layout should adapt gracefully down to ~900px width (stack side column below main if narrower).

## Assets
None. No icons or images are used — the design is purely typographic. Do not add icons.

## Files
- `Time Tracker.dc.html` — interactive high-fidelity prototype (open in a browser with `support.js` alongside).
- `support.js` — prototype runtime only.
