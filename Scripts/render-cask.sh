#!/bin/bash
set -euo pipefail

if (( $# != 5 )); then
    echo "Usage: $0 <version> <arm64-sha256> <x86_64-sha256> <github-repository> <output-file>" >&2
    exit 64
fi

VERSION="$1"
ARM_SHA256="$2"
INTEL_SHA256="$3"
REPOSITORY="$4"
OUTPUT="$5"
mkdir -p "$(dirname "$OUTPUT")"
cat > "$OUTPUT" <<CASK
cask "countpane" do
  version "${VERSION}"

  on_macos do
    on_arm do
      url "https://github.com/${REPOSITORY}/releases/download/v#{version}/Countpane-#{version}-arm64.dmg"
      sha256 "${ARM_SHA256}"
    end
    on_intel do
      url "https://github.com/${REPOSITORY}/releases/download/v#{version}/Countpane-#{version}-x86_64.dmg"
      sha256 "${INTEL_SHA256}"
    end
  end
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
