# Release Checklist

## Automated checks

- [ ] GitHub Actions CI is green on the release commit for both `arm64` and `x86_64`.
- [ ] The release tag uses semantic versioning, for example `v1.2.0`.
- [ ] The release workflow is triggered by an existing immutable tag.
- [ ] DMG, SHA-256 file, and Homebrew Cask are attached to the release.
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

- [ ] The release candidate was measured with the protocol in `docs/resource-efficiency-baseline.md` on AC and battery power.
- [ ] Raw Instruments traces remain outside the repository and contain no personal countdown data.
- [ ] The no-widget scenario exits after the final management window closes; the widget-only scenario keeps enabled widgets alive.
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

## Universal Binary

- [ ] `lipo -archs dist/Countpane.app/Contents/MacOS/Countpane` reports both `arm64` and `x86_64`.
- [ ] The same DMG launches on an Apple Silicon Mac.
- [ ] The same DMG launches on a supported Intel Mac or Intel macOS test environment.
- [ ] `codesign -d --entitlements :- dist/Countpane.app` reports the expected entitlements.
