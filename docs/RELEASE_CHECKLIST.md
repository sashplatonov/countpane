# Release Checklist

## Automated checks

- [ ] GitHub Actions CI is green on the release commit for both `arm64` and `x86_64`.
- [ ] The release tag uses semantic versioning, for example `v1.2.0`.
- [ ] The release workflow is triggered by an existing immutable tag.
- [ ] DMG, SHA-256 file, and Homebrew Cask are attached to the release.
- [ ] Third-party Actions remain pinned to reviewed commit SHAs.

## Application smoke test

- [ ] Countpane launches from `/Applications`.
- [ ] A countdown can be created, edited, completed, restored, and deleted.
- [ ] Title receives initial keyboard focus in the editor.
- [ ] Desktop widgets open, remain above normal windows, move, and restore their positions.
- [ ] Closing the management window keeps enabled widgets running.
- [ ] Quitting immediately after an edit preserves the latest change.
- [ ] Launch at Login starts enabled widgets without showing the management window.
- [ ] About displays the semantic product version and generated build timestamp.
- [ ] JSON export/import round trip preserves active and completed countdowns.

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
