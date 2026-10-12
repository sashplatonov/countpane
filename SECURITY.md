# Security Policy

## Supported version

Security fixes are provided for the latest published Countpane release.

## Reporting a vulnerability

Please report security issues privately to **Sash Platonov** through the contact options on [github.com/sashplatonov](https://github.com/sashplatonov). Do not open a public issue until the report has been reviewed.

Include the Countpane product version, build timestamp, macOS version, installation channel, and minimal reproduction steps. Do not attach JSON backups or screenshots containing private countdown titles, dates, or notes unless they have been anonymized.

Countpane stores countdown data locally. Its only normal network operation is an optional read-only request to GitHub's public latest-release link. The app version is included in the request's user agent; countdown data is not sent. Homebrew-based update installation invokes the local Homebrew executable only after explicit user action.
