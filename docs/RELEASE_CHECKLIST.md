# Release Checklist

## Automated checks

- [ ] GitHub Actions CI is green on the release commit for both `arm64` and `x86_64`.
- [ ] The release tag uses semantic versioning, for example `v1.2.0`.
- [ ] The release workflow is triggered by an existing immutable tag.
- [ ] Native arm64 and x86_64 DMGs, both SHA-256 files, and the Homebrew Cask are attached to the release.
- [ ] Third-party Actions remain pinned to reviewed commit SHAs.

## Application smoke test

- [ ] Countpane launches from `/Applications`.
- [ ] Countpane shows a calendar icon in the macOS menu bar and no Dock tile.
- [ ] The menu-bar menu exposes **Show Main Window** and **Quit Countpane** with keyboard-accessible labels.
- [ ] **Show Main Window** opens or reopens the existing management window without duplicating desktop widgets.
- [ ] A countdown can be created, edited, completed, restored, and deleted.
- [ ] Title receives initial keyboard focus in the editor.
- [ ] Keyboard input remains reliable after reopening the management window, and no Dock tile appears.
- [ ] Desktop widgets open, remain above normal windows, move, and restore their positions.
- [ ] Closing the management window keeps enabled widgets running.
- [ ] Quitting immediately after an edit preserves the latest change.
- [ ] Choosing **Quit Countpane** removes the menu-bar icon; relaunching shows the edited countdown still present.
- [ ] Launch at Login starts enabled widgets without showing the management window.
- [ ] About displays the semantic product version and generated build timestamp.
- [ ] JSON export/import round trip preserves active and completed countdowns.

## Resource and battery verification

- [ ] The size report records the app, executable, each resource, and DMG bytes for both architectures.
- [ ] The accepted budgets are respected: Universal app <= 9,000,000 bytes, native app <= 5,400,000 bytes, native executable <= 3,600,000 bytes, and native DMG <= 3,000,000 bytes.
- [ ] `dist/Countpane.dSYM` or the matching native dSYM remains external to the `.app` and DMG, and its UUIDs match the final executable.
- [ ] The packaged app contains exactly one `Contents/Resources/AppIcon.icns`, no `AppIcon.png`, and no SwiftPM resource bundle.
- [ ] The release candidate was measured on AC and battery power; the recorded protocol and results accompany the release review.
- [ ] Raw Instruments traces remain outside the repository and contain no personal countdown data.
- [ ] With no desktop widgets, closing the final management window leaves Countpane available from the menu bar; **Quit Countpane** ends the process cleanly.
- [ ] Automatic-update opt-out produces no automatic release request or Homebrew detection process; manual checking still works.
- [ ] Sleep/wake does not create duplicate widgets, timers, or update requests, and date-derived labels refresh after wake.
- [ ] CPU, energy, memory, disk, network, and process results are recorded separately for `arm64` and `x86_64`, with any measurement gap documented.

## Update verification

- [ ] Automatic update checks can be enabled and disabled.
- [ ] Offline checks fail gracefully and do not affect countdown data.
- [ ] The current release reports “up to date”.
- [ ] An older semantic version discovers the new tag.
- [ ] A DMG installation opens the correct GitHub Release.
- [ ] A Homebrew installation performs an in-app upgrade without freezing the UI.
- [ ] Homebrew unavailable, busy, timed-out, and tap-not-updated states show useful messages.
- [ ] Updating preserves the local JSON file and widget positions.

## Distribution test

- [ ] DMG installs from a clean macOS user account.
- [ ] Gatekeeper behavior matches the release notes.
- [ ] `brew install --cask countpane` succeeds from the public tap.
- [ ] `brew upgrade --cask countpane` upgrades an older installation.
- [ ] `brew uninstall --cask countpane` removes the application cleanly.

## Architecture artifacts

- [ ] `lipo -archs dist/Countpane-arm64.app/Contents/MacOS/Countpane` reports only `arm64`.
- [ ] `lipo -archs dist/Countpane-x86_64.app/Contents/MacOS/Countpane` reports only `x86_64`.
- [ ] The arm64 DMG launches on an Apple Silicon Mac and the x86_64 DMG launches on a supported Intel macOS test environment.
- [ ] Homebrew selects the matching native URL and checksum on both CPU architectures.
- [ ] `codesign -d --entitlements :-` reports the expected entitlements for both native apps.
- [ ] The Universal CI app remains launchable and reports both architectures as a compatibility check.
