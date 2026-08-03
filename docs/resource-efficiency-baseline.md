# Resource Efficiency Baseline

This document is the repeatable measurement protocol for Countpane's CPU, memory, disk, network, and battery behavior. It is intentionally separate from application telemetry: Countpane does not collect analytics or ship a diagnostics SDK.

## Scope and privacy

- Measure packaged `Countpane.app`, not the Swift Package executable.
- Use a fresh temporary macOS user or a fixture containing synthetic titles such as `Fixture 001`; never use a personal `countpane.json`.
- Store raw `.trace` files outside the repository, for example under `/tmp/countpane-resource-traces`.
- Record only anonymized aggregate results in this document or a release note.

## Required metadata

Record the date, Countpane version/build, Mac model, `arm64` or `x86_64`, macOS version, Xcode/Swift version, AC or battery power, battery percentage at start/end, fixture size, visible widget count, and whether the management window is open.

## Scenarios

Run each scenario three times for 180 seconds after a 30-second warm-up. Keep the fixture and power mode constant within a comparison.

1. Normal launch with zero active visible widgets; close the management window and verify the process exits.
2. One active visible widget with the management window closed.
3. Ten active visible widgets with the management window closed.
4. Management window open with at least 1,000 active/completed synthetic countdowns; exercise search, sort, and section switching once during the foreground phase, then leave it idle.
5. Automatic update checks enabled, with the app left idle and no user action.
6. Automatic update checks disabled, with the app left idle; compare against scenario 5 for unintended request/process activity.
7. Sleep the Mac during the widget-only scenario, wake it, and observe widget restoration, date refresh, and update scheduling for one additional interval.

## Instruments commands

Build the packaged app first:

```bash
./Scripts/build-app.sh 0.0.0-resource-baseline
mkdir -p /tmp/countpane-resource-traces
```

Use Power Profiler for energy impact and Time Profiler/Allocations for CPU and memory samples. Replace the output name for each scenario; do not commit the trace files.

```bash
xcrun xctrace record --template 'Power Profiler' --output /tmp/countpane-resource-traces/power-scenario-1.trace --time-limit 180s --launch -- dist/Countpane.app
xcrun xctrace record --template 'Time Profiler' --output /tmp/countpane-resource-traces/time-scenario-4.trace --time-limit 180s --launch -- dist/Countpane.app
xcrun xctrace record --template 'Allocations' --output /tmp/countpane-resource-traces/allocations-scenario-4.trace --time-limit 180s --launch -- dist/Countpane.app
```

Use Instruments' process/network and file-activity views for update and persistence observations. Do not treat a successful compile as proof of runtime battery behavior.

## Comparison rules

For each metric, report the three-run median and the observed range. Compare the same scenario before and after a code change on the same architecture and power source. Establish the initial numeric budget from the first clean baseline; until then, report measurements without inventing a percentage improvement. A later change is a regression when it exceeds the documented measurement noise band without a user-visible behavior reason.

The release gate must include CPU time/wakeups, energy impact, resident memory and growth, disk writes, network requests, spawned processes, widget visibility, and sleep/wake behavior. Keep architecture-specific results separate; do not average Apple Silicon and Intel into one number.

## Result table

| Scenario | Architecture | Power | Runs | CPU / wakeups | Energy impact | Memory | Disk/network/processes | Notes |
| --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| Baseline to be recorded | `arm64` | To record | 3 | To record | To record | To record | To record | Use synthetic fixture |
| Baseline to be recorded | `x86_64` | To record | 3 | To record | To record | To record | To record | Use Intel hardware or document follow-up |
