# Changelog

All notable changes to Countpane are documented here. Public releases use semantic versioning; each application build also displays an automatically generated `yyyyMMdd-HHmm` build timestamp.

## Unreleased

### Fixed

- Moved `SidebarButtonStyle` to the shared UI module so the extracted sidebar view can access it.
- Passed the themed foreground color explicitly to `CircularCount`, removing an invalid out-of-scope `theme` reference.

### Added

- Versioned and validated JSON import/export.
- Universal Binary packaging for Apple Silicon and Intel.
- Explicit entitlements and Hardened Runtime packaging.
- In-app update center backed by GitHub Releases.
- Optional automatic update checks with a privacy explanation.
- Homebrew installation-channel detection and explicit in-app upgrades.
- Dedicated tests for semantic versions, release decoding, updater state, Homebrew failures, and process timeouts.
- Security policy and expanded release verification checklist.

### Changed

- Compare product releases with semantic versions instead of build timestamps.
- Keep the generated timestamp as build metadata shown in About.
- Run Homebrew detection and upgrades outside the main actor.
- Capture command output through a temporary file with timeout and cancellation support.
- Test tagged releases natively on both ARM and Intel runners.
- Pin third-party GitHub Actions to verified commit SHAs.
- Document the updater network boundary and local-data privacy behavior.

### Fixed

- Prevent UI stalls caused by synchronous Homebrew checks.
- Prevent pipe-buffer deadlocks during verbose Homebrew commands.
- Preserve pending countdown changes during application termination.
- Exclude pinned items from Next Up without hiding the entire banner.

## 1.0.0 - 2026-08-03

### Added

- Native macOS 15 countdown management dashboard.
- Independent rounded always-on-top desktop widgets.
- Human-readable durations and configurable urgency stages.
- Light and dark application themes plus per-countdown themes.
- Search, sorting, pinning, quick date shifts, undo, and login startup.
- Custom countdown editor and calendar.
- About window with automatic build timestamp.
- Swift Testing coverage for domain, persistence, model, widget, and startup behavior.
- GitHub Actions, DMG packaging, GitHub Releases, and Homebrew Cask generation.

### UI polish

- Removed opaque black pixels from the application icon corners and regenerated icon resources.
- Disabled native rectangular focus halos for Countpane custom controls.
- Fixed the countdown editor title row so the icon stays compact and the title uses the remaining width.
- Removed the duplicated dashboard layout setting from Settings.
- Replaced the native Sort menu with a themed Countpane popover selector.
