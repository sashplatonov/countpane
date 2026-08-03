# Menu Bar Application - Implementation Backlog

## Goal

Make Countpane a menu-bar application: it must run without a Dock icon and
expose a recognisable icon in the macOS menu bar. Clicking that icon must give
the user a clear way to open the existing management window or quit the app.
Countdown data, desktop widgets, login-item behaviour, and packaging must keep
their current contracts.

## Architectural decisions

- AppKit owns macOS process presentation. `AppDelegate` remains the single
  place that sets the application activation policy; it must use `.accessory`
  for the whole session instead of switching to `.regular` when a window is
  opened. This prevents the Dock icon from returning after interaction.
- SwiftUI owns the menu-bar UI. Extend the existing `CountpaneApp` scene graph
  with one `MenuBarExtra`; reuse its `openWindow(id: "main")` route rather than
  creating a second dashboard, state model, or window controller.
- `AppModel` and `CountdownRepository` remain the source of truth for
  countdowns and JSON persistence. No model, persistence format, API, or
  migration change is required for this presentation-only feature.
- The menu-bar control uses a system `calendar.badge.clock` symbol rendered by
  macOS as the accessible status-bar icon. Do not repurpose the colourful app
  icon (`AppBrandIcon`) as a tiny status-bar asset and do not add a duplicate
  icon asset unless a later visual review explicitly requires bespoke artwork.
- Existing desktop-widget ownership stays in `RootView`: it continues opening
  only active `visibleWidgetItems`. Opening the management window from the
  menu bar must reuse the same `main` scene, not recreate widgets or reload the
  repository.
- Backward compatibility is required for ordinary launches, login launches,
  keyboard-based editing, persistence on quit, Universal packaging, and
  existing desktop widgets. `LSUIElement` must not be added as a parallel
  launch-policy mechanism: the runtime AppKit policy is the selected mechanism.

## Recommended implementation order

| Order | Task | Priority | Depends on | Reason |
| ---: | --- | --- | --- | --- |
| 1 | P1-1 | P1 | - | Establish one testable policy for the new app lifetime contract before changing scenes. |
| 2 | P1-2 | P1 | P1-1 | Add the menu-bar entry point and apply the policy without duplicating UI state. |
| 3 | P2-1 | P2 | P1-2 | Prove the visible macOS behaviour and preserve it in release documentation. |

## P1-1: Define menu-bar application lifetime policy

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** -

### Outcome

Countpane has one explicit, test-covered policy for running as a menu-bar app:
the process stays alive when the management window closes, and the Dock is not
used as an application entry point.

### Architectural decision

Keep `AppLifetimePolicy` as the pure, unit-testable owner of process-lifetime
decisions. `AppDelegate` consumes that policy and remains responsible for the
AppKit activation policy. Do not encode lifecycle rules separately in
`RootView`, `MenuBarExtra`, or window callbacks.

### Files

- Modify `Sources/Countpane/Services/StartupBehavior.swift`.
- Modify `Tests/CountpaneTests/AppLifetimePolicyTests.swift`.
- Modify `Tests/CountpaneTests/StartupBehaviorTests.swift`.

### Work

1. Extend the existing pure startup/lifetime contract with the menu-bar
   presence needed to decide whether closing the final visible window should
   terminate the process.
2. Preserve the initial-load guard so a close during persistence loading cannot
   race the JSON read; once loaded, the persistent menu-bar control must keep
   the app available even with zero desktop widgets.
3. Keep login-item presentation semantics explicit: a login launch still does
   not show the management window, while the menu-bar control and enabled
   desktop widgets remain available.
4. Update focused unit tests for normal launch, login launch, no-widget state,
   visible-widget state, and an early window close. Tests must assert the new
   observable policy rather than AppKit implementation details.

### Acceptance criteria

- Closing the last management or About window after loading does not terminate
  Countpane solely because no desktop widget is visible.
- A login-item launch does not open the management window and still leaves a
  usable menu-bar entry point after model loading.
- The initial persistence-load close path never terminates while a visible
  window, desktop widget, or menu-bar entry is available.
- Existing tests for visible desktop widgets retain their meaning and pass.

### Verification

```bash
swift test --filter AppLifetimePolicyTests
swift test --filter StartupPresentationTests
swift test
```

### Commit

```bash
git add Sources/Countpane/Services/StartupBehavior.swift Tests/CountpaneTests/AppLifetimePolicyTests.swift Tests/CountpaneTests/StartupBehaviorTests.swift
git commit -m "feat(lifecycle): Support menu bar lifetime"
```

## P1-2: Expose Countpane through the macOS menu bar

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** P1-1

### Outcome

Countpane appears as a `calendar.badge.clock` menu-bar icon, has no Dock icon,
and offers an accessible menu action to open and focus the existing management
window plus a Quit action.

### Architectural decision

