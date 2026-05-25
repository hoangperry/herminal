# herminal Homebrew cask formula
#
# `brew install --cask herminal` is the intended install path for end
# users once we ship a notarized .app + a tap (homebrew-cask submission
# follows once we have ≥1 month of stable releases per their policy).
#
# Lives in the repo for two reasons:
#   1. Self-documenting — anyone reading the source knows what shape the
#      cask will take when published.
#   2. Reusable as the starting point for our own tap (hoangperry/tap)
#      and the eventual upstream submission to homebrew-cask.
#
# Update flow per release:
#   1. Bump `version` to the new tag (without the `v` prefix).
#   2. Update `sha256` — `shasum -a 256 herminal-vX.Y.Z.zip` after the
#      signed bundle lands in the GitHub release.
#   3. Tap-side: `brew bump-cask-pr` will do both of the above.

cask "herminal" do
  version "0.1.0"
  # PLACEHOLDER — replace once the v0.1.0 notarized bundle is up.
  # `brew style --fix` will normalise the format.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/hoangperry/herminal/releases/download/v#{version}/herminal-v#{version}.zip"
  name "herminal"
  desc "AI-native macOS terminal for Vietnamese developers"
  homepage "https://github.com/hoangperry/herminal"

  # libghostty requires Metal + a modern AppKit; we target Sonoma+ per
  # the PRD. Apple Silicon only — see Package.swift platforms.
  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  # The release zip contains `herminal.app` at the root (per
  # Scripts/release.sh `ditto -c -k --keepParent`).
  app "herminal.app"

  # Per-user state we'd want zapped on `brew uninstall --zap`. These
  # are the only files herminal writes outside the .app bundle.
  zap trash: [
    "~/Library/Application Support/herminal",
    "~/Library/Preferences/com.hoangperry.herminal.plist",
  ]
end
