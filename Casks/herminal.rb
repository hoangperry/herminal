# herminal Homebrew cask formula
#
# Canonical copy of the formula published by hoangperry/homebrew-herminal.
# Keep version, checksum, URL, and install artifact synchronized with that tap.
# Update both copies only after the signed + notarized release asset exists.

cask "herminal" do
  version "0.4.2"
  sha256 "c989cf627fb6eedc37dbd688dfce85fb2eb47b3a376ba585d0b1bccdcd0864de"

  url "https://github.com/hoangperry/herminal/releases/download/v#{version}/herminal-v#{version}.dmg"
  name "herminal"
  desc "AI-native macOS terminal for Vietnamese developers"
  homepage "https://github.com/hoangperry/herminal"

  # libghostty requires Metal + a modern AppKit; we target Sonoma+ per
  # the PRD. Apple Silicon only — see Package.swift platforms.
  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  livecheck do
    url :url
    strategy :github_latest
  end

  app "herminal.app"

  # Per-user state we'd want zapped on `brew uninstall --zap`. These
  # are the only files herminal writes outside the .app bundle.
  zap trash: [
    "~/Library/Application Support/herminal",
    "~/Library/Preferences/com.hoangperry.herminal.plist",
  ]
end
