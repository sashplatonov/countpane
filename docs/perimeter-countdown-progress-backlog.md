# Perimeter Countdown Progress - Implementation Backlog

## Goal

Show an icon-inspired countdown-progress outline around every active countdown presentation. The floating desktop widget gets the strongest treatment: a rounded, segmented track follows its entire edge and the elapsed portion is a rounded, theme-aware active stroke. The same visual language replaces the grid card's horizontal progress bar and is added to compact rows, without changing countdown data or user settings.

## Architectural decisions

- `CountdownItem.progress(at:calendar:)` remains the sole source of elapsed progress. It already normalizes valid values to `0...1` and returns `nil` when a countdown has no valid creation-to-target interval.
- The new reusable SwiftUI decoration owns only geometry, track styling, and active-stroke rendering. It receives the existing optional progress and `CountdownTheme`; it must not calculate dates, read `AppStorage`, mutate `AppModel`, or create persisted display settings.
- The active stroke follows the icon's visual grammar: a muted segmented background track, a round-capped elapsed segment, and a theme-derived gradient. Use `CountdownTheme.gradient`/`accent` so every countdown remains legible in its selected theme; do not hard-code the AppIcon SVG colors into app views.
- The indicator is decorative. Existing card and widget accessibility labels remain the spoken source of countdown status; the decoration is hidden from accessibility to avoid duplicate progress announcements.
- The preferred widget placement is its rounded perimeter. Active list cards use the same rounded-perimeter indicator in both `Compact Row` and `Card Grid` modes. The existing grid-only horizontal bar is removed rather than showing two progress indicators.
- No API, model schema, SQLite migration, JSON format, or backward-compatibility migration is required. Existing records that produce `nil` progress simply render no indicator, preserving current behavior.

## Recommended implementation order

| Order | Task | Priority | Depends on | Reason |
| ---: | --- | --- | --- | --- |
| 1 | P1-1 | P1 | - | Establish one tested presentation contract before wiring it into three surfaces. |
| 2 | P1-2 | P1 | P1-1 | Add the perimeter treatment to the fixed-size desktop widget without changing panel behavior. |
| 3 | P1-3 | P1 | P1-1 | Apply the same component consistently to both active-list densities and remove the old duplicate bar. |
| 4 | P2-1 | P2 | P1-2, P1-3 | Capture visual regression checks and complete the production-build smoke test. |

## P1-1: Create the shared perimeter-progress decoration

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** -

### Outcome

Active countdown views can layer one reusable rounded-perimeter progress decoration over their own content. It matches the app icon's segmented-track and rounded-active-stroke language while remaining safe for `nil`, `0`, and `1` progress values.

### Architectural decision

The UI layer owns this reusable decoration. Its input is the existing optional model progress plus `CountdownTheme`; `CountdownItem` remains the owner of time arithmetic. The component is the only new place that maps normalized progress to a trimmed rounded shape, preventing independent widget and card implementations from drifting.

### Files

- Create `Sources/Countpane/UI/CountdownPerimeterProgress.swift`.
- Create `Tests/CountpaneTests/CountdownPerimeterProgressTests.swift`.
- Modify `Tests/CountpaneTests/ProgressTests.swift` only if an uncovered `CountdownItem.progress` boundary is needed by the presentation contract.

### Work

1. Define a reusable decoration for a rounded-rectangle contour with explicit corner radius, line width, and inset so its stroke is never clipped by the host's `clipShape`.
2. Render a subdued segmented track and a round-capped active segment that begins at the visual top of the contour. Derive the active color treatment from the supplied `CountdownTheme` and retain contrast on its light and dark gradients.
3. Treat `nil` as no decoration, `0` as track-only, and `1` as a visually complete active contour. Clamp any direct component input defensively even though the model already normalizes it.
4. Make the decoration non-interactive and accessibility-hidden so it cannot intercept a card click, context menu, widget drag, or close button.
5. Add focused unit tests for the component's visible-state/normalized-trim contract, including `nil`, lower and upper bounds, and clamped out-of-range input. Keep existing model-progress tests as the date-calculation contract.

