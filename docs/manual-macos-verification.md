# Manual macOS Verification

These checks require a physical macOS 15+ machine and a packaged
`Countpane.app`. They are evidence for native runtime behavior; `swift test`
and GitHub Actions do not replace them.

## Preparation

1. Build a local app and open it:

   ```bash
   ./Scripts/build-app.sh 0.0.0-manual arm64
   open dist/Countpane.app
   ```

2. Use synthetic entries such as `Trip`, `Launch`, and `Birthday`. Do not use
   personal countdown titles, dates, notes, screenshots, or backup files.

## Lifecycle and data

- Confirm the app appears only in the menu bar and **Show Main Window** opens a
  single management window.
- Close and reopen the management window repeatedly; verify one click closes it
  and its saved frame remains stable.
- Create, edit, save, cancel, and discard an entry. Confirm the unsaved-changes
  prompt appears only when data changed.
- Export a synthetic JSON backup, import it, cancel the replacement prompt, then
  import and confirm replacement. Try an oversized/invalid fixture and confirm
  the existing list remains unchanged.
- Enable Launch at Login, restart, and verify enabled widgets restore without
  unexpectedly opening the management window.

## Widgets and displays

- Show multiple widgets, drag each one, close one with its close control, and
  reopen it from the countdown row.
- Move widgets across two displays and Spaces; verify they remain above normal
  windows and do not block fullscreen auxiliary content unexpectedly.
- Disconnect the display containing a widget, reconnect it, and verify the
  widget is rehomed inside a visible screen and the close control is reachable.

## Accessibility and appearance

- Navigate sidebar, filters, search, editor, menus, and save/cancel controls with
  keyboard only; verify visible focus and no control requires a pointer.
- Run VoiceOver and confirm active cards expose title, duration, urgency, and
  progress; the widget close action is announced as **Hide desktop widget**.
- Test System, light, dark, and high-contrast settings plus increased text size.
- Enable Reduce Motion and confirm urgency pulse animation is suppressed.

## Installation evidence

- Mount a release DMG, verify it contains `Countpane.app` and the Applications
  alias, copy the app to Applications, and launch it.
- Record Gatekeeper behavior separately. The current project intentionally does
  not claim Developer ID signing or notarization.

Record date, macOS version, architecture, and pass/fail notes in the release
checklist. Never commit private runtime data or unredacted screenshots.
