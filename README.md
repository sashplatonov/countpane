<a id="top"></a>

# Countpane

**Keep the dates that matter visible, without filling your calendar.**

Countpane is a private, native Mac app for deadlines, anniversaries, trips, launches, and every other date you do not want to lose track of. Create a countdown once, then keep it on your desktop as a small, always-visible widget while you work.

<a id="table-of-contents"></a>

## Table of contents

- [Install with Homebrew](#install-with-homebrew)
- [Why Countpane](#why-countpane)
- [What you can do](#what-you-can-do)
- [Get started](#get-started)
- [Privacy and backups](#privacy-and-backups)
- [Updates](#updates)
- [Build from source](#build-from-source)
- [Releases and quality](#releases-and-quality)
- [Security and license](#security-and-license)

## ⚡ Install with Homebrew

Install Countpane with:

```bash
brew tap sashplatonov/apps
brew install --cask countpane
```

Then open **Countpane** from Applications. To update later:

```bash
brew update
brew upgrade --cask countpane
```

[↑ Back to top](#top)

![Countpane app preview](docs/app-preview.png)

## ✨ Why Countpane

Calendars are excellent for appointments. Countpane is for the dates you want to keep in view between appointments: a visa deadline, a birthday, a move, a product launch, or a long-awaited trip.

- Keep upcoming dates visible in independent, rounded desktop widgets.
- See the remaining time in plain language, from days to years and months.
- Work privately: no account, cloud sync, analytics, or server is required.
- Focus on what is next with search, pinning, sorting, and a dedicated **Next Up** view.

[↑ Back to top](#top)

## 🧩 What you can do

- Create active and completed countdowns with notes, symbols, and individual themes.
- Choose compact Rows or a responsive Card Grid for the main dashboard.
- Show or hide a floating widget for each active countdown.
- Set urgency stages so approaching dates are easy to spot.
- Pin important items, shift dates quickly, mark items complete, restore them, or undo the last change.
- Start Countpane at login and show widgets without opening the main window.
- Use light, dark, or adaptive application themes.
- Export a backup before moving to another Mac, then import it when needed.

[↑ Back to top](#top)

## 🚀 Get started

1. Open Countpane and select **Add Countdown**.
2. Give it a title and target date; add a note, symbol, or colour if helpful.
3. Enable its desktop widget to keep the countdown visible above other windows.
4. In Settings, adjust urgency stages, appearance, Launch at Login, and automatic update checks.
5. Use **Export** in Settings before changing Macs or making a major edit to your list.

[↑ Back to top](#top)

## 🔒 Privacy and backups

Your countdowns stay on your Mac at:

```text
~/Library/Application Support/Countpane/countpane.json
```

Countpane has no account or analytics service. Automatic update checks are optional; they query the public GitHub Releases API and send only the product version. Titles, dates, notes, and backup files are never transmitted.

Backups use Countpane's current versioned JSON format. Import checks the format, duplicate identifiers, required titles, and urgency settings before replacing the local list. Unsupported or older backup formats are rejected rather than changed silently.

📝 Keep exported backups somewhere you control, such as an encrypted drive or your own private cloud folder.

[↑ Back to top](#top)

## 🔄 Updates

Countpane can check for a new version automatically or when you ask it to. For a Homebrew installation, **Install Update** runs a bounded Homebrew update outside the app's interface. For a DMG installation, Countpane opens the newest release page.

If Homebrew is unavailable, the tap has not propagated yet, the network is offline, or GitHub rate-limits a request, Countpane explains the problem without exposing your data.

[↑ Back to top](#top)

## 🛠️ Build from source

Requirements: macOS 15+ and Xcode 16+.

```bash
git clone https://github.com/sashplatonov/countpane.git
cd countpane
swift test
./Scripts/build-app.sh 1.0.0
open dist/Countpane.app
```

Build a local DMG:

```bash
./Scripts/build-dmg.sh 1.0.0
```

[↑ Back to top](#top)

## ✅ Releases and quality

GitHub Actions runs the test suite natively on Apple Silicon and Intel Macs. A semantic tag such as `v1.0.0` builds a Universal app, creates a DMG and checksum, publishes a GitHub Release, and generates the Homebrew cask.

```bash
git tag v1.0.0
git push origin v1.0.0
```

Packaging uses Hardened Runtime and ad-hoc signing. A Developer ID certificate and Apple notarization are still required for distribution without Gatekeeper prompts; until they are configured, DMG and Homebrew distribution are experimental.

For release maintainers, see the [release checklist](docs/RELEASE_CHECKLIST.md).

[↑ Back to top](#top)

## 🛡️ Security and license

Report vulnerabilities privately according to [SECURITY.md](SECURITY.md). Never attach unredacted backups to a public issue.

Countpane is available under the [MIT License](LICENSE).

[↑ Back to top](#top)