### Acceptance criteria

- A valid 50% progress value produces one active perimeter segment over a full muted segmented track.
- `nil` produces neither track nor active segment; 0% produces the track without a visible elapsed segment; 100% completes the active outline.
- The active segment has rounded ends, starts at the top edge, and follows the rounded contour without sharp joins or clipped pixels.
- The decoration does not expose a separate accessibility element or consume pointer events.
- All `CountdownTheme` cases receive their color from the supplied theme; the implementation does not duplicate the icon SVG's hex palette in Swift.

### Verification

```bash
swift test --filter CountdownProgressTests
swift test --filter CountdownPerimeterProgressTests
swift test
```

### Commit

```bash
git add Sources/Countpane/UI/CountdownPerimeterProgress.swift Tests/CountpaneTests/CountdownPerimeterProgressTests.swift Tests/CountpaneTests/ProgressTests.swift
git commit -m "feat(progress): add perimeter indicator"
```

## P1-2: Add perimeter progress to the desktop widget

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** P1-1

### Outcome

Each visible desktop widget shows its countdown progress around the rounded edge, while preserving its 294×184 panel, drag behavior, close control, urgency pulse, and readable title/duration layout.

### Architectural decision

`CountdownWidgetView` stays a presentation consumer of `CountdownItem` and uses the shared decoration with `item.progress(at: now)`. The AppKit panel and `WidgetWindowController` are intentionally unchanged: panel size and movement remain a window concern, not a progress concern.

### Files

- Modify `Sources/Countpane/Views/CountdownWidgetView.swift`.
- Modify `Tests/CountpaneTests/WidgetPresentationTests.swift`.

### Work

1. Place `CountdownPerimeterProgress` inside the widget's existing rounded clipping and border layers, with a deliberate inset that leaves its active stroke visible along all four edges.
2. Use the `TimelineView` context date already passed to `widget(_:now:)`; do not introduce another clock, timer, state variable, or persistence value.
3. Preserve the close button's hit target and visibility, the drag surface, current icon/title/duration hierarchy, and the existing gentle-pulse behavior. The progress overlay must not create a square shadow or halo.
4. Add coverage for the widget's presentation contract if a lightweight, testable input/helper is introduced; otherwise retain the current model and manual visual checks rather than adding a view-inspection dependency.

### Acceptance criteria

- At 294×184, a widget with valid progress has a continuous rounded perimeter indicator and all text remains inside the widget bounds.
- A widget with a missing or invalid progress interval remains visually clean and behaves exactly as before, with no empty outline.
- The 26×26 close control is reachable by mouse and its help text remains available; dragging unused widget background still moves the panel.
- The progress overlay follows the countdown's selected light and dark theme without reducing the contrast of the title, duration, or urgency label.
- No widget persistence, visibility, panel level, position-restoration, or pulse schedule behavior changes.

### Verification

```bash
swift test --filter DesktopWidgetPresentationTests
swift test --filter CountdownProgressTests
swift test
./Scripts/build-app.sh 0.0.0-progress
open dist/Countpane.app
```

Manual check in the built app: create countdowns with Ocean Light, Graphite, and Aurora themes; inspect 0%, partial, complete, and missing-creation-date states; move and close a widget; relaunch and confirm its saved position.

### Commit

```bash
git add Sources/Countpane/Views/CountdownWidgetView.swift Tests/CountpaneTests/WidgetPresentationTests.swift
git commit -m "feat(widget): show perimeter progress"
```

## P1-3: Replace active-list progress with the shared perimeter treatment

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** P1-1

### Outcome

Both active countdown list densities show the same icon-inspired elapsed progress around their card edges. Card Grid no longer also renders its horizontal progress bar.

### Architectural decision

`CountdownCard` remains the only active-list presentation owner. It uses the existing `progress` computed property, which delegates to `CountdownItem`, and layers the shared decoration alongside the existing selected-card border. Do not add a separate compact-row progress calculation or an `AppTheme`-based color override.

### Files

- Modify `Sources/Countpane/Views/ActiveView.swift`.
- Modify `Tests/CountpaneTests/ProgressTests.swift` only if P1-1 did not already add the required progress boundary coverage.

