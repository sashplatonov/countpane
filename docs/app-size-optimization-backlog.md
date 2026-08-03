# Countpane Distribution Size Optimization - Implementation Backlog

## Goal

Reduce the size of the installed `Countpane.app` and the released DMG as far as
measurements allow, while keeping the full 1024px Retina app icon, all product
behavior, Hardened Runtime signing, and support for both Apple Silicon and
Intel Macs. The first local Universal release baseline is 12,692 KiB: 7,478,656
bytes of Universal executable and 5,497,238 bytes of duplicated icon resources.

## Architectural decisions

- `Scripts/build-app.sh` owns the release `.app` layout; SwiftPM owns only
  development/test builds. `Scripts/build-dmg.sh` owns the compressed download
  artifact, and the release workflow owns published asset names and checksums.
- `Packaging/AppIcon.iconset/` remains the high-resolution icon source and
  `Sources/Countpane/Resources/AppIcon.icns` remains the packaged macOS icon.
  The release bundle must contain one `AppIcon.icns`, not PNG and ICNS copies
  at both the top level and in a SwiftPM resource bundle.
- `AppIconResource` is the single resolver for the app icon used by the app
  icon and in-product brand views. It must resolve the canonical ICNS file;
  no view may introduce its own image asset or fallback packaging path.
- A Universal release remains the compatibility baseline until architecture-
  specific artifacts have equivalent CI, Homebrew, installation, signature,
  and launch proof. If split releases are adopted, each user receives exactly
  one native artifact; no Rosetta-only distribution is allowed.
- Debug symbols may be kept as CI/release diagnostics but must never be put in
  the `.app` or DMG. Any stripping is accepted only if it is reproducible and
  retains a UUID-matched external dSYM for crash symbolication.
- Repository-only documentation previews are out of scope for the application
  or DMG size budget because `Package.swift` does not package `docs/`. They
  may be optimized separately only when clone/repository size becomes a goal.

## Recommended implementation order

| Order | Task | Priority | Depends on | Reason |
| ---: | --- | --- | --- | --- |
| 1 | P1-1 | P1 | - | Establishes a reproducible budget before changing distribution behavior. |
| 2 | P1-2 | P1 | P1-1 | Removes the confirmed 5.50 MB duplicate-resource cause without reducing icon resolution. |
| 3 | P2-1 | P2 | P1-2 | Evaluates and, only if proven, removes release-only linker metadata. |
| 4 | P2-2 | P2 | P1-2 | Delivers smaller per-machine downloads without dropping either CPU architecture. |
| 5 | P3-1 | P3 | P1-2 | Tunes DMG compression only after content duplication is gone. |
| 6 | P2-3 | P2 | P2-1, P2-2, P3-1 | Locks the final budget and release evidence into CI and release documentation. |

## P1-1: Add a reproducible distribution-size baseline

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** -

### Outcome

Maintainers can build a release candidate and see comparable byte totals for
the app, executable, each bundled resource, DMG, and checksum without
estimating from Finder sizes.

### Architectural decision

Add a packaging-only measurement helper; do not put size counters or release
logic into the SwiftUI application. Measurements are evidence for packaging
decisions, not a runtime feature.

### Files

- Create `Scripts/measure-distribution-size.sh`.
- Modify `.github/workflows/ci.yml`.
- Modify `.github/workflows/release.yml`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Create a Bash helper that accepts an existing `.app` and optional DMG,
   prints byte and KiB values for the bundle, its executable, every file below
   `Contents/Resources`, the universal architectures, and the DMG when given.
2. Make the helper fail clearly for a missing file, a non-application path, or
   an executable lacking either required architecture when it is measuring the
   Universal baseline.
3. Run the helper after current CI and release packaging verification, and
   write the output to the job summary without uploading additional artifacts.
4. Record the baseline and the final accepted budget in the release checklist;
   update the number only from a clean, fresh release build.

### Acceptance criteria

