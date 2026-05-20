# Pattern Enhancements — Design Spec
**Date:** 2026-05-20
**Project:** CrochetApp (macOS)
**Scope:** Row goal + progress bar, inline pattern annotations, session timer, keyboard shortcuts

---

## Features

### 1. Row Goal + Optional Progress Bar

- `PatternEntry` gains an optional `rowGoal: Int?` field
- When `rowGoal` is nil, the progress bar is hidden entirely — no space reserved
- When set, a thin progress bar appears inline in the counter bar between the stitch counter and the timer: `"12 / 60 rows" [████░░░░░░]`
- Goal is set via a small popover: right-click (or long-press) the Row counter → "Set Row Goal…" → number field → confirm
- Clearing the field removes the goal and hides the bar
- Progress bar is pink, matches Row counter color

### 2. Inline Pattern Annotations

Notes are attached to paragraph-level blocks in the rendered markdown. Storage is a `[Int: String]` dictionary on `PatternEntry` keyed by paragraph index (0-based order of `<p>` and `<li>` blocks in the rendered HTML).

**Interaction:**
- **Double-click any paragraph/row** in the markdown viewer → an inline text input appears below that paragraph with an amber left rule (`border-left: 2px solid #e8b84b`)
- **Return** saves the note; **Escape** cancels without saving
- **Click an existing note** → the note text becomes editable in place; a plain "Delete" text link appears on the right
- **Return** saves edits; **Escape** cancels; clicking "Delete" removes the note
- Empty rows have zero visual chrome — no icons, no gutters, no indicators

**Rendering:**
- Notes render as indented italic grey text (`font-style: italic; color: #999; font-size: 11px`) below their paragraph
- Amber left rule (`border-left: 2px solid #e8b84b; padding-left: 10px`) is the only decoration
- Implemented via JavaScript injected into the WKWebView after the HTML loads: JS adds `dblclick` listeners to each block, tracks note state in a JS object, and calls a Swift `WKScriptMessageHandler` to save/load/delete notes

**Data flow:**
1. `MarkdownWebView` injects a JS bootstrap on page load that receives the note dictionary as JSON
2. JS renders existing notes and wires up interaction
3. On save/delete, JS posts a message: `{ action: "save"|"delete", index: Int, text: String }`
4. `WKScriptMessageHandler` in Swift receives the message and calls `PatternLibrary.updateNote(index:text:)` on the active entry

### 3. Session Timer

- A simple elapsed-time timer for the current crocheting session
- **Not** per-pattern — it's a session concept (resets on app relaunch, or manually)
- Lives in `SessionTimer` (an `ObservableObject`) owned by `CrochetAppApp`
- Displayed in the counter bar: `⏱ 0:42:17` (hours:minutes:seconds)
- Auto-starts when the app launches with a pattern open; pauses when app loses focus (optional, controlled by a user preference toggle in the counter bar)
- Controls: tap the timer display to pause/resume; right-click → "Reset Timer"
- Format: `h:mm:ss` when over an hour, `m:ss` when under

### 4. Keyboard Shortcuts

Extended shortcut map (all modifier-free, same pattern as existing):

| Key | Action |
|-----|--------|
| `Space` | Increment stitch (+1) |
| `↑` / `R` | Increment row (+1) |
| `↓` / `r` | Decrement row (−1) |
| `→` / `S` | Increment stitch (+1) |
| `←` / `s` | Decrement stitch (−1) |
| `Return` | Increment row (+1) and reset stitch to 0 (regardless of auto-reset setting) — "end of row" shortcut |

**Auto-advance on stitch goal:** When `stitchGoal` is set on the active `PatternEntry` and stitch count reaches `stitchGoal`, automatically trigger "increment row + reset stitch" (same as pressing Return). A brief haptic-style visual flash on the Row counter acknowledges the auto-advance.

`stitchGoal: Int?` is added to `PatternEntry` alongside `rowGoal`. Set via right-click on the Stitch counter → "Set Stitch Goal…".

---

## Data Model Changes (PatternEntry additions)

```swift
var rowGoal: Int?           // nil = no goal, no progress bar
var stitchGoal: Int?        // nil = no auto-advance
var annotations: [Int: String]  // paragraph index → note text
```

---

## Files Changed

| File | Change |
|------|--------|
| `PatternEntry.swift` | Add `rowGoal`, `stitchGoal`, `annotations` fields |
| `SessionTimer.swift` | New — simple elapsed timer ObservableObject |
| `CounterBarView.swift` | Add progress bar (conditional), timer display, goal popovers |
| `CounterStore.swift` | Add stitch-goal auto-advance logic |
| `MarkdownWebView.swift` | Inject annotation JS; add WKScriptMessageHandler |
| `AnnotationBridge.swift` | New — WKScriptMessageHandler that relays JS messages to PatternLibrary |
| `CrochetAppApp.swift` | Own SessionTimer, pass to CounterBarView |

---

## Out of Scope

- Persistent session history / total time logged per pattern
- Stitch goal progress bar (row goal bar is sufficient)
- Note formatting (bold, italic within notes)
- Syncing annotations across devices
