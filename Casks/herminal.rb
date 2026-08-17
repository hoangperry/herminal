# herminal Homebrew cask formula
#
# Canonical copy of the formula published by hoangperry/homebrew-herminal.
# Keep version, checksum, URL, and install artifact synchronized with that tap.
# Update both copies only after the signed + notarized release asset exists.

cask "herminal" do
  version "1.0.0"
  sha256 "8fd8d833635f712643026bc52f31faf3ad07e4e321f85f8cebe9bae89ea7079f"

  url "https://github.com/hoangperry/herminal/releases/download/v#{version}/herminal-v#{version}.dmg"
  name "herminal"
  desc "AI-native terminal with Vietnamese IME and agent visibility"
  homepage "https://github.com/hoangperry/herminal"

  livecheck do
    url :url
    strategy :github_latest
  end

  # libghostty requires Metal + a modern AppKit; we target Sonoma+ per
  # the PRD. Apple Silicon only — see Package.swift platforms.
  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "herminal.app"

  # Per-user state we'd want zapped on `brew uninstall --zap`. These
  # are the only files herminal writes outside the .app bundle.
  zap trash: [
    "~/Library/Application Support/herminal",
    "~/Library/Preferences/com.hoangperry.herminal.plist",
  ]
end
