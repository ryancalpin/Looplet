# UX & Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "basic / broken / alpha" UI with a token-based design system (warm-craft light / calm-focus dark), a Calm Reader + Focus-mode layout, an on-demand AI inspector, and a reliability pass — without changing the app's core data model.

**Architecture:** Introduce a `DesignSystem/` group (color tokens via Asset Catalog, a typography scale, reusable components). Restructure `ContentView` into a Calm Reader layout plus a Focus mode; lift `PatternAIService` ownership up so the AI panel can be unmounted when closed (kills the auto-burst). Fix the reliability bugs inline as their owning views are touched. No data-model changes except removing one view file.

**Tech Stack:** SwiftUI + AppKit interop (`NSViewRepresentable`, `WKWebView`, `PDFKit`), `@AppStorage`, FoundationModels (macOS 26+, already gated), Xcode project `CrochetApp` / scheme `CrochetApp`, deployment target macOS 13.

**Verification model (per project CLAUDE.md — no test target exists):** Every task ends by (a) building and confirming `** BUILD SUCCEEDED **`, and (b) where the change is visible, launching the app and capturing screenshots in **light mode, dark mode, and Focus mode**, then confirming against the spec. Unit tests are out of scope (no test target); logic fixes are verified by build + a described runtime check.

**Spec:** `docs/superpowers/specs/2026-05-21-ux-overhaul-design.md`

**Build command (used throughout):**
```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp" && \
xcodebuild build -scheme CrochetApp -configuration Debug \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

**Run + screenshot helper (used for visual verification):**
```bash
# Launch the freshly built app
APP=$(find ~/Library/Developer/Xcode/DerivedData/CrochetApp-*/Build/Products/Debug -maxdepth 1 -name 'CrochetApp.app' | head -1)
open "$APP"
# After interacting, capture the focused window (interactive: space, then click window)
screencapture -o -w ~/Desktop/crochet-shot.png
```
To toggle appearance for dark-mode shots: System Settings → Appearance, or run the app and use the in-app scheme/appearance. Capture both.

---

## File Structure

**New files**
- `CrochetApp/CrochetApp/DesignSystem/Theme.swift` — color token accessors (`Color.surface`, `.accentRow(for:)`, etc.) reading from the Asset Catalog.
- `CrochetApp/CrochetApp/DesignSystem/Typography.swift` — semantic font helpers.
- `CrochetApp/CrochetApp/DesignSystem/CounterPill.swift` — reusable Row/Stitch pill.
- `CrochetApp/CrochetApp/DesignSystem/StatChip.swift` — reusable label+value chip.
- `CrochetApp/CrochetApp/DesignSystem/SectionCard.swift` — AI inspector section container.
- `CrochetApp/CrochetApp/DesignSystem/GlassHUD.swift` — floating counter cluster for Focus mode.
- Asset Catalog colorsets under `Assets.xcassets` (surfaces + per-scheme accents, each Any/Dark).
- `Samples/Granny-Square-Blanket.md` (repo root) — fixture for visual verification.

**Removed**
- `CrochetApp/CrochetApp/PatternStatsBannerView.swift`

**Modified** (responsibility after change)
- `ContentView.swift` — layout, Focus mode, AI ownership + gating.
- `CounterBarView.swift` — uses `CounterPill`; Clear-goal fix; tokens.
- `AIPanelView.swift` — lazy/sequential load; difficulty/total stay internal; two new sections.
- `PatternAIService.swift` — no behavior change except being owned externally (already fine).
- `SessionTimer.swift` — manual-pause tracking.
- `SettingsView.swift` — shortcut rows, restyle.
- `AppSettings.swift` — publish on change; schemes read from catalog.
- `MarkdownView.swift` — hover `＋ note` affordance; placeholder text; remove Alt-click.
- `PatternContentView.swift` — PDF access lifecycle; real surface color.
- `PatternLibraryView.swift` — drag-drop type validation.

---

## Phase 0 — Fixtures & baseline

### Task 0.1: Add a sample pattern fixture

**Files:**
- Create: `Samples/Granny-Square-Blanket.md`

- [ ] **Step 1: Create the fixture file**

```markdown
# Granny Square Blanket

