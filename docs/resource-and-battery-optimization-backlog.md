# Resource and Battery Optimization - Implementation Backlog

## Goal

Reduce Countpane's CPU wakeups, memory/GPU work, disk writes, and network/process activity when it is idle, while preserving the core promise: enabled desktop countdown widgets remain available after the management window closes and on Login Item launches. The work must be driven by reproducible measurements on both Apple Silicon and Intel Macs; it must not add a user-facing "energy saver" mode or weaken persistence, update, or widget behavior.

## Architectural decisions

- `AppModel.items` and `CountdownRepository` remain the source of truth for countdowns. Resource optimization must not add a second widget list, a cache persisted separately from `countpane.json`, or a new data format.
- `AppDelegate` owns the process-lifetime decision; `RootView` owns opening and dismissing SwiftUI windows; `StartupPresentationDecision` in `Services/StartupBehavior.swift` remains the testable, UI-independent policy seam. The AppKit delegate must not infer widget state from `NSApp.windows` alone because SwiftUI window creation is asynchronous.
- `UpdateController` remains the sole owner of automatic-update preference, last-successful-check timestamp, scheduling, release requests, and Homebrew invocation. Do not introduce a second timer, an AppKit-level duplicate update loop, or another `UserDefaults` key for the same preference.
- The existing `TimelineView` instances are the only approved presentation clock until profiling proves that a shared clock reduces actual wakeups. If a shared clock is introduced, it must have one lifecycle owner and must stop when no visible countdown surface needs date-derived text.
- Derived dashboard collections are presentation data, not stored data. Any optimization must derive one immutable snapshot from the existing `items`, search, sort, filter, and current date inputs; avoid independent sorting/counting paths in `RootView`, `ActiveView`, and the sidebar.
- Preserve compatibility with existing `countpane.json` files and existing `update.automaticChecksEnabled` / `update.lastSuccessfulCheck` defaults. No migration is expected.
- Measurement traces can contain window titles and local app activity. Keep raw `.trace` files out of Git; commit only anonymized aggregate results and the repeatable protocol.

## Recommended implementation order

| Order | Task | Priority | Depends on | Reason |
| ---: | --- | --- | --- | --- |
| 1 | P1-1 | P1 | - | Establishes the baseline and gates so later changes optimize a verified bottleneck. |
| 2 | P1-2 | P1 | P1-1 | Releases the process when no user-visible desktop widget needs it. |
| 3 | P1-3 | P1 | P1-1 | Removes unnecessary update-related process/network work while retaining the current preference contract. |
| 4 | P2-1 | P2 | P1-1 | Removes repeated model derivation only if the realistic large-list trace identifies it as material. |
| 5 | P2-2 | P2 | P1-2, P1-3, P2-1 | Verifies the complete idle, widget, update, sleep/wake, and release-build contract. |

## P1-1: Define a repeatable resource and battery baseline

**Status:** 🚧 In progress
**Priority:** P1
**Depends on:** -

### Outcome

Maintainers can compare before/after idle power behavior with the same app build, scenarios, duration, machine metadata, and trace template. The repository records acceptance thresholds based on a clean baseline rather than claiming unmeasured battery savings.

### Architectural decision

Instrumentation is an operational verification artifact, not application state. `xctrace` Power Profiler and Time Profiler remain external tools; neither diagnostics SDKs nor analytics are added to this private local-data app.

### Files

- Create `docs/resource-efficiency-baseline.md`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Document a controlled protocol for a release build on AC and battery power: normal launch with no widgets, one visible widget with main window closed, ten visible widgets with main window closed, management window with a realistic large list, automatic updates enabled, and automatic updates disabled.
2. Record the required machine model, architecture, macOS/Xcode versions, power source, build version, countdown count, active windows, and trace duration. Use a fresh local fixture with non-sensitive titles rather than a user's production JSON file.
3. Define comparison rules: three runs per scenario, compare medians, record CPU wakeups/CPU time, energy impact, memory growth, disk writes, and network/process events. Set numeric regression budgets only after the first baseline; any later change must not regress a scenario by more than the documented noise band without an explicit reason.
4. Add the resource/battery verification steps to the release checklist, including manual verification after sleep/wake. Keep raw traces outside the repository and commit only the anonymized summary table.

### Acceptance criteria

