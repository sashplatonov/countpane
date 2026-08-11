# Contributing to Countpane

Countpane is a Swift Package Manager macOS application. Keep changes focused
on the local-first product and preserve the existing SwiftUI/AppKit and SQLite
boundaries.

## Local checks

Run the full test suite before opening a pull request:

```bash
swift package dump-package >/dev/null
swift test
bash -n Scripts/*.sh
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
git diff --check
```

For a packaged app or DMG, use the existing scripts:

```bash
./Scripts/build-app.sh 0.0.0-local arm64
./Scripts/build-dmg.sh 0.0.0-local arm64
```

The packaging scripts perform architecture, signing, dSYM, DMG integrity, and
install-layout checks. A local ad-hoc signature is expected until a future
release explicitly adds trusted distribution credentials.

## Data and privacy

- Use temporary SQLite databases and synthetic countdowns in tests.
- Never commit personal JSON backups, SQLite files, screenshots, credentials,
  or unredacted logs.
- Keep the no-account, no-cloud, no-analytics product model intact.
- Import/export behavior must remain versioned, bounded, and transactional.

## Pull requests

Describe the user-visible behavior, affected files, verification commands, and
any manual macOS checks that remain. Separate local proof from remote CI and
physical-device proof. Do not claim notarization, Gatekeeper approval, or a
successful remote release run without evidence from that environment.

## Release maintenance

Release maintainers should follow [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).
