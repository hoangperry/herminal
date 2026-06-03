// Updater — Sparkle integration stub for auto-update.
//
// Sparkle isn't wired into v0.1.0 — we haven't shipped enough releases
// to justify the dependency, and Apple's notarisation workflow needs
// to be exercised end-to-end first. This file is the "wiring point"
// so when v0.2.x adds Sparkle proper, the AppDelegate hook + the
// appcast URL contract are already in place.
//
// Why land the stub now: PRD M7 retro Theme E sequences Distribution
// as (notarized release) → (Homebrew cask) → (Sparkle). The Homebrew
// cask formula landed in M10/E-brew; this is the Sparkle peer so the
// roadmap can show concrete groundwork instead of "TODO". Adding the
// real Sparkle.framework + delegate methods then becomes a focused
// change rather than a from-zero refactor.
//
// The appcast template lives at `docs/appcast-template.xml`. When the
// owner cuts v0.2.0 the release.sh script (M10/E-cd) regenerates it
// with the real version + signature.
//
// FULL INTEGRATION STEPS: docs/SPARKLE-NEXT.md — SPM dep, framework
// embedding + signing into the hand-rolled bundle, Info.plist keys,
// the owner-gated EdDSA key-gen, and the per-release appcast signing.
// Sequenced AFTER the Homebrew tap (shipped + audited) because Sparkle
// carries pipeline risk + a secret signing key.

import Foundation

/// Stub auto-updater. Production implementation will own a Sparkle
/// `SPUStandardUpdaterController` and route its delegate callbacks to
/// the Diary so we can correlate update events with crash reports.
///
/// For v0.1.0 the only public surface is `currentVersion` and
/// `appcastURL` so the rest of the codebase can already reason about
/// "where would I check for updates" without taking on the dependency.
public enum Updater {
    /// Read from Info.plist at runtime — single source of truth.
    /// Stays in sync with whatever Scripts/make-app-bundle.sh writes.
    public static var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        return short ?? build ?? "0.0.0"
    }

    /// Appcast XML published alongside each GitHub release. Sparkle
    /// fetches this on the user's schedule, compares against
    /// `currentVersion`, and prompts when a newer signed release
    /// exists. URL contract: the file lives next to the release zip
    /// at a stable path so the cask formula + Sparkle both point at
    /// the same target.
    public static let appcastURL = URL(
        string: "https://github.com/hoangperry/herminal/releases/latest/download/appcast.xml"
    )!

    /// Production hook — call from `applicationDidFinishLaunching` to
    /// kick off Sparkle's scheduled check. Currently a no-op so the
    /// call site is already in place when the dependency lands.
    public static func startScheduledUpdateChecks() {
        // SPUStandardUpdaterController(startingUpdater: true,
        //                              updaterDelegate: nil,
        //                              userDriverDelegate: nil)
        // The controller registers itself with the active updater
        // instance — no need to hold the reference once configured.
        //
        // Until Sparkle is added as a SPM dependency we log the call
        // through the Diary so dogfood owners can see the lifecycle
        // hook fires (or doesn't) without grepping for "Sparkle".
        Diary.shared.log("Updater stub — scheduled check would fire here (Sparkle not yet integrated)",
                         category: "updater")
    }
}