- A new maintainer can produce comparable `.trace` files without guessing the target app, Instruments template, data fixture, or scenario duration.
- The protocol explicitly distinguishes idle CPU/power behavior from foreground interaction latency and build-time resource use.
- The accepted summary has results for both `arm64` and `x86_64`, or records a dated reason and follow-up when physical Intel hardware is unavailable.
- No user countdown title, note, export, or raw trace is committed.

### Verification

```bash
swift package dump-package >/dev/null
swift test
./Scripts/build-app.sh 0.0.0-resource-baseline
xcrun xctrace list templates | rg -F 'Power Profiler'
mkdir -p /tmp/countpane-resource-traces
xcrun xctrace record --template 'Power Profiler' --output /tmp/countpane-resource-traces/no-widget.trace --time-limit 180s --launch -- dist/Countpane.app
xcrun xctrace record --template 'Time Profiler' --output /tmp/countpane-resource-traces/widget.trace --time-limit 180s --launch -- dist/Countpane.app
```

### Commit

```bash
git add docs/resource-efficiency-baseline.md docs/RELEASE_CHECKLIST.md
git commit -m "docs(performance): Define resource baseline"
```

## P1-2: End the idle process when no desktop widget requires it

**Status:** 🚧 In progress
**Priority:** P1
**Depends on:** P1-1

### Outcome

After the management window closes, Countpane exits when no enabled widget is visible, so it cannot consume background memory, timers, or battery. When at least one widget is enabled, closing the management window still leaves widgets running and movable as before.

### Architectural decision

Create or extend a pure policy in `StartupBehavior.swift` that maps the durable `AppModel.visibleWidgetItems` result to the AppKit termination decision. `CountpaneApp.swift` consumes that policy from `applicationShouldTerminateAfterLastWindowClosed`; it must not duplicate filtering logic or persist an additional "keep running" flag.

### Files

- Modify `Sources/Countpane/Services/StartupBehavior.swift`.
- Modify `Sources/Countpane/App/CountpaneApp.swift`.
- Modify `Tests/CountpaneTests/StartupBehaviorTests.swift`.
- Create `Tests/CountpaneTests/AppLifetimePolicyTests.swift`.

### Work

1. Introduce a deterministic, unit-testable lifetime decision for the two states: zero active visible widgets and one-or-more active visible widgets.
2. Make the AppKit delegate request termination after the final window closes only for the zero-widget state; retain the existing save-on-termination guarantee.
3. Ensure a Login Item launch with no eligible widgets does not remain hidden indefinitely after the main window is dismissed, while a Login Item launch with visible widgets remains background-only.
4. Add tests for completed or hidden items not keeping the app alive, and for the existing visible-widget flow remaining alive.

### Acceptance criteria

- Closing the final management window with no active visible widgets terminates Countpane and the last edit remains in `countpane.json` after relaunch.
- Closing the final management window with one or more active visible widgets keeps the process and every enabled widget alive.
- A completed countdown and an active countdown whose widget is hidden do not keep the process alive.
- Login Item behavior remains: no management window is shown; enabled widgets are restored; an empty widget set does not leave an invisible long-running app.

### Verification

```bash
swift test
./Scripts/build-app.sh 0.0.0-resource-lifetime
open dist/Countpane.app
```

Manual smoke test in the packaged app: exercise the four acceptance states, quit immediately after an edit, relaunch, and verify the saved item plus widget restoration.

### Commit

```bash
git add Sources/Countpane/Services/StartupBehavior.swift Sources/Countpane/App/CountpaneApp.swift Tests/CountpaneTests/StartupBehaviorTests.swift Tests/CountpaneTests/AppLifetimePolicyTests.swift
git commit -m "perf(lifecycle): Exit without visible widgets"
```

## P1-3: Make automatic update work lifecycle-aware and coalesced

**Status:** 🚧 In progress
**Priority:** P1
**Depends on:** P1-1

### Outcome

Disabling automatic checks prevents all automatic update-related detection, timers, and GitHub requests. When checks are enabled, launch, periodic, and manual triggers share one in-flight operation instead of producing concurrent network requests or Homebrew detection processes.

### Architectural decision

`UpdateController` owns one cancellable scheduling/in-flight state and delegates transport/channel detection to its existing protocols. Preserve the current defaults keys and manual "Check for Updates" behavior. The UI in `UpdateSettingsSection` only observes controller state; it must not start a timer or issue a request itself.

### Files

