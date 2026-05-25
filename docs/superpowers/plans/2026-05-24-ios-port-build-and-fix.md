# iOS Port: Build, Fix & Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Looplet build and run cleanly on both macOS and iOS (iPhone 17 Pro / iOS 26.5), fix compile errors, pass tests on both platforms, then close the three known iOS UX gaps.

**Architecture:** Single multiplatform target with `#if os(macOS)` / `#if canImport(UIKit)` guards. Platform shims live in Platform.swift. Sheets and JS annotations need iOS-specific adaptations. No iPad simulator is currently installed — iPad testing is blocked until one is added.

**Tech Stack:** Swift 6, SwiftUI, WebKit (WKWebView), PDFKit, AudioToolbox (iOS), AppKit/UIKit conditional compilation, XcodeBuildMCP for build/run/screenshot.

**Available simulators:** iPhone 17 Pro (iOS 26.5) — Booted. No iPad simulator installed.

---

### Phase 0: macOS Regression

- [ ] Build macOS: `xcodebuild -project CrochetApp/Looplet.xcodeproj -scheme Looplet -destination 'platform=macOS' build`
- [ ] Fix every compile error and warning
- [ ] Run macOS app and confirm: counters, library, PDF viewer, markdown viewer, sounds, Settings, menus, focus mode all work
- [ ] Commit: `git commit -m "fix: macOS regression baseline"`

---

### Phase 1: iOS Simulator Build

- [ ] Build for iPhone 17 Pro: `xcodebuild build -scheme Looplet -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- [ ] Fix every compile error (see known risks below)
- [ ] Confirm `** BUILD SUCCEEDED **`
- [ ] Commit: `git commit -m "fix: iOS simulator build passes"`

**Known compile risks (written in a Linux container, never compiled):**
- `NSCursor` references inside `#if os(macOS)` blocks — verify guards are present
- `onHover` in `PatternLibraryView` entryRow and yarnRow — must be macOS-only
- `KeyboardShortcutHandler` / `KeyHandlerView` (NSViewRepresentable) — must be macOS-only  
- `NSApp.mainWindow?.title` in ContentView — must be macOS-only (already guarded)
- `PatternExporter.share(_:from:)` overloads differ by `NSView?` vs `UIView?` — verify guards
- Any stray AppKit types leaking past `#if canImport(AppKit)` guards

---

### Phase 2: iOS UX Gap — Sheet Widths

**Files:** `CrochetApp/Looplet/PatternLibraryView.swift`

The three inline sheets have hard-coded macOS widths that look cramped on iPhone:
- `AddYarnSheet` — `.frame(width: 320)` 
- `AddTagSheet` — `.frame(width: 300)`
- `RenameSheet` — `.frame(width: 300)`
- `GoalInputPopover` — `.frame(width: 200)` / `.frame(width: 120)` for text field

Fix: Remove the fixed `.frame(width:)` on iOS; let the sheet fill the presented width.

- [ ] In each sheet body, replace:
  ```swift
  .padding(20).frame(width: 300)
  ```
  with:
  ```swift
  .padding(20)
  #if os(macOS)
  .frame(width: 300)
  #endif
  ```
  (same pattern for 320, 200, 120)
- [ ] Build iOS and verify no regressions on macOS
- [ ] Screenshot iPhone 17 Pro showing each sheet full-width
- [ ] Commit: `git commit -m "fix: iOS sheets use full-width on iPhone"`

---

### Phase 3: iOS UX Gap — Tap-Based Annotation Affordance

**Files:** `CrochetApp/Looplet/MarkdownView.swift`

The annotation JS in `injectAnnotationJS` is entirely hover-based (`mouseenter`/`mouseleave`). On iOS:
- Tapping an existing note (the amber `div`) correctly calls `openEditor` ✓
- There is no way to ADD a new note (the pencil button only appears on hover)
- Tooltips for abbreviations use `mouseover`/`mouseout` — never fire on touch

