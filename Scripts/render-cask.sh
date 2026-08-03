#!/bin/bash
set -euo pipefail

if (( $# != 4 )); then
    echo "Usage: $0 <version> <sha256> <github-repository> <output-file>" >&2
    exit 64
fi

VERSION="$1"
SHA256="$2"
REPOSITORY="$3"
OUTPUT="$4"
mkdir -p "$(dirname "$OUTPUT")"
cat > "$OUTPUT" <<CASK
cask "countpane" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${REPOSITORY}/releases/download/v#{version}/Countpane-#{version}.dmg"
  name "Countpane"
  desc "Native countdown manager with always-on-top desktop widgets"
  homepage "https://github.com/${REPOSITORY}"

  depends_on macos: :sequoia

  app "Countpane.app"

  zap trash: [
    "~/Library/Application Support/Countpane",
    "~/Library/Preferences/com.sashplatonov.countpane.plist",
    "~/Library/Saved Application State/com.sashplatonov.countpane.savedState",
  ]
end
CASK

echo "Rendered $OUTPUT"