- Modify `Sources/Countpane/Services/UpdateController.swift`.
- Modify `Sources/Countpane/Services/UpdateInfrastructure.swift` only if event-driven process waiting replaces the current polling implementation after profiling confirms it is material.
- Modify `Tests/CountpaneTests/UpdateTests.swift`.
- Modify `Sources/Countpane/Views/UpdateSettingsSection.swift` only if user-facing timing copy changes.
- Modify `README.md` only if the shipped update behavior changes.

### Work

1. Audit each automatic path: application launch, preference toggle, periodic firing, sleep/wake deferral, and manual action. Ensure an automatic opt-out returns before installation-channel detection or release-client work starts.
2. Coalesce concurrent automatic and manual checks so only one release request and one channel-detection operation can be active; make final status deterministic and preserve the explicit manual request when a throttled automatic check would otherwise return.
3. Cancel/retire the scheduled automatic work when the preference is disabled or the app terminates. Do not retry in a tight loop after offline, rate-limit, or malformed-release failures.
4. Use the P1-1 trace to decide whether replacing `SafeProcessRunner`'s 100 ms polling loop is worthwhile. If it is not material during a user-initiated Homebrew action, document that decision and leave the proven timeout/cancellation behavior unchanged.
5. Add injected fakes or counters needed to test no-work-on-opt-out, coalescing, throttling, failure behavior, and re-enabling. Do not test with live GitHub or Homebrew.

### Acceptance criteria

- With automatic updates disabled before startup, no release request, Homebrew detection process, or recurring update timer is created until the user presses "Check for Updates".
- With automatic updates enabled, repeated lifecycle/timer triggers during a check result in one release request and one channel detection, not parallel work.
- Manual checking remains possible after an automatic opt-out and reports the same success/error states as today.
- Offline, GitHub rate-limited, malformed tag, unavailable Homebrew, and process timeout states remain user-facing and do not cause rapid background retries.
- Re-enabling automatic checks schedules exactly one future automatic path and preserves the existing last-successful-check throttle semantics.

### Verification

```bash
swift test
./Scripts/build-app.sh 0.0.0-resource-updates
xcrun xctrace record --template 'Power Profiler' --output /tmp/countpane-resource-traces/updates-disabled.trace --time-limit 180s --launch -- dist/Countpane.app
```

Manual packaged-app smoke test: toggle automatic checks off, relaunch, wait through the documented observation window, then use the manual action; repeat after toggling it on and after sleep/wake.

### Commit

```bash
git add Sources/Countpane/Services/UpdateController.swift Sources/Countpane/Services/UpdateInfrastructure.swift Tests/CountpaneTests/UpdateTests.swift Sources/Countpane/Views/UpdateSettingsSection.swift README.md
git commit -m "perf(updates): Coalesce background checks"
```

## P2-1: Eliminate measured duplicate dashboard derivation

**Status:** 🚧 In progress
**Priority:** P2
**Depends on:** P1-1

### Outcome

On a realistic large countdown collection, one presentation refresh derives active items, sidebar counts, "Next Up", and card data without repeatedly sorting/filtering the same `items` collection. Small collections retain the current output and interaction behavior.

### Architectural decision

Keep the raw `[CountdownItem]` in `AppModel`; introduce a single in-memory, immutable dashboard query/snapshot only if P1-1 shows this path in CPU or allocation samples. `RootView`, `ActiveView`, and `DashboardSidebarView` consume that result instead of each recomputing a parallel view of the model. Do not cache to disk or introduce a separate observable store.

### Files

- Modify `Sources/Countpane/Services/AppModel.swift`.
- Modify `Sources/Countpane/Views/RootView.swift`.
- Modify `Sources/Countpane/Views/ActiveView.swift`.
- Modify `Sources/Countpane/Views/DashboardSidebarView.swift`.
- Modify `Tests/CountpaneTests/AppModelFilteringTests.swift`.
- Create `Tests/CountpaneTests/DashboardSnapshotTests.swift`.

### Work

1. Capture baseline call stacks and allocations with the large-list scenario before changing code. If repeated derivation is absent from the material samples, mark this task blocked with the trace evidence and do not perform speculative caching.
2. Define the snapshot inputs and invalidation boundaries: item mutation/import/load, search text, sort mode, selected filter, and the date tick. Make the current date a supplied value so sorting and "Next Up" remain internally consistent for one render.
3. Replace duplicate calls to `activeItems(at:)`, `nextItem(at:)`, and sidebar filtering with the shared derived result, retaining existing deterministic tie-breaking and visibility rules.
4. Test filtering, pinned ordering, completion handling, next-item selection, and count values for empty, normal, and large fixture sets. Include a regression check that the date change updates day-sensitive values without changing stored data.