- A clean `./Scripts/build-app.sh 0.0.0-size-check` followed by the helper
  reports the exact byte size of `dist/Countpane.app`, its executable, and all
  packaged resources.
- The report makes both copies of `AppIcon.icns` and `AppIcon.png` visible on
  the current baseline rather than grouping them into an opaque total.
- CI still verifies a signed Universal bundle, and its summary contains the
  same measurement categories as the local helper.
- The script exits nonzero with an actionable error for an absent app or DMG.

### Verification

```bash
bash -n Scripts/measure-distribution-size.sh Scripts/build-app.sh Scripts/build-dmg.sh
./Scripts/build-app.sh 0.0.0-size-check
./Scripts/measure-distribution-size.sh dist/Countpane.app
swift test
git diff --check
```

### Commit

```bash
git add Scripts/measure-distribution-size.sh .github/workflows/ci.yml .github/workflows/release.yml docs/RELEASE_CHECKLIST.md
git commit -m "ci(package): Measure distribution size"
```

## P1-2: Package one canonical high-resolution icon

**Status:** ✅ Completed
**Priority:** P1
**Depends on:** P1-1

### Outcome

The release application contains one 1024px-capable `AppIcon.icns`; the app,
menu-bar icon, sidebar, and About view retain identical rendering while the
confirmed duplicate icon payload is removed.

### Architectural decision

Use the existing ICNS as the sole release resource and make
`AppIconResource` resolve it. Remove SwiftPM resource processing only after
all product code and tests no longer require its generated resource bundle;
keep `Packaging/AppIcon.iconset/` as the editable Retina source, not a second
runtime asset source.

### Files

- Modify `Package.swift`.
- Modify `Scripts/build-app.sh`.
- Modify `Sources/Countpane/Services/AppIconResource.swift`.
- Modify `Tests/CountpaneTests/AppIconResourceTests.swift`.
- Modify `.github/workflows/ci.yml`.
- Modify `.github/workflows/release.yml`.
- Remove `Sources/Countpane/Resources/AppIcon.png`.

### Work

1. Change the application-resource resolver and its tests to identify
   `Contents/Resources/AppIcon.icns` as the canonical packaged resource,
   including a safe failure result if it is absent.
2. Stop copying `AppIcon.png` into the application and stop SwiftPM from
   producing a resource bundle containing both icon formats. Remove the PNG
   only after confirming no release or development path references it.
3. Preserve `CFBundleIconFile=AppIcon`, the existing 1024px ICNS representations,
   and the `NSImage` rendering path used by `CountpaneApp` and `AppBrandIcon`.
4. Replace CI/release assertions for the removed PNG with checks for exactly
   one release ICNS and no `Countpane_Countpane.bundle` under
   `Contents/Resources`.
5. Compare pre/post size reports. Accept this task only if the Universal app
   decreases by at least 2,700,000 bytes; otherwise investigate unexpected
   SwiftPM resource output before proceeding.

### Acceptance criteria

- `dist/Countpane.app/Contents/Resources/AppIcon.icns` exists and passes
  `iconutil --convert iconset` round-trip inspection with 16, 32, 128, 256,
  512, and 1024 pixel representations.
- The packaged app contains neither `AppIcon.png` nor
  `Countpane_Countpane.bundle`, and resource resolution finds the ICNS file.
- At 1x and 2x display scale, the macOS application icon, Dashboard sidebar
  icon, and About icon remain sharp with no reduced-resolution source image.
- Building from SwiftPM, launching the packaged app, and all existing app
  behaviors continue to work; an unavailable icon uses the existing visual
  fallback instead of crashing.
- The Universal app size decreases by at least 2.7 MB versus the P1-1 baseline
  and the release is still code-signature valid.

### Verification

```bash
swift test
./Scripts/build-app.sh 0.0.0-icon-dedup
./Scripts/measure-distribution-size.sh dist/Countpane.app
iconutil --convert iconset --output /tmp/Countpane-icon-check.iconset dist/Countpane.app/Contents/Resources/AppIcon.icns
test ! -e dist/Countpane.app/Contents/Resources/AppIcon.png
test ! -e dist/Countpane.app/Contents/Resources/Countpane_Countpane.bundle
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
git diff --check
```