**Skill level:** Intermediate
**Materials:** Worsted-weight (#4) yarn, 5.0 mm (H/8) hook, tapestry needle
**Finished size:** 48" × 60"

## Abbreviations
- ch — chain
- sl st — slip stitch
- dc — double crochet
- sp — space

## Instructions

Round 1: ch 4, 2 dc in 4th ch from hook, ch 2, (3 dc, ch 2) 3 times in ring, join with sl st to top of beginning ch-3. (12 dc)

Round 2: sl st into next ch-2 sp, ch 3, (2 dc, ch 2, 3 dc) in same sp, *ch 1, (3 dc, ch 2, 3 dc) in next ch-2 sp; repeat from * around, ch 1, join. (24 dc)

Round 3: sl st to ch-2 sp, ch 3, (2 dc, ch 2, 3 dc) in same sp, *ch 1, 3 dc in next ch-1 sp, ch 1, (3 dc, ch 2, 3 dc) in corner; repeat from * around, join. (36 dc)

Round 4: continue the pattern, working (3 dc, ch 2, 3 dc) in each corner and 3 dc in each ch-1 space along the sides. (48 dc)
```

- [ ] **Step 2: Verify it renders**

Build (build command above), launch the app, click ＋, choose this file, confirm it renders with headings, lists, and paragraphs.
Expected: `** BUILD SUCCEEDED **` and a readable pattern.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp"
git add Samples/Granny-Square-Blanket.md
git commit -m "test: add sample pattern fixture for visual verification"
```

---

## Phase 1 — Design system

### Task 1.1: Color tokens (Asset Catalog + accessors)

**Files:**
- Create colorsets in `CrochetApp/CrochetApp/Assets.xcassets`
- Create: `CrochetApp/CrochetApp/DesignSystem/Theme.swift`
- Modify: `CrochetApp/CrochetApp/AppSettings.swift` (scheme cases unchanged; colors will be resolved in Theme)

- [ ] **Step 1: Create surface + text colorsets**

In `Assets.xcassets`, create colorsets, each with **Any Appearance** + **Dark** values (hex → sRGB):

| Colorset | Any (light) | Dark |
|---|---|---|
| `surface` | `#FBF6EF` | `#16151A` |
| `surfaceRaised` | `#FFFFFF` | `#211F28` |
| `surfaceSidebar` | `#F3E9DC` | `#1F1D24` |
| `textPrimary` | `#3A2F26` | `#E8D5C4` |
| `textSecondary` | `#7A6A58` | `#9A92A6` |
| `divider` | `#ECE0D0` | `#2A2730` |

(Each colorset is a folder containing a `Contents.json` with two appearances. Use Xcode's asset editor or hand-author `Contents.json`.)

- [ ] **Step 2: Create per-scheme accent colorsets**

For each scheme create `<scheme>Row` and `<scheme>Stitch` colorsets with Any + Dark:

| Scheme | Row Any | Row Dark | Stitch Any | Stitch Dark |
|---|---|---|---|---|
| classic | `#C26B5A` | `#F0A878` | `#9A6FB0` | `#C3AEF5` |
| ocean | `#007ACC` | `#54B8FF` | `#008C99` | `#4FD6E0` |
| forest | `#2E7D49` | `#6FD08C` | `#C47D2B` | `#E8B36A` |
| sunset | `#E0612B` | `#FF9259` | `#BF3349` | `#FF7088` |
| mono | `#737373` | `#B0B0B0` | `#A6A6A6` | `#D9D9D9` |

- [ ] **Step 3: Set AccentColor**

Set the existing `AccentColor` colorset to Any `#C26B5A`, Dark `#F0A878`.

- [ ] **Step 4: Write Theme.swift**

```swift
import SwiftUI

extension Color {
    static let surface        = Color("surface")
    static let surfaceRaised  = Color("surfaceRaised")
    static let surfaceSidebar = Color("surfaceSidebar")
    static let textPrimary    = Color("textPrimary")
    static let textSecondary  = Color("textSecondary")
    static let dividerToken   = Color("divider")
}

extension AppSettings.PillColorScheme {
    var rowColor: Color   { Color("\(rawValue)Row") }
    var stitchColor: Color { Color("\(rawValue)Stitch") }
}
```

- [ ] **Step 5: Remove the hardcoded scheme colors from AppSettings**

In `AppSettings.swift`, delete the `rowColor`/`stitchColor` computed properties on `PillColorScheme` (lines ~98–116) — they're now provided by the `Theme.swift` extension. Keep the enum cases, `rawValue`, and `label`.

- [ ] **Step 6: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **` (no other view changes yet; existing `settings.pillColorScheme.rowColor` calls now resolve via Theme).

- [ ] **Step 7: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp"
git add CrochetApp/CrochetApp/Assets.xcassets CrochetApp/CrochetApp/DesignSystem/Theme.swift CrochetApp/CrochetApp/AppSettings.swift
git commit -m "feat: color token system with light/dark colorsets for all 5 schemes"
```

### Task 1.2: Typography scale

**Files:**
- Create: `CrochetApp/CrochetApp/DesignSystem/Typography.swift`

- [ ] **Step 1: Write Typography.swift**

```swift
import SwiftUI

enum Typo {
    /// Large counter numerals — rounded, monospaced digits, scales with Dynamic Type.
    static func counter(_ size: AppSettings.CounterSize) -> Font {
        let base: Font.TextStyle
        switch size {
        case .compact: base = .title3
        case .normal:  base = .title
        case .large:   base = .largeTitle
        }
        return .system(base, design: .rounded).weight(.bold)
    }

    static let pillLabel  = Font.caption2.weight(.semibold)
    static let sectionTitle = Font.headline
    static let bodyText   = Font.callout
    static let metadata   = Font.caption
}
```

- [ ] **Step 2: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add CrochetApp/CrochetApp/DesignSystem/Typography.swift
git commit -m "feat: semantic typography scale (Dynamic Type aware)"
```

### Task 1.3: CounterPill component

**Files:**
- Create: `CrochetApp/CrochetApp/DesignSystem/CounterPill.swift`

- [ ] **Step 1: Write CounterPill.swift**

```swift
import SwiftUI

struct CounterPill: View {
    let label: String
    let value: Int
    let goal: Int?
    let color: Color
    let size: AppSettings.CounterSize
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    private var pillHeight: CGFloat { size.pillHeight }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", enabled: value > 0, action: onDecrement)
            Divider().frame(height: pillHeight)
            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Text(label).font(Typo.pillLabel).foregroundColor(color)
                    if let goal { Text("/ \(goal)").font(Typo.pillLabel).foregroundColor(color.opacity(0.6)) }
                }
                Text("\(value)")
                    .font(Typo.counter(size)).monospacedDigit()
                    .foregroundColor(color)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: value)
            }
            .frame(minWidth: 48).padding(.horizontal, 6)
            Divider().frame(height: pillHeight)
            stepButton(systemName: "plus", enabled: true, action: onIncrement)
        }
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(color.opacity(0.25), lineWidth: 1.5))
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: pillHeight, height: pillHeight)
                .background(color.opacity(0.15))
                .foregroundColor(enabled ? color : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
```

- [ ] **Step 2: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add CrochetApp/CrochetApp/DesignSystem/CounterPill.swift
git commit -m "feat: reusable CounterPill component"
```

### Task 1.4: StatChip, SectionCard, GlassHUD components

**Files:**
- Create: `CrochetApp/CrochetApp/DesignSystem/StatChip.swift`
- Create: `CrochetApp/CrochetApp/DesignSystem/SectionCard.swift`
- Create: `CrochetApp/CrochetApp/DesignSystem/GlassHUD.swift`

- [ ] **Step 1: Write StatChip.swift**

```swift
import SwiftUI

struct StatChip: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(Typo.pillLabel).foregroundColor(.textSecondary)
            Text(value).font(Typo.metadata.weight(.semibold)).foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.surfaceRaised)
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Write SectionCard.swift**

```swift
import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let isLoading: Bool
    let onRegenerate: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Group {
                if isLoading {
                    HStack { ProgressView().scaleEffect(0.7); Text("Generating…").font(Typo.metadata).foregroundColor(.textSecondary) }
                        .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content().padding(.top, 4)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Text(title).font(Typo.sectionTitle).foregroundColor(.textPrimary)
                Spacer()
                if !isLoading, let onRegenerate {
                    Button(action: onRegenerate) {
                        Image(systemName: "arrow.clockwise").imageScale(.small).foregroundColor(.textSecondary)
                    }.buttonStyle(.plain).help("Regenerate this section")
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}
```

- [ ] **Step 3: Write GlassHUD.swift**

```swift
import SwiftUI

/// Floating counter cluster used in Focus mode. Caller supplies the pills.
struct GlassHUD<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.dividerToken, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}
```

- [ ] **Step 4: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add CrochetApp/CrochetApp/DesignSystem/StatChip.swift CrochetApp/CrochetApp/DesignSystem/SectionCard.swift CrochetApp/CrochetApp/DesignSystem/GlassHUD.swift
git commit -m "feat: StatChip, SectionCard, GlassHUD components"
```

---

## Phase 2 — Counter bar refactor + remove banner

### Task 2.1: Rebuild CounterBarView on CounterPill + fix Clear-goal

**Files:**
- Modify: `CrochetApp/CrochetApp/CounterBarView.swift`

- [ ] **Step 1: Replace rowPill/stitchPill with CounterPill usage**

Replace the `rowPill` and `stitchPill` computed properties (and the `pillShell` helper) with two `CounterPill` instances inside `body`'s `HStack`. The Row pill:

```swift
CounterPill(
    label: "ROW", value: store.rowCount, goal: entry?.rowGoal,
    color: rowColor, size: settings.counterSize,
    onDecrement: { store.decrementRow() }, onIncrement: { store.incrementRow() }
)
.help("Rows — right-click to set goal")
.popover(isPresented: $showRowGoalPopover, arrowEdge: .bottom) {
    GoalInputPopover(
        title: "Row Goal", currentGoal: entry?.rowGoal, inputText: $rowGoalInput,
        onConfirm: { entry?.rowGoal = $0; showRowGoalPopover = false },
        onClear:   { entry?.rowGoal = nil; showRowGoalPopover = false },
        onDismiss: { showRowGoalPopover = false }
    )
}
.contextMenu {
    Button("Set Row Goal…") { rowGoalInput = entry?.rowGoal.map { "\($0)" } ?? ""; showRowGoalPopover = true }
    if entry?.rowGoal != nil { Button("Clear Row Goal") { entry?.rowGoal = nil } }
}
```

Do the same for the Stitch pill (`label: "STITCH"`, `goal: entry?.stitchGoal`, `color: stitchColor`, stitch increment/decrement, stitch goal popover/menu with `onClear: { entry?.stitchGoal = nil; ... }`).

- [ ] **Step 2: Fix GoalInputPopover Clear button**

In the `GoalInputPopover` struct at the bottom of the file, add an `onClear` closure and wire the Clear button to it:

```swift
private struct GoalInputPopover: View {
    let title: String
    let currentGoal: Int?
    @Binding var inputText: String
    let onConfirm: (Int) -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField(currentGoal.map { "\($0)" } ?? "e.g. 60", text: $inputText)
                .textFieldStyle(.roundedBorder).frame(width: 120).focused($focused)
                .onSubmit { confirm() }
            HStack {
                if currentGoal != nil {
                    Button("Clear", role: .destructive, action: onClear).buttonStyle(.bordered)
                }
                Spacer()
                Button("Cancel", action: onDismiss).buttonStyle(.bordered)
                Button("Set") { confirm() }.buttonStyle(.borderedProminent).disabled(Int(inputText) == nil)
            }
        }
        .padding(16).frame(width: 200).onAppear { focused = true }
    }
    private func confirm() { if let v = Int(inputText), v > 0 { onConfirm(v) } }
}
```

- [ ] **Step 3: Token-ize the bar background and timer chip**

Change `.background(Color(NSColor.windowBackgroundColor))` on the bar to `.background(Color.surface)`. In `timerView`, replace `Color(NSColor.controlBackgroundColor)` with `Color.surfaceRaised` and the gray foregrounds with `.textSecondary`.

- [ ] **Step 4: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Visual verify**

Launch app, open the sample pattern. Set a row goal, then open the goal popover again and click **Clear** → confirm the goal is removed (the `/ N` disappears and progress bar hides). Screenshot the counter bar in light and dark.
Expected: pills styled via tokens; Clear actually clears.

- [ ] **Step 6: Commit**

```bash
git add CrochetApp/CrochetApp/CounterBarView.swift
git commit -m "refactor: CounterBarView on CounterPill; fix Clear-goal button"
```

### Task 2.2: Remove the stats banner

**Files:**
- Delete: `CrochetApp/CrochetApp/PatternStatsBannerView.swift`
- Modify: `CrochetApp/CrochetApp/ContentView.swift`

- [ ] **Step 1: Remove the banner from ContentView**

Delete the `if let entry = library.activeEntry { PatternStatsBannerView(...) }` block (lines ~34–41) and the `bannerDifficulty` / `bannerTotalRows` `@State` properties (lines ~13–14). Remove the `bannerDifficulty:`/`bannerTotalRows:` arguments from the `AIPanelView(...)` call and the corresponding `.onChange` resets that set them.

- [ ] **Step 2: Delete the file**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp"
git rm CrochetApp/CrochetApp/PatternStatsBannerView.swift
```

- [ ] **Step 3: Update AIPanelView signature**

In `AIPanelView.swift`, remove the `@Binding var bannerDifficulty: String?` and `@Binding var bannerTotalRows: String?` properties and every assignment to them (in `resetAll`, `loadSummary`, `loadDifficulty`, `regenSummary`, `regenDifficulty`). The difficulty/total now live only inside the panel.

- [ ] **Step 4: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Visual verify**

Launch on this machine (macOS 26 per build SDK). Open a pattern WITHOUT opening AI → confirm there is **no perpetual-spinner banner** under the counter bar. Screenshot.
Expected: counter bar sits directly above the pattern; no spinning chips.

- [ ] **Step 6: Commit**

```bash
git add CrochetApp/CrochetApp/ContentView.swift CrochetApp/CrochetApp/AIPanelView.swift
git commit -m "fix: remove redundant stats banner and its perpetual spinners"
```

---

## Phase 3 — AI inspector: on-demand + lazy

### Task 3.1: Lift PatternAIService ownership and unmount panel when closed

**Files:**
- Modify: `CrochetApp/CrochetApp/ContentView.swift`
- Modify: `CrochetApp/CrochetApp/AIPanelView.swift`

- [ ] **Step 1: Own the service in ContentView**

In `ContentView`, add (gated for availability so the type resolves):

```swift
@available(macOS 26.0, *)
private final class AIServiceBox { static let shared = PatternAIService() }
```

Simpler and avoids generic-availability issues: keep a single service instance accessible only inside the `if #available` block. In the detail `HStack`, change the AI block so the panel is mounted **only when open**:

```swift
if #available(macOS 26.0, *), showAIPanel, let entry = library.activeEntry, let text = loadedPatternText {
    resizableDivider
    AIPanelView(service: AIServiceBox.shared, entry: entry, patternText: text,
                showAIPanel: $showAIPanel, abbreviationDict: $abbreviationDict)
        .frame(width: aiPanelWidth)
        .transition(.move(edge: .trailing))
}
```

Wrap the `showAIPanel` toggle site (in `CounterBarView`) and this block usage with `.animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAIPanel)` on the container `HStack`.

- [ ] **Step 2: Accept the injected service in AIPanelView**

In `AIPanelView.swift`, replace `@StateObject private var service = PatternAIService()` with `@ObservedObject var service: PatternAIService` and add it as the first init parameter (struct memberwise init covers it). Keep the in-memory cache benefit because the single shared instance survives mount/unmount.

- [ ] **Step 3: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Visual verify (the auto-burst fix)**

Launch app. Open a pattern but DO NOT open AI. Confirm the app is responsive immediately and no AI work runs (no spinners anywhere). Then click ✦ AI → panel slides in and sections begin loading. Close and reopen → cached results appear instantly. Screenshot open + closed states.
Expected: zero AI activity until the panel is opened.

- [ ] **Step 5: Commit**

```bash
git add CrochetApp/CrochetApp/ContentView.swift CrochetApp/CrochetApp/AIPanelView.swift
git commit -m "fix: AI inspector loads on demand; service owned outside the panel (no auto-burst)"
```

### Task 3.2: Load AI sections sequentially + surface the two unwired features

**Files:**
- Modify: `CrochetApp/CrochetApp/AIPanelView.swift`

- [ ] **Step 1: Make loadAll sequential**

Replace the six fire-and-forget `Task {}` loaders' invocation. Change `loadAll()` to a single async sequence so the on-device model isn't hit by 6 concurrent requests:

```swift
.task(id: entry.id) {
    resetAll()
    await loadSummary()
    await loadAbbreviations()
    await loadMaterials()
    await loadDifficulty()
    await loadStitchVerifier()
    await loadTimeEstimate()
    await loadConversion()
    await loadYarnSubs()
}
```

Convert each `loadX()` from `func loadX() { Task { ... } }` to `func loadX() async { do { ... } catch { ... } }` (remove the inner `Task {}` wrapper; the body stays the same).

- [ ] **Step 2: Add state + loaders for the two new sections**

Add `@State private var conversion: String? = nil`, `@State private var conversionError: String? = nil`, `@State private var yarnSubs: String? = nil`, `@State private var yarnSubsError: String? = nil`. Reset them in `resetAll()`. Add:

```swift
private func loadConversion() async {
    do { conversion = try await service.convertTerminology(patternID: entry.id, patternText: patternText) }
    catch { conversionError = error.localizedDescription }
}
private func loadYarnSubs() async {
    do { yarnSubs = try await service.suggestYarnSubstitutions(patternID: entry.id, patternText: patternText) }
    catch { yarnSubsError = error.localizedDescription }
}
private func regenConversion() { service.clearCache(for: entry.id); conversion = nil; conversionError = nil; Task { await loadConversion() } }
private func regenYarnSubs() { service.clearCache(for: entry.id); yarnSubs = nil; yarnSubsError = nil; Task { await loadYarnSubs() } }
```

- [ ] **Step 3: Render the two new sections**

After the Time Estimate section in `body`, add (using the new `SectionCard` from Task 1.4 — swap the existing `AIFeatureSection` usages to `SectionCard` in this same edit for consistency; `SectionCard` has the same `title`/`isLoading`/`onRegenerate`/content shape):

```swift
Divider().padding(.horizontal, 12)
SectionCard(title: "US ↔ UK Convert", isLoading: service.isLoadingConversion, onRegenerate: regenConversion) {
    if let c = conversion { Text(c).font(Typo.bodyText).fixedSize(horizontal: false, vertical: true) }
    else if let e = conversionError { errorText(e) } else { loadingPlaceholder }
}
Divider().padding(.horizontal, 12)
SectionCard(title: "Yarn Substitutes", isLoading: service.isLoadingYarnSub, onRegenerate: regenYarnSubs) {
    if let y = yarnSubs { Text(y).font(Typo.bodyText).fixedSize(horizontal: false, vertical: true) }
    else if let e = yarnSubsError { errorText(e) } else { loadingPlaceholder }
}
```

Delete `AIFeatureSection.swift` after swapping all usages to `SectionCard`:
```bash
git rm CrochetApp/CrochetApp/AIFeatureSection.swift
```

- [ ] **Step 4: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Visual verify**

Launch app (macOS 26), open the sample pattern, open ✦ AI. Confirm sections fill in one after another (not all spinning at once), and the new **US ↔ UK Convert** and **Yarn Substitutes** sections render content. Screenshot.
Expected: sequential load; two new sections populated.

- [ ] **Step 6: Commit**

```bash
git add CrochetApp/CrochetApp/AIPanelView.swift
git commit -m "feat: sequential AI loading; surface US/UK convert + yarn substitutes; adopt SectionCard"
```

---

## Phase 4 — Focus mode

### Task 4.1: Focus-mode state, toggle, and GlassHUD layout

**Files:**
- Modify: `CrochetApp/CrochetApp/ContentView.swift`
- Modify: `CrochetApp/CrochetApp/CrochetAppApp.swift`

- [ ] **Step 1: Add focus state + a notification toggle**

In `ContentView` add `@State private var focusMode = false`. Wrap the sidebar + divider in `if !focusMode { ... }`. When `focusMode` is true, overlay the counters as a `GlassHUD` at top-center of the detail pane:

```swift
.overlay(alignment: .top) {
    if focusMode {
        GlassHUD {
            CounterPill(label: "ROW", value: store.rowCount, goal: library.activeEntry?.rowGoal,
                        color: settings.pillColorScheme.rowColor, size: settings.counterSize,
                        onDecrement: { store.decrementRow() }, onIncrement: { store.incrementRow() })
            CounterPill(label: "STITCH", value: store.stitchCount, goal: library.activeEntry?.stitchGoal,
                        color: settings.pillColorScheme.stitchColor, size: settings.counterSize,
                        onDecrement: { store.decrementStitch() }, onIncrement: { store.incrementStitch() })
        }
        .padding(.top, 12)
    }
}
```

When `focusMode` is true, hide the normal `CounterBarView` (wrap it in `if !focusMode`). Add `@ObservedObject private var settings = AppSettings.shared` to `ContentView` if not present.

- [ ] **Step 2: Add the menu command + shortcut**

In `CrochetAppApp.swift`, add a `CommandGroup(after: .sidebar)` (or `.toolbar`) with a Focus toggle posting a notification:

```swift
CommandGroup(after: .sidebar) {
    Button("Toggle Focus Mode") { NotificationCenter.default.post(name: .toggleFocusMode, object: nil) }
        .keyboardShortcut("f", modifiers: [.control, .command])
}
```

And add `static let toggleFocusMode = Notification.Name("CrochetApp.toggleFocusMode")` to the `Notification.Name` extension. In `ContentView`, observe it:

```swift
.onReceive(NotificationCenter.default.publisher(for: .toggleFocusMode)) { _ in
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { focusMode.toggle() }
}
```

- [ ] **Step 3: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Visual verify**

Launch app, open sample pattern, press ⌃⌘F. Confirm: sidebar collapses, pattern fills width, glass counter HUD floats top-center and `+`/`−` work. Press again to exit. Screenshot Focus mode in light and dark.
Expected: clean distraction-free mode; counters usable; smooth animation.

- [ ] **Step 5: Commit**

```bash
git add CrochetApp/CrochetApp/ContentView.swift CrochetApp/CrochetApp/CrochetAppApp.swift
git commit -m "feat: Focus mode (⌃⌘F) with floating glass counter HUD"
```

---

## Phase 5 — Reliability fixes

### Task 5.1: Timer remembers manual pause

**Files:**
- Modify: `CrochetApp/CrochetApp/SessionTimer.swift`

- [ ] **Step 1: Track manual pause**

Add `private var userPaused = false`. In `togglePause()`, set `userPaused = isRunning ? true : false` before toggling (i.e., pausing sets it true, resuming sets it false). In `observeAppFocus()`'s activate handler, only resume if not user-paused:

```swift
func togglePause() {
    if isRunning { userPaused = true; pauseTimer() }
    else { userPaused = false; startTimer() }
}
```
```swift
// in the didBecomeActive observer:
{ [weak self] _ in
    guard let self, !self.userPaused else { return }
    self.startTimer()
}
```

- [ ] **Step 2: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Runtime verify**

Launch app. Pause the timer (click it). Switch to another app (Finder), then back. Confirm the timer is **still paused**. Then resume manually and confirm focus-switch still auto-pauses/resumes normally.
Expected: manual pause survives focus changes.

- [ ] **Step 4: Commit**

```bash
git add CrochetApp/CrochetApp/SessionTimer.swift
git commit -m "fix: session timer no longer auto-resumes after a manual pause"
```

### Task 5.2: AppSettings publishes changes live

**Files:**
- Modify: `CrochetApp/CrochetApp/AppSettings.swift`

- [ ] **Step 1: Make @AppStorage writes notify observers**

`@AppStorage` inside an `ObservableObject` does not emit `objectWillChange`. Add a UserDefaults observation that republishes. Replace the class body's storage approach minimally by adding, in `init`, a notification observer:

```swift
private var defaultsObserver: NSObjectProtocol?
private init() {
    defaultsObserver = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.objectWillChange.send() }
}
deinit { if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) } }
```

- [ ] **Step 2: Build**

Run build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Runtime verify**

Launch app, open the sample pattern so the counter bar is visible. Open Settings (⌘,) → Appearance → change Color Scheme and Counter Display Size. Confirm the counter bar updates **live** without needing to click a counter first.
Expected: appearance changes reflect immediately.

- [ ] **Step 4: Commit**

```bash
git add CrochetApp/CrochetApp/AppSettings.swift
git commit -m "fix: AppSettings republishes on UserDefaults change so appearance updates live"
```

### Task 5.3: Remove phantom ⌘O hints

**Files:**
- Modify: `CrochetApp/CrochetApp/SettingsView.swift`
- Modify: `CrochetApp/CrochetApp/MarkdownView.swift`

- [ ] **Step 1: Fix Shortcuts tab**

In `SettingsView.swift` `shortcutsTab`, delete the `shortcutRow("⌘ O", "Open pattern file")` line. Add `shortcutRow("⌃⌘F", "Toggle Focus Mode")` under the App section.

- [ ] **Step 2: Fix empty placeholder**

In `MarkdownView.swift` `EmptyMarkdownPlaceholder`, change the body text from the ⌘O/File→Open wording to:

```swift
Text("Add a pattern from the sidebar — click the ＋ button or drag a Markdown, PDF, or text file in.")
```

- [ ] **Step 3: Build + visual verify**

Run build command (`** BUILD SUCCEEDED **`). Launch with no pattern selected → confirm placeholder shows the new text. Open Settings → Shortcuts → confirm no ⌘O row and a Focus Mode row is present. Screenshot.

- [ ] **Step 4: Commit**

```bash
git add CrochetApp/CrochetApp/SettingsView.swift CrochetApp/CrochetApp/MarkdownView.swift
git commit -m "fix: remove phantom Cmd-O hints; document Focus Mode shortcut"
```

### Task 5.4: Validate drag-dropped file types

**Files:**
- Modify: `CrochetApp/CrochetApp/PatternLibraryView.swift`

- [ ] **Step 1: Filter dropped URLs by extension**

In the `.onDrop` handler, before calling `library.add(url:)`, check the extension:

```swift
let allowedExt: Set<String> = ["md", "markdown", "txt", "text", "rtf", "pdf"]
// inside the loadObject completion, after `guard let url else { return }`:
guard allowedExt.contains(url.pathExtension.lowercased()) else { return }
```

- [ ] **Step 2: Build + verify**

Run build command (`** BUILD SUCCEEDED **`). Launch app, drag a non-supported file (e.g. a `.png`) onto the sidebar → confirm it is ignored. Drag the sample `.md` → confirm it's added.

- [ ] **Step 3: Commit**

```bash
git add CrochetApp/CrochetApp/PatternLibraryView.swift
git commit -m "fix: validate drag-and-drop file types before importing"
```

### Task 5.5: PDF security-scope lifecycle + surface color

**Files:**
- Modify: `CrochetApp/CrochetApp/PatternContentView.swift`

- [ ] **Step 1: Hold access for the view lifetime; load doc only on URL change**

Rewrite `PDFKitView` to keep security-scoped access open while the view exists, set the document only when the URL changes, and release on dismantle:

```swift
struct PDFKitView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(named: "surface") ?? .windowBackgroundColor
        context.coordinator.accessing = url.startAccessingSecurityScopedResource()
        view.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        // Release access to the previously loaded URL before switching.
        if context.coordinator.accessing, let old = context.coordinator.loadedURL {
            old.stopAccessingSecurityScopedResource()
        }
        context.coordinator.accessing = url.startAccessingSecurityScopedResource()
        pdfView.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        if coordinator.accessing, let u = coordinator.loadedURL { u.stopAccessingSecurityScopedResource() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var accessing = false; var loadedURL: URL? }
}
```

- [ ] **Step 2: Build + verify**

Run build command (`** BUILD SUCCEEDED **`). Add a multi-page PDF pattern, scroll to the last page → confirm later pages render (no blank pages) and that switching patterns and back doesn't reset scroll mid-view unexpectedly.

- [ ] **Step 3: Commit**

```bash
git add CrochetApp/CrochetApp/PatternContentView.swift
git commit -m "fix: hold PDF security scope for view lifetime; reload only on URL change"
```

---

## Phase 6 — Annotations hover affordance

### Task 6.1: Replace Alt-click with a hover "＋ note" button

**Files:**
- Modify: `CrochetApp/CrochetApp/MarkdownView.swift`

- [ ] **Step 1: Update the injected annotation JS**

In `injectAnnotationJS`, remove the Alt-click listener loop. Instead, give each `p,li` block relative positioning and inject a `＋ note` button that appears on hover. Replace the second `blocks.forEach(...) { block.addEventListener('click'...) }` section with:

```javascript
blocks.forEach(function(block, idx) {
  block.style.position = 'relative';
  var add = document.createElement('button');
  add.className = 'ann-add';
  add.textContent = '＋ note';
  add.style.cssText = 'position:absolute;right:0;top:0;opacity:0;transition:opacity .12s;'
    + 'font-size:10px;border:none;background:'+AMBER+';color:#3a2f26;border-radius:6px;'
    + 'padding:2px 6px;cursor:pointer;z-index:5';
  add.addEventListener('click', function(e){ e.stopPropagation(); openEditor(block, idx); });
  block.addEventListener('mouseenter', function(){ add.style.opacity = '0.95'; });
  block.addEventListener('mouseleave', function(){ add.style.opacity = '0'; });
  block.appendChild(add);
});
```

Keep `insertNoteElement`, `openEditor`, `saveNote`, `deleteNote` as-is (existing notes still render and are click-to-edit).

- [ ] **Step 2: Build + visual verify**

Run build command (`** BUILD SUCCEEDED **`). Launch app, open the sample pattern, hover over a row → confirm a small amber **＋ note** button appears at the row's right edge; click it → inline editor opens; type + Return → note saves below the row; reopen the pattern → note persists. Screenshot the hover affordance.
Expected: discoverable annotation; no modifier key needed.

- [ ] **Step 3: Commit**

```bash
git add CrochetApp/CrochetApp/MarkdownView.swift
git commit -m "feat: discoverable hover '+ note' affordance for annotations (replaces Alt-click)"
```

---

## Final verification

### Task 7.1: Full visual pass

- [ ] **Step 1: Build clean**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp" && \
xcodebuild clean build -scheme CrochetApp -configuration Debug \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Screenshot matrix**

Capture and eyeball each against the spec:
- Light mode — Calm Reader (sidebar + counter bar + pattern), no banner.
- Dark mode — Calm Reader.
- Light + Dark — Focus mode (glass HUD).
- AI inspector open (sections sequential, two new sections present).
- Goal popover Clear works; hover ＋ note appears.

- [ ] **Step 3: Confirm the checklist**

State explicitly: "Build passed; UI verified via screenshots in light/dark/Focus; banner gone; no perpetual spinners; Clear clears; timer survives focus switch; AI on-demand; hover notes work."

- [ ] **Step 4: Final commit (if any cleanup)**

```bash
git add -A && git commit -m "chore: UX overhaul final polish pass" || echo "nothing to commit"
```

---

## Self-review notes (author)

- **Spec coverage:** §1 design system → Phase 1; §2 layout/Focus/AI → Phases 2–4; §3 reliability → Phase 5 + Tasks 2.1/2.2/3.1; §4 annotations → Phase 6; §5 settings → Tasks 5.3; §6 dead code → Task 3.2. All sections mapped.
- **Naming consistency:** `GoalInputPopover` gains `onClear` (used in Task 2.1 and defined in same task). `SectionCard` replaces both `AIFeatureSection` and is used in Task 3.2. `AIServiceBox.shared` is the single service instance used by ContentView + AIPanelView.
- **Known follow-ups (not in scope):** context-window guarding for large patterns on summary/verifier; `@Generable` structured AI parsing; sandbox entitlements. Tracked in the spec's non-goals.