### Acceptance criteria

- With a fixture of at least 1,000 active and completed countdowns, a normal dashboard refresh produces the same active cards, sidebar counts, pinned ordering, and "Next Up" item as the pre-change behavior.
- Search, sorting, filter selection, complete/restore/delete/undo, import, and widget visibility changes invalidate displayed derived data correctly without a relaunch.
- Date-derived labels update after the documented time tick, while no mutation or save occurs solely because time advanced.
- The after trace meets the P1-1 CPU/allocation regression budget for the large-list scenario; otherwise this task is not marked complete.

### Verification

```bash
swift test
./Scripts/build-app.sh 0.0.0-resource-dashboard
xcrun xctrace record --template 'Time Profiler' --output /tmp/countpane-resource-traces/dashboard-large-list.trace --time-limit 180s --launch -- dist/Countpane.app
xcrun xctrace record --template 'Allocations' --output /tmp/countpane-resource-traces/dashboard-large-list-allocations.trace --time-limit 180s --launch -- dist/Countpane.app
```

### Commit

```bash
git add Sources/Countpane/Services/AppModel.swift Sources/Countpane/Views/RootView.swift Sources/Countpane/Views/ActiveView.swift Sources/Countpane/Views/DashboardSidebarView.swift Tests/CountpaneTests/AppModelFilteringTests.swift Tests/CountpaneTests/DashboardSnapshotTests.swift
git commit -m "perf(dashboard): Share derived countdown data"
```

## P2-2: Prove idle and battery behavior in the packaged app

**Status:** ⬜ Not started
**Priority:** P2
**Depends on:** P1-2, P1-3, P2-1

### Outcome

The optimized release build has reproducible local evidence for the no-widget idle case, widget-only background case, large-dashboard case, update settings, sleep/wake behavior, and both binary architectures. Documentation accurately states only the behavior that was measured.

### Architectural decision

This is an integration and operations gate. It consumes the source-of-truth runtime contracts above and does not add runtime feature flags, persistence fields, API calls, or alternative clocks.

### Files

- Modify `docs/resource-efficiency-baseline.md`.
- Modify `docs/RELEASE_CHECKLIST.md`.
- Modify `README.md` only if user-visible resource behavior needs explanation.

### Work

1. Repeat every P1-1 scenario three times on the supported Apple Silicon build and the Intel build or supported Intel macOS test environment; record anonymized median and variance against the accepted baseline.
2. Validate close/relaunch/widget restoration, Login Item background launch, automatic-update opt-out/manual action, network failure, and sleep/wake without relying on a successful compilation as browserless runtime proof.
3. Build the universal app, verify architectures, code signature, and packaging checks. Verify that no release artifact or repository file contains traces, fixture data, or private countdown content.
4. Update release documentation with the measured result, known hardware scope, and explicit follow-up if a target cannot be measured. Do not claim percentage battery improvement when the trace does not establish it.

### Acceptance criteria

- The no-widget scenario leaves no Countpane process after the final management window closes.
- The widget-only scenario keeps enabled widgets visible and responsive for the full observation window without opening the management window or showing repeated CPU activity outside the accepted baseline.
- The update-disabled scenario has no automatic GitHub request or Homebrew detection; manual update checking still works.
- After sleep/wake, the app does not create duplicate widgets, duplicate timers, or duplicate update requests, and date labels refresh correctly.
- `swift test`, universal build, architecture validation, code-signature validation, and the complete resource protocol pass for the release candidate.

### Verification

```bash
swift package dump-package >/dev/null
swift test
bash -n Scripts/*.sh
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
./Scripts/build-app.sh 0.0.0-resource-verify
lipo -archs dist/Countpane.app/Contents/MacOS/Countpane
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
xcrun xctrace record --template 'Power Profiler' --output /tmp/countpane-resource-traces/release-widget.trace --time-limit 180s --launch -- dist/Countpane.app
git status --short
```

Remote CI proof remains separate: confirm the `native-tests` matrix and `universal-build` job in `.github/workflows/ci.yml` are green for the committed release candidate.

### Commit

```bash
git add docs/resource-efficiency-baseline.md docs/RELEASE_CHECKLIST.md README.md
git commit -m "docs(performance): Verify resource budget"
```
