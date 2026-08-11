# Countpane Release Checklist

This checklist describes the current release path. It does not claim Apple
Developer ID signing or notarization; the current DMGs use Hardened Runtime and
ad-hoc signing.

## Before tagging

- [ ] Confirm the working tree is clean and the intended commit is on the
      release branch.
- [ ] Review user-visible changes and synthetic screenshots for private data.
- [ ] Run `swift package dump-package` and `swift test`.
- [ ] Run `bash -n Scripts/*.sh` and `plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements`.
- [ ] Run `gitleaks detect --source . --no-git --redact` and the history scan.
- [ ] Confirm `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, and this checklist
      make no unsupported distribution claims.

## Build and verify

- [ ] Build native arm64 and x86_64 DMGs with `Scripts/build-dmg.sh`.
- [ ] Confirm executable architectures, resource presence, dSYM UUID matching,
      code-signature verification, and configured size budgets.
- [ ] Run `hdiutil verify` for each DMG.
- [ ] Mount each DMG and confirm it contains only the expected `Countpane.app`
      and `/Applications` alias; detach the image afterwards.
- [ ] Confirm each `.sha256` file matches its DMG.

## Publish

- [ ] Push the semantic tag and confirm the release workflow completes for both
      native architectures.
- [ ] Confirm the GitHub Release contains both DMGs, checksums, and the rendered
      architecture-aware cask.
- [ ] Confirm the Homebrew tap cask has matching version, URLs, and SHA-256.
- [ ] Record the remote workflow URL and release URL in the handoff.

## Physical Mac checks

- [ ] Follow [manual-macos-verification.md](manual-macos-verification.md) on a
      clean macOS 15+ machine.
- [ ] Test menu-bar reopening, editor dismissal, import failure, widgets,
      multiple displays, VoiceOver, Reduce Motion, and Dark Mode.
- [ ] Record Gatekeeper behavior separately; do not describe ad-hoc builds as
      notarized or trusted.

## Data removal warning

Homebrew cask `zap` removes Countpane's Application Support directory. Verify a
backup exists before uninstalling with zap.