Fix plan:
1. **New-note tap affordance:** After the existing hover listeners, add a `touchend` listener on each block. On touch, toggle a "tapped" state: show a brief "+ note" button near the tapped block (or immediately open `openEditor`).
2. **Abbreviation touch:** Replace `mouseover`/`mouseout` on abbreviation spans with a `touchstart` that opens a short-lived tooltip positioned above the tapped word, hiding after 3s or on any other touch.

- [ ] In `injectAnnotationJS`, after all the `mouseenter`/`mouseleave` listeners on `blocks`, add:
  ```javascript
  // iOS touch: tap a paragraph to add a note
  blocks.forEach(function(block) {
    block.addEventListener('touchend', function(e) {
      // Don't trigger if user tapped an existing note or the button
      if (e.target.closest('[id^="ann-note-"]') || e.target.closest('[id^="ann-editor-"]')) return;
      e.preventDefault();
      hoveredBlock = block;
      hoveredKey = fingerprint(block.textContent);
      openEditor(block, hoveredKey, existingNotes[hoveredKey]);
    });
  });
  ```
- [ ] In `injectAbbreviationTooltips`, after the `mouseover`/`mouseout` span listeners, add:
  ```javascript
  span.addEventListener('touchstart', function(ev) {
    ev.preventDefault();
    showTip(ev.touches[0], meaning);
    setTimeout(hideTip, 3000);
  }, {passive: false});
  ```
- [ ] Build iOS, run on iPhone 17 Pro, verify:
  - Tap a paragraph → editor opens
  - Tap an abbreviation → tooltip appears for ~3s
- [ ] Commit: `git commit -m "feat: iOS touch-based annotation and abbreviation tooltip"`

---

### Phase 4: iOS Sound Sanity Check

**Files:** `CrochetApp/Looplet/AppSettings.swift`

Current iOS system-sound IDs (from `/System/Library/Audio/UISounds`):
| Effect | ID | Notes |
|--------|-----|-------|
| tink | 1057 | short tap |
| pop | 1104 | pop |
| morse | 1103 | dot-dot-dot |
| glass | 1109 | xylophone-ish |
| bottle | 1131 | hollow blow |
| frog | 1112 | keyboard click variant |
| funk | 1130 | low bloop |
| hero | 1025 | fanfare |
| ping | 1052 | email-received ping |
| purr | 1070 | mechanical click |
| submarine | 1023 | sonar ping |
| blow | 1105 | whoosh |
| sosumi | 1073 | error sound |

- [ ] Run on iPhone 17 Pro, open Settings → Counting → enable sounds, pick each effect and listen
- [ ] Confirm all 13 IDs play an audible sound (some may be silent on newer iOS — flag any)
- [ ] If any ID is silent/wrong, replace with a working ID from `AudioServicesPlayAlertSound` family
- [ ] Commit if any IDs changed: `git commit -m "fix: update iOS system sound IDs"`

---

### Phase 5: Tests on Both Platforms

- [ ] Run macOS tests:
  ```
  xcodebuild test -scheme Looplet -destination 'platform=macOS'
  ```
- [ ] Run iOS Simulator tests:
  ```
  xcodebuild test -scheme Looplet -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
- [ ] Report pass counts; fix any failures
- [ ] Commit any test fixes

---

### Phase 6: iOS Golden-Path QA Screenshot

- [ ] Boot iPhone 17 Pro simulator and install app
- [ ] Screenshot: Library (empty state)
- [ ] Import a markdown/text pattern
- [ ] Screenshot: Pattern viewer with content
- [ ] Exercise counters (row +/−, stitch +/−)
- [ ] Screenshot: Counter bar with values
- [ ] Trigger focus mode
- [ ] Screenshot: Focus mode overlay
- [ ] Open Settings gear
- [ ] Screenshot: Settings sheet
- [ ] Test share/export via `…` menu
- [ ] Screenshot: Share sheet visible

---

### Known Blocking Issues to Report

- **No iPad simulator installed** — iPad (10th generation) was requested but is not available. Test on `iPhone 17 Pro` only until an iPad sim is installed via Xcode → Platforms.
- macOS app is in App Store review — do not push until user confirms.