### Commit

```bash
git add Package.swift Scripts/build-app.sh Sources/Countpane/Services/AppIconResource.swift Tests/CountpaneTests/AppIconResourceTests.swift .github/workflows/ci.yml .github/workflows/release.yml
git rm Sources/Countpane/Resources/AppIcon.png
git commit -m "perf(package): Deduplicate app icon resources"
```

## P2-1: Evaluate reproducible release stripping

**Status:** ✅ Completed
**Priority:** P2
**Depends on:** P1-2

### Outcome

Release builds retain only Mach-O information needed to launch, sign, and
symbolicate Countpane. The optimization is skipped if it does not produce a
meaningful saving or compromises diagnostic quality.

### Architectural decision

`Scripts/build-app.sh` is the only place allowed to change the final Mach-O.
Do not add compiler-wide flags or remove Swift reflection metadata speculatively.
Keep dSYMs outside `Countpane.app`, keyed to the final executable UUIDs, so
the release has no functional or visual trade-off.

### Files

- Modify `Scripts/build-app.sh`.
- Modify `Scripts/measure-distribution-size.sh`.
- Modify `.github/workflows/ci.yml`.
- Modify `.github/workflows/release.yml`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Compare the current release executable with an explicitly stripped copy
   using macOS tooling, recording per-architecture and Universal byte deltas,
   UUIDs, code-signature status, and whether a matching external dSYM exists.
2. Adopt only a documented stripping mode that has a material positive result
   (at least 5% of the executable or 250 KiB) and preserves the code paths
   used by SwiftUI, Foundation, update checks, JSON import/export, and login
   item registration.
3. Sign only after all binary modifications; retain the current Hardened
   Runtime entitlements and never use `codesign --deep` as a substitute for
   checking the final signed executable.
4. If no qualifying option exists, document the negative result and leave the
   build command unchanged rather than adding a no-op flag.

### Acceptance criteria

- The adopted path, if any, reduces the measured executable by the stated
  threshold relative to P1-2; otherwise the checklist records that stripping
  was rejected with the measured reason.
- `lipo -archs` still reports `arm64 x86_64`, each final UUID has a matching
  dSYM outside the app, and the dSYM is not included in the DMG.
- Final signing, entitlement inspection, launch, countdown editing,
  persistence, import/export, update settings, and widget display succeed on
  the packaged app.
- No compiler-warning suppression, linker exclusion, or disabled test is
  introduced to obtain the reduction.

### Verification

```bash
bash -n Scripts/build-app.sh Scripts/measure-distribution-size.sh
./Scripts/build-app.sh 0.0.0-strip-check
./Scripts/measure-distribution-size.sh dist/Countpane.app
lipo -archs dist/Countpane.app/Contents/MacOS/Countpane
xcrun dwarfdump --uuid dist/Countpane.app/Contents/MacOS/Countpane
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
swift test
git diff --check
```

### Commit

```bash
git add Scripts/build-app.sh Scripts/measure-distribution-size.sh .github/workflows/ci.yml .github/workflows/release.yml docs/RELEASE_CHECKLIST.md
git commit -m "perf(package): Strip release binary safely"
```

## P2-2: Publish native architecture-specific DMGs

**Status:** ✅ Completed
**Priority:** P2
**Depends on:** P1-2

### Outcome

Apple Silicon and Intel users download a native app containing one architecture
instead of a Universal binary, while direct downloads and Homebrew continue to
install the correct release automatically.

### Architectural decision

Extend the existing build, DMG, release, and Cask flow; do not create a second
packaging system or release branch. Keep the existing Universal output only if
it is needed as an explicit compatibility artifact with a separately measured
reason; otherwise make the Cask architecture selection the single installer
decision point.

### Files