`CountpaneApp` owns the `MenuBarExtra` scene and uses the existing `main`
window route. `AppDelegate` applies `.accessory` once at launch and continues
to own termination persistence. The existing root scene remains the sole
dashboard and widget coordinator; no menu-bar popover dashboard or second
`AppModel` instance is allowed.

### Files

- Modify `Sources/Countpane/App/CountpaneApp.swift`.
- Modify `Sources/Countpane/Services/StartupBehavior.swift`.
- Modify `Tests/CountpaneTests/AppLifetimePolicyTests.swift`.

### Work

1. Add a `MenuBarExtra` scene using the selected system-symbol label and a
   menu-style interaction suitable for quick actions.
2. Provide a visible, keyboard-accessible **Show Main Window** action that
   activates Countpane and reuses `openWindow(id: "main")`; it must work both
   before and after the management window has been closed.
3. Add a clearly labelled Quit action that follows the existing
   `applicationShouldTerminate` persistence path; do not bypass
   `saveImmediately()` with force termination.
4. Replace every `.regular` activation-policy assignment used by the current
   launch and command code with the agreed accessory policy. Verify that
   opening or editing a countdown still makes its window key and accepts
   keyboard input without restoring a Dock icon.
5. Update the delegate's final-window-close call to consume the P1-1 policy,
   preserving enabled-widget opening and login-launch behaviour in `RootView`.

### Acceptance criteria

- After a cold launch of `Countpane.app`, the `calendar.badge.clock` icon is
  visible in the menu bar and Countpane has no Dock tile.
- Clicking the icon exposes **Show Main Window** and **Quit** with meaningful
  accessibility labels; keyboard navigation can invoke both actions.
- **Show Main Window** opens or focuses the existing 1200×760 management
  window; it does not create a second dashboard, reset filters, or duplicate
  desktop-widget windows.
- Closing the management window leaves the menu-bar icon available; clicking
  it can reopen the window.
- Creating or editing a countdown from the reopened window accepts physical
  keyboard input, and the Dock remains absent throughout the interaction.
- Choosing **Quit** saves the most recent mutation through the existing JSON
  repository, then removes the menu-bar icon and process.
- Login-item launch remains windowless while enabled desktop widgets and the
  menu-bar entry point are available.

### Verification

```bash
swift test
swift package dump-package >/dev/null
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
./Scripts/build-app.sh 0.0.0-menu-bar
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
open -n dist/Countpane.app
```

Then perform the macOS smoke test in the acceptance criteria with the packaged
app; inspect both the menu bar and Dock, close and reopen the management
window, edit a countdown, quit, and relaunch. A successful build alone is not
proof of status-bar visibility, Dock absence, or keyboard focus.

### Commit

```bash
git add Sources/Countpane/App/CountpaneApp.swift Sources/Countpane/Services/StartupBehavior.swift Tests/CountpaneTests/AppLifetimePolicyTests.swift
git commit -m "feat(menubar): Run Countpane from menu bar"
```

## P2-1: Document and release-check menu-bar behaviour

**Status:** ✅ Completed
**Priority:** P2
**Depends on:** P1-2

### Outcome

Users and release maintainers can discover the menu-bar entry point and verify
that it remains available without a Dock tile in packaged builds.

### Architectural decision

User-facing behaviour belongs in `README.md`; release-only validation belongs
in `docs/RELEASE_CHECKLIST.md`. Keep the existing widget and login-item copy
accurate and do not describe an implementation detail such as an activation
policy as a user instruction.

### Files

- Modify `README.md`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Update the product overview and getting-started guidance to state that
   Countpane lives in the menu bar and that its icon opens the management
   window.
2. Amend the application smoke-test checklist with separate observable checks
   for menu-bar visibility, Dock absence, window reopening, keyboard editing,
   and clean Quit persistence.
3. Keep the wording compatible with desktop widgets and Launch at Login;
   neither feature is removed by this change.

### Acceptance criteria

- README instructions tell a new user where to find Countpane after launch and
  how to reopen its management window.
- The release checklist distinguishes a successful app build from a manual
  verification of menu-bar presence and Dock absence.
- The documented smoke test includes a relaunch after an edit and confirms
  the saved countdown remains present.

### Verification

```bash
git diff --check
swift test
./Scripts/build-app.sh 0.0.0-menu-bar
open -n dist/Countpane.app
```

Perform the documented packaged-app smoke test on macOS before a release; CI's
Universal build verifies packaging but does not prove the interactive menu-bar
geometry or Dock presentation.

### Commit

```bash
git add README.md docs/RELEASE_CHECKLIST.md
git commit -m "docs(menubar): Describe menu bar workflow"
```

## Final quality gates

```bash
swift test
swift package dump-package >/dev/null
bash -n Scripts/*.sh
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
./Scripts/build-app.sh 0.0.0-menu-bar
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
lipo -archs dist/Countpane.app/Contents/MacOS/Countpane
git diff --check
```

Before merging, run the packaged-app manual smoke test from P1-2 on macOS and
obtain a fresh GitHub Actions CI run for both `arm64` and `x86_64` plus the
Universal app bundle.
