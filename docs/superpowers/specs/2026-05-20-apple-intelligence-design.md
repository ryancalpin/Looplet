# Apple Intelligence Features — Design Spec
**Date:** 2026-05-20
**Project:** CrochetApp (macOS)
**Scope:** On-device AI features using Foundation Models framework + Writing Tools

---

## OS Requirement

All features in this spec require **macOS 15.1+** and an Apple Silicon Mac with Apple Intelligence enabled. All code is wrapped in `@available(macOS 15.1, *)` and gated at runtime with `if #available(macOS 15.1, *)`. On macOS 13/14, the AI panel simply does not appear.

---

## Architecture

A single `PatternAIService` class owns all Foundation Models interactions. It takes the raw markdown text of the open pattern as input and provides async methods for each feature. Results are cached in memory per-pattern (keyed by `PatternEntry.id`) so repeated calls don't re-run inference.

A new `AIPanel` view slides in from the right side of the content pane (like an inspector), toggled by a toolbar button (✦ or "AI" label). The panel is divided into sections — one per feature — that expand/collapse individually.

The pattern text is always passed as context to the model. For Q&A, the user's question is appended.

---

## Features

### 1. Summary Card
Auto-generates a structured summary of the open pattern. Displayed at the top of the AI panel when it opens.

**Fields extracted:**
- Pattern name
- Skill level (Beginner / Intermediate / Advanced)
- Materials (yarn weight, hook size, yardage)
- Total rows (if determinable)
- Estimated time (if row goal + rows-per-hour baseline is set)
- Key stitches used

**Trigger:** Runs automatically when the AI panel is opened and a pattern is loaded. Shows a spinner while generating. Result is cached until the pattern changes.

---

### 2. Abbreviation Explainer
Scans the pattern text and identifies all crochet abbreviations. Displays them as a clean list: `sc — single crochet`, `dc — double crochet`, etc.

Handles both US and UK conventions. If the pattern uses UK terms, notes this at the top of the list.

**Trigger:** "Abbreviations" section in AI panel, auto-populated when panel opens.

---

### 3. Pattern Q&A
A small text input at the bottom of the AI panel: "Ask anything about this pattern…"

The full pattern markdown is passed as context. The model answers in 1–3 sentences. Previous Q&A pairs are shown in a scrollable list above the input (in-memory only, not persisted).

**Examples:**
- "What stitch do I use in row 5?"
- "How many stitches should I have at the end of row 3?"
- "What does 'bobble' mean here?"

---

### 4. Materials Extractor
Parses and normalizes the materials list from the pattern. Displays as structured fields:

- Yarn: weight class, fiber (if mentioned), color (if mentioned), yardage
- Hook: size (mm and US letter)
- Notions: everything else (needles, markers, etc.)

Falls back gracefully if materials aren't clearly listed ("Could not detect a materials section").

---

### 5. Difficulty Estimator
Classifies the pattern as **Beginner**, **Intermediate**, or **Advanced** with a 1-sentence explanation.

Factors considered: stitch variety, row count, use of increases/decreases, joining, colorwork.

---

### 6. US ↔ UK Terminology Converter
Detects which convention the pattern uses and offers to show a converted version.

US→UK key mappings: sc→dc, dc→tr, hdc→htr, tr→dtr, skip→miss, yarn over→yarn round hook.

Converted text is shown in a scrollable preview within the panel — not written back to the file.

---

### 7. Stitch Count Verifier
Parses each row instruction and checks whether the resulting stitch count matches the expected count from the previous row. Flags rows where the math doesn't add up with a ⚠ indicator and an explanation.

Falls back gracefully for complex stitch patterns the model can't parse ("Could not verify rows 8–12 — pattern too complex to parse automatically").

---

### 8. Yarn Substitution Suggester
Given the yarn spec in the pattern (weight, fiber), suggests 2–3 alternative yarn characteristics that would work. Does not recommend specific brand names — stays generic (e.g., "any worsted-weight superwash wool or acrylic blend").

---

### 9. Project Time Estimator
Uses `rowGoal` from `PatternEntry` and a user-set "rows per hour" baseline (stored in `UserDefaults`, default 8) to estimate total hours remaining.

Formula: `hoursRemaining = (rowGoal - rowCount) / rowsPerHour`

The AI layer augments this with a note if the pattern is particularly stitch-dense ("Bobble stitches typically take 30–50% longer per row than plain sc rows — adjust your estimate accordingly").

Displayed as: "~4.5 hours remaining at your current pace."

---

### 10. Writing Tools (Notes field)
Free — no implementation needed. macOS 15+ Writing Tools are automatically available in any `TextEditor` view. When the inline note input is a SwiftUI `TextEditor` (or uses `NSTextView` under the hood), the system Writing Tools popover (Proofread, Rewrite, Summarize, etc.) appears automatically on right-click or selection.

---

## UI — AI Panel

- Toggled by a `✦` toolbar button in the counter bar area (right side)
- Slides in as a right-side inspector within the content pane (not a separate window)
- Width: 280pt, resizable
- Sections: Summary Card (always open) → Abbreviations → Q&A → Materials → Difficulty → US↔UK → Stitch Verifier → Yarn Sub → Time Estimate
- Each section has a disclosure triangle to collapse
- A "Regenerate" button per section re-runs inference for that feature
- `@available(macOS 15.1, *)` gate: on older OS, toolbar button is hidden entirely

---

## Files

| File | Change |
|------|--------|
| `PatternAIService.swift` | New — Foundation Models wrapper, all AI methods, in-memory cache |
| `AIPanelView.swift` | New — inspector panel with all feature sections |
| `AIFeatureSection.swift` | New — reusable disclosure section with spinner + regenerate |
| `PatternQAView.swift` | New — Q&A input + scrollable history |
| `CounterBarView.swift` | Add ✦ toolbar button (availability-gated) |
| `ContentView.swift` | Wire AI panel as optional right column |
| `UserDefaults+CrochetApp.swift` | New — typed UserDefaults extensions (rowsPerHour, aiPanelOpen) |

---

## Out of Scope

- Persisting Q&A history across launches
- Image generation / pattern chart generation
- Network-based AI (everything is on-device only)
- Fine-tuning or custom model training