- Modify `Scripts/build-app.sh`.
- Modify `Scripts/build-dmg.sh`.
- Modify `Scripts/render-cask.sh`.
- Modify `Packaging/Homebrew/countpane.rb.template`.
- Modify `.github/workflows/ci.yml`.
- Modify `.github/workflows/release.yml`.
- Modify `README.md`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Add a validated architecture parameter to existing scripts and create
   deterministic `arm64` and `x86_64` app/DMG names; reject any unsupported
   architecture before deleting or replacing a distribution directory.
2. Build, sign, measure, checksum, upload, and publish both native artifacts
   from the existing tagged release workflow. Preserve semantic tag validation
   and do not make one architecture depend on a Rosetta fallback.
3. Render a Homebrew Cask using Homebrew's supported architecture-conditional
   URL and SHA-256 form, with both checksums generated from that release.
4. Document direct-download selection and retain a clear Universal-build path
   for local testing only when it is still required by CI.
5. Compare each native app and DMG with the P1-2 Universal baseline. Do not
   claim the sum of the two release files as a user download size.

### Acceptance criteria

- An `arm64` DMG installs and runs natively on Apple Silicon, and an `x86_64`
  DMG installs and runs natively on an Intel macOS environment.
- Each native executable reports only its intended architecture; both retain
  the same bundle identifier, version, entitlements, icon quality, app views,
  persistence format, and update behavior as the Universal P1-2 build.
- Homebrew selects the matching URL and SHA-256 on both architectures; an
  unsupported architecture fails before download with Homebrew's normal error.
- Each native app is measurably smaller than the P1-2 Universal app, with the
  target and actual reduction recorded in the release checklist.
- The release retains checksums for every published DMG and does not publish a
  Cask whose URL or hash points to the wrong architecture.

### Verification

```bash
bash -n Scripts/build-app.sh Scripts/build-dmg.sh Scripts/render-cask.sh
./Scripts/build-dmg.sh 0.0.0-arm64 arm64
./Scripts/build-dmg.sh 0.0.0-x86_64 x86_64
./Scripts/measure-distribution-size.sh dist/Countpane-arm64.app dist/Countpane-0.0.0-arm64.dmg
./Scripts/measure-distribution-size.sh dist/Countpane-x86_64.app dist/Countpane-0.0.0-x86_64.dmg
lipo -archs dist/Countpane-arm64.app/Contents/MacOS/Countpane
lipo -archs dist/Countpane-x86_64.app/Contents/MacOS/Countpane
codesign --verify --deep --strict --verbose=2 dist/Countpane-arm64.app
codesign --verify --deep --strict --verbose=2 dist/Countpane-x86_64.app
brew audit --cask --strict dist/countpane.rb
swift test
git diff --check
```

### Commit

```bash
git add Scripts/build-app.sh Scripts/build-dmg.sh Scripts/render-cask.sh Packaging/Homebrew/countpane.rb.template .github/workflows/ci.yml .github/workflows/release.yml README.md docs/RELEASE_CHECKLIST.md
git commit -m "perf(release): Ship native architecture DMGs"
```

## P3-1: Tune lossless DMG compression from measured output

**Status:** ✅ Completed
**Priority:** P3
**Depends on:** P1-2

### Outcome

The release DMG uses the smallest reproducibly buildable lossless compression
setting that materially reduces download size without changing application
contents.

### Architectural decision

Keep the DMG as the existing `hdiutil` UDZO workflow. Compression is a
distribution-container concern only: it must not transcode icons, modify the
signed app, or trade CPU time for negligible saved bytes.

### Files

- Modify `Scripts/build-dmg.sh`.
- Modify `Scripts/measure-distribution-size.sh`.
- Modify `docs/RELEASE_CHECKLIST.md`.

### Work

1. Build DMGs from the same signed P1-2 app using the current setting and
   candidate lossless `hdiutil` compression levels, recording size and wall
   time for each architecture or for the retained Universal baseline.
2. Adopt an explicit setting only if it saves at least 2% or 100 KiB and does
   not increase a clean release packaging run by more than 20%.
