# Pattern Management — Design Spec
**Date:** 2026-05-20  
**Project:** CrochetApp (macOS)  
**Scope:** Pattern library sidebar + per-pattern counter persistence

---

## Problem

Every launch requires re-browsing to the pattern file. Counters are global — switching patterns loses your place.

---

## Solution

A persistent pattern library (left sidebar) paired with per-pattern counter state. Selecting a pattern restores its saved row/stitch counts. The counter bar moves from a separate sidebar column to a sticky bar at the top of the markdown viewer pane, keeping it always visible while scrolling.

---

## Layout

Two-column `NavigationSplitView`:

- **Column 1 — Pattern Library** (min 200pt, ideal 220pt)
  - Header: "Patterns" label + "+" button to add a pattern via file picker
  - Two sections: **Pinned** and **Recent**
  - Each row: filename, last-opened date, saved R/S badge (e.g. "R12 · S4")
  - Active pattern highlighted with a pink left-border accent
  - Right-click context menu: Pin/Unpin, Remove from Library
  - Empty state: "No patterns yet — click + to open one"

- **Column 2 — Content Pane** (fills remaining space)
  - **Sticky counter bar** pinned to top (never scrolls away):
    - Row counter: `−` | label + count | `+` (pill card, pink)
    - Stitch counter: `−` | label + count | `+` (pill card, purple)
    - Auto-reset stitch toggle (compact, labelled)
    - Reset button (destructive, requires confirmation)
    - Keyboard shortcut hint: `↑↓ row · ←→ stitch`
  - **Scrollable markdown viewer** below the bar (existing `MarkdownWebView`, unchanged)

---

## Data Model

### `PatternEntry`
```swift
struct PatternEntry: Codable, Identifiable {
    let id: UUID
    var displayName: String        // derived from filename
    var bookmark: Data             // security-scoped bookmark for sandbox persistence
    var lastOpened: Date
    var isPinned: Bool
    var rowCount: Int
    var stitchCount: Int
    var autoResetStitch: Bool
}
```

### `PatternLibrary`
- `ObservableObject` with `@Published var entries: [PatternEntry]`
- Persists to `~/Library/Application Support/CrochetApp/patterns.json`
- On add: resolves bookmark from URL, creates entry, saves
- On select: saves current counter state to previous entry, loads new entry's state into `CounterStore`
- Sections derived via computed properties: `pinned` and `recent` (last 20, sorted by `lastOpened`)

---

## Counter State Flow

1. User selects pattern in library → `PatternLibrary.select(entry:)` called
2. Current counter state flushed to previously active entry (if any)
3. New entry's `rowCount`, `stitchCount`, `autoResetStitch` loaded into `CounterStore`
4. `CounterStore` publishes changes → counter bar updates instantly
5. Every counter increment/decrement also writes back to the active `PatternEntry` in memory (persisted to disk on next selection or app quit)

---

## Files Changed

| File | Change |
|------|--------|
| `PatternLibrary.swift` | New — library model + persistence |
| `PatternEntry.swift` | New — Codable entry model |
| `PatternLibraryView.swift` | New — sidebar list view |
| `CounterBarView.swift` | New — compact sticky counter bar |
| `CounterStore.swift` | Refactor — remove UserDefaults counter keys; delegate to PatternLibrary |
| `ContentView.swift` | Refactor — 2-column split, wire library + counter bar |
| `CounterView.swift` | Remove — replaced by `CounterBarView` |
| `CrochetAppApp.swift` | Minor — inject `PatternLibrary` as environment object |

---

## Error Handling

- Stale bookmarks (file moved/deleted): show inline error in library row; offer "Locate file…" to re-resolve
- JSON decode failure on launch: start with empty library, log error (no crash)
- File read errors in markdown pane: existing error state in `MarkdownView` already handles this

---

## Out of Scope

- iCloud sync
- Pattern tags or search
- Custom counter names
- Notes/annotations per pattern