### Work

1. Add the shared rounded-perimeter decoration to the card-level overlay so it applies to both `Compact Row` and `Card Grid` layouts and respects each layout's existing 15/18-point corner radius.
2. Keep the existing selection border (`isNext`) discernible; define its layer order and opacity so it remains visible without competing with the progress indicator.
3. Remove the grid card's 6-point horizontal `GeometryReader` progress bar once the perimeter indicator is present. Do not change title, target-date, urgency, actions, hover, context-menu, or pulse behavior.
4. Ensure the new overlay stays decorative and does not alter the full-card edit tap, the compact-row chevron button, grid menu, or keyboard focus behavior.

### Acceptance criteria

- In `Compact Row` and `Card Grid`, an active countdown with valid progress shows one perimeter indicator using the selected `CountdownTheme`.
- Grid cards contain no horizontal progress bar after the change.
- A next countdown still has a visible selected border, and hover/pulse effects do not hide the progress contour.
- Cards with `nil` progress retain their existing border and layout without an empty progress ring or changed vertical spacing.
- Card edit, context-menu, menu, Complete, and widget-toggle controls remain reachable by mouse and keyboard.

### Verification

```bash
swift test --filter CountdownProgressTests
swift test --filter DashboardSnapshotTests
swift test
./Scripts/build-app.sh 0.0.0-progress
open dist/Countpane.app
```

Manual check in the built app: switch between Compact Row and Card Grid; check Ocean Light, Peach, Midnight, Forest, Lavender, Graphite, Minimal Light, and Aurora countdown themes; verify next-item, hover, context-menu, and keyboard actions at 0%, partial, complete, and unavailable progress values.

### Commit

```bash
git add Sources/Countpane/Views/ActiveView.swift Tests/CountpaneTests/ProgressTests.swift
git commit -m "feat(countdowns): use perimeter progress"
```

## P2-1: Record visual release checks and run the final quality gate

**Status:** ✅ Completed
**Priority:** P2
**Depends on:** P1-2, P1-3

**Visual smoke check:** Waived by user; local automated verification and packaged-app launch completed.

### Outcome

The release checklist makes perimeter-progress review reproducible, and the finished change has local test, packaging, and manual macOS proof.

### Architectural decision

Visual geometry is a macOS runtime concern and cannot be proven by the current unit-test-only suite. Document the manual checks in the existing release checklist instead of inventing a screenshot-test framework for this feature. CI remains the source of remote compile/package proof after the change is pushed; local success does not claim a fresh remote run.

### Files

- Modify `docs/RELEASE_CHECKLIST.md`.
- Modify `docs/perimeter-countdown-progress-backlog.md` to mark completed tasks only after their commits and checks succeed.

### Work

1. Add concise application-smoke checks for the widget perimeter, both active list densities, light/dark countdown themes, and absent-progress fallback.
2. Run the complete local suite and create a signed local app bundle using the documented build script.
3. Perform the manual interaction checks against the built app. Record any issue as a follow-up rather than weakening visual, accessibility, or build requirements.
4. After the branch is pushed, confirm the corresponding GitHub Actions run separately; do not treat local build output as remote CI evidence.

### Acceptance criteria

- The release checklist names the required perimeter-progress visual and interaction checks.
- `swift test` passes with no warning suppression or test exclusion.
- `./Scripts/build-app.sh 0.0.0-progress` produces a codesign-verified app containing `Contents/Resources/AppIcon.icns`.
- Manual macOS testing proves the widget and both active-list layouts meet the acceptance criteria; a fresh remote CI run is reported only when available.

### Verification

```bash
swift package dump-package >/dev/null
swift test
./Scripts/build-app.sh 0.0.0-progress
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
test -f dist/Countpane.app/Contents/Resources/AppIcon.icns
open dist/Countpane.app
```

### Commit

```bash
git add docs/RELEASE_CHECKLIST.md docs/perimeter-countdown-progress-backlog.md
git commit -m "docs(release): cover perimeter progress"
```