3. Keep SHA-256 generation after final DMG creation and mount each candidate
   read-only to validate the app layout before accepting it.
4. Record the selected level, measured delta, and rejection rationale for
   alternatives in the release checklist.

### Acceptance criteria

- Mounted DMGs contain the signed `Countpane.app` and the `/Applications`
  alias, and the installed app has the same byte-level contents as the staged
  signed app except for normal filesystem metadata.
- The selected setting is lossless and meets the declared size/time threshold;
  otherwise the existing setting remains with a documented measurement.
- The generated checksum matches the final published DMG, not a staging or
  pre-compression artifact.
- Icon representation count, icon sharpness, and all application behavior are
  unchanged because no image content was recompressed or resized.

### Verification

```bash
bash -n Scripts/build-dmg.sh Scripts/measure-distribution-size.sh
./Scripts/build-dmg.sh 0.0.0-compression
./Scripts/measure-distribution-size.sh dist/Countpane.app dist/Countpane-0.0.0-compression.dmg
hdiutil verify dist/Countpane-0.0.0-compression.dmg
shasum -a 256 -c dist/Countpane-0.0.0-compression.dmg.sha256
git diff --check
```

### Commit

```bash
git add Scripts/build-dmg.sh Scripts/measure-distribution-size.sh docs/RELEASE_CHECKLIST.md
git commit -m "perf(package): Tune lossless DMG compression"
```

## P2-3: Enforce the accepted size and release regression gates

**Status:** ✅ Completed
**Priority:** P2
**Depends on:** P2-1, P2-2, P3-1

### Outcome

Future releases cannot silently restore duplicate assets, debug bundles, or an
oversized artifact without a deliberate reviewed budget update.

### Architectural decision

The measurement helper remains the one source of size facts. CI enforces the
accepted per-artifact ceilings; release documentation records compatibility and
manual visual/runtime proof rather than duplicating package logic in tests.

### Files

- Modify `Scripts/measure-distribution-size.sh`.
- Modify `.github/workflows/ci.yml`.
- Modify `.github/workflows/release.yml`.
- Modify `docs/RELEASE_CHECKLIST.md`.
- Modify `README.md`.

### Work

1. Set explicit ceilings from the completed measurements for each published
   artifact, executable, and resource payload. Keep tolerance narrow enough to
   catch a duplicated 1 MB icon but documented enough for intentional toolchain
   growth.
2. Make CI fail with the measured offending path and ceiling when a candidate
   exceeds its budget; do not use a blanket file exclusion or suppress the
   failure.
3. Verify the final release workflow publishes only the intended DMG(s),
   checksums, and architecture-aware Cask, with no dSYM or intermediate app
   bundle uploaded.
4. Add a release-checklist visual smoke step for the menu-bar, Dashboard, and
   About icons at native scale on both architectures, plus install/launch
   checks from the final DMG.

### Acceptance criteria

- A deliberate oversized fixture or restored duplicate resource causes the
  size gate to fail and identifies the relevant file in its output.
- A normal clean release build stays within every recorded ceiling, passes
  signature verification, and publishes no debug symbols or staging folders.
- Both native DMGs (or the documented retained Universal artifact) pass final
  install, launch, persistence, widget, import/export, update-settings, and
  sharp-icon smoke checks.
- CI build success is accompanied by artifact-size evidence; a successful
  compilation alone is not treated as distribution-size proof.

### Verification

```bash
bash -n Scripts/measure-distribution-size.sh Scripts/build-app.sh Scripts/build-dmg.sh Scripts/render-cask.sh
swift test
./Scripts/build-app.sh 0.0.0-size-gate
./Scripts/measure-distribution-size.sh dist/Countpane.app
codesign --verify --deep --strict --verbose=2 dist/Countpane.app
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
git diff --check
```

### Commit

```bash
git add Scripts/measure-distribution-size.sh .github/workflows/ci.yml .github/workflows/release.yml docs/RELEASE_CHECKLIST.md README.md
git commit -m "ci(release): Enforce distribution size budget"
```
