# Sparkle auto-update — integration handoff

**Status:** wiring point in place (`Sources/HerminalApp/Updater.swift`
stub + `docs/appcast-template.xml`), Homebrew tap live, notarization
pipeline proven. Sparkle itself is NOT yet wired — this doc is the
exact next-step so it's a focused change, not a from-zero refactor.

**Why it's not auto-landed:** two hard constraints make Sparkle a
deliberate, owner-in-the-loop step rather than a silent commit:

1. **It can break the green release pipeline.** Sparkle ships as a
   dynamic framework with bundled XPC services + helper apps
   (`Autoupdate`, `Updater.app`, `Downloader.xpc`, `Installer.xpc`).
   Our `Scripts/make-app-bundle.sh` is hand-rolled and currently
   embeds *no* frameworks (everything is static). Embedding Sparkle
   wrong = the app fails to launch (dyld can't resolve
   `@rpath/Sparkle.framework`) or notarization rejects unsigned
   nested code. That would ship a broken DMG to the brew users we
   just enabled.
2. **The EdDSA signing key is a secret only the owner can hold.**
   Sparkle refuses updates without a `SUPublicEDKey` in Info.plist
   and a valid `sparkle:edSignature` on each appcast item. The
   private key must never enter the repo or this transcript.

So: this is sequenced like notarization was — wire everything, owner
runs the one-time secret step.

---

## Step 0 — one-time: generate the EdDSA key (owner, secret)

Sparkle ships `generate_keys`. Get it once (via the SPM checkout or
the release zip from <https://github.com/sparkle-project/Sparkle/releases>):

```sh
./bin/generate_keys
```

It prints a **public** key (goes in Info.plist, safe) and stores the
**private** key in the login Keychain (never leaves the machine).
Copy the public key string — that's `SUPublicEDKey`.

To re-print the public key later: `./bin/generate_keys -p`.

---

## Step 1 — add the dependency (Package.swift)

```swift
// dependencies:
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),

// HerminalApp target dependencies:
.product(name: "Sparkle", package: "Sparkle"),
```

`swift build` will pull Sparkle as a binary xcframework. Note where it
lands: `swift build --show-bin-path` → there'll be a
`Sparkle.framework` alongside. Confirm before touching the bundle
script:

```sh
swift build -c release --product HerminalApp
find "$(swift build -c release --product HerminalApp --show-bin-path)" -name "Sparkle.framework" -maxdepth 2
```

---

## Step 2 — embed + sign the framework (make-app-bundle.sh)

After copying the binary, before the final codesign, add framework
embedding. Sparkle's nested code must be signed inside-out (helpers
first, then the framework, then the app), each with hardened runtime:

```sh
FW_SRC="$BIN_DIR/Sparkle.framework"      # from --show-bin-path
FW_DST="$APP/Contents/Frameworks/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
cp -R "$FW_SRC" "$FW_DST"

# Sign nested helpers inside-out (paths per Sparkle 2.x layout).
SIGN="codesign --force --options runtime --timestamp --sign \"$IDENTITY\""
for nested in \
  "Versions/B/XPCServices/Downloader.xpc" \
  "Versions/B/XPCServices/Installer.xpc" \
  "Versions/B/Autoupdate" \
  "Versions/B/Updater.app"; do
  [ -e "$FW_DST/$nested" ] && eval $SIGN "\"$FW_DST/$nested\""
done
eval $SIGN "\"$FW_DST\""
# Then the main app last (existing sign-and-notarize.sh step), which
# must use --options runtime + the same identity. The app picks up
# Sparkle via @executable_path/../Frameworks (SwiftPM sets the rpath).
```

`sign-and-notarize.sh` already does the final app sign + notarize —
just make sure the Frameworks dir exists before it runs (i.e. embed in
`make-app-bundle.sh`, sign nested there or in `sign-and-notarize.sh`).
Verify: `codesign --verify --deep --strict .build/release/herminal.app`
then notarize as usual. **If notarization rejects nested code, fix the
sign order before shipping — do not staple a half-signed bundle.**

---

## Step 3 — replace the Updater stub (Updater.swift)

```swift
import Sparkle

@MainActor
final class Updater {
    static let shared = Updater()
    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
```

- AppDelegate `applicationDidFinishLaunching`: `_ = Updater.shared`
  (starts scheduled checks). Drop the old stub call.
- AppMenu: add a **"Check for Updates…"** item in the app menu
  targeting `#selector(...)` that calls `Updater.shared.checkForUpdates()`.

---

## Step 4 — Info.plist keys (App/Info.plist)

```xml
<key>SUFeedURL</key>
<string>https://hoang.tech/herminal/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>PASTE_PUBLIC_KEY_FROM_STEP_0</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

Host the appcast on the site (`docs/site/appcast.xml`) — it
auto-deploys via `pages.yml` to `hoang.tech/herminal/appcast.xml`.
(Use the site, not `releases/latest/download/appcast.xml`: the
latter 404s until an asset named exactly `appcast.xml` is attached,
and the site path is stable + already HTTPS.)

> Update `Sources/HerminalApp/Updater.swift`'s `appcastURL` to the
> site path to match.

---

## Step 5 — per-release: sign the update + update the appcast

After `sign-and-notarize.sh` produces the notarized DMG:

```sh
./bin/sign_update .build/release/herminal-vX.Y.Z.dmg
# → prints: sparkle:edSignature="..." length="..."
```

Add an `<item>` to `docs/site/appcast.xml` (template at
`docs/appcast-template.xml`) with: title = X.Y.Z, the DMG `<enclosure
url>`, the `sparkle:edSignature` + `length` from `sign_update`,
`sparkle:version` = CFBundleVersion, `sparkle:shortVersionString` =
X.Y.Z, `minimumSystemVersion` = 14.0, and the changelog block as the
`<description>`. Commit → push → site redeploys → Sparkle sees it.

Fold this into `Scripts/release.sh` so every release regenerates the
appcast entry automatically.

---

## Verification checklist (before announcing auto-update works)

- [ ] `codesign --verify --deep --strict` passes on the embedded build
- [ ] `spctl --assess --type execute` accepts the notarized bundle
- [ ] App launches (no dyld `Sparkle.framework` error in Console)
- [ ] "Check for Updates…" against an appcast advertising a *higher*
      version shows the update prompt
- [ ] Installing the update from the prompt succeeds + relaunches
- [ ] The Homebrew cask + Sparkle coexist (brew-installed app can
      still self-update; document which path "wins" in FAQ)

---

## Why the order is: tap → Sparkle (not the reverse)

Homebrew users `brew upgrade --cask herminal` for updates; Sparkle is
for direct-download users. The tap shipped first (zero secret, zero
pipeline risk, done + audited). Sparkle is the direct-download
retention path — worth it, but it's the heavier lift with the
owner-gated key, so it's sequenced second and gated on a real
decision rather than rushed.
