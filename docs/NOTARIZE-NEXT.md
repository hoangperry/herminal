# Notarize v0.1.0 — owner action sheet

App is already Developer-ID signed with the NEW GENERATION AI cert
as of 2026-05-26. Notarization is the missing step that flips
Gatekeeper from "Unnotarized Developer ID — rejected" to silent.

This file captures the exact commands the owner runs once an
app-specific password is created. Three steps. ~10 minutes total
(most of it Apple's notary queue waiting).

---

## Prerequisites the owner needs to gather first

1. **Apple ID email** — the one tied to the Developer Program
   account for NEW GENERATION ARTIFICIAL INTELLIGENCE JOINT STOCK
   COMPANY (TeamID `JP4XV8A9JF`).

2. **App-specific password** — generate one fresh for this purpose:
   - Go to https://appleid.apple.com
   - Sign in → Sign-In and Security → App-Specific Passwords
   - Click `+ Generate Password`
   - Label: `herminal-notarize` (or any label; only you see it)
   - Apple will display a `xxxx-xxxx-xxxx-xxxx` password once.
     Copy it now — they don't show it again.

3. **Team ID** — already known: `JP4XV8A9JF`. No action needed.

---

## Step 1 — store the credentials in the keychain (one-time)

```sh
xcrun notarytool store-credentials herminal-notarize \
    --apple-id "YOUR_APPLE_ID@example.com" \
    --team-id JP4XV8A9JF \
    --password "xxxx-xxxx-xxxx-xxxx"
```

Replace `YOUR_APPLE_ID@example.com` and the password placeholder
with your real values. Apple keeps the credentials in the macOS
keychain under the profile name `herminal-notarize`; subsequent
notarize runs only need the profile name, not the credentials.

---

## Step 2 — re-run the signing + notarize pipeline

```sh
cd /Users/hoangtruong/pet-project/herminal
export HERMINAL_SIGNING_IDENTITY="Developer ID Application: NEW GENERATION ARTIFICIAL INTELLIGENCE JOINT STOCK COMPANY (JP4XV8A9JF)"
export HERMINAL_NOTARY_PROFILE="herminal-notarize"
Scripts/sign-and-notarize.sh
```

What the script will do (visible as it runs):

1. Build the release bundle.
2. Re-sign with the Developer-ID cert (same as before).
3. Zip the bundle and submit to Apple's notary service with
   `--wait` — this blocks until Apple responds, typically 3-10
   minutes. You'll see periodic status updates from notarytool.
4. Parse the JSON result. If Apple says `Invalid`, the script
   exits non-zero and prints the command to fetch the rejection
   log. (Most common rejection reason: a nested binary inside the
   `.app` bundle isn't signed — solvable with `codesign --deep`,
   which the script already uses.)
5. Staple the notarization ticket onto the `.app` so future
   launches don't need network access to verify.

End state: `.build/release/herminal.app` is fully notarized.

---

## Step 3 — re-package the notarized bundle + update the GitHub release

```sh
# Re-zip the notarized bundle:
cd .build/release
rm -f herminal-v0.1.0.zip
ditto -c -k --keepParent herminal.app herminal-v0.1.0.zip

# Re-build the DMG with the notarized bundle:
cd /Users/hoangtruong/pet-project/herminal
Scripts/make-dmg.sh 0.1.0

# Upload the notarized assets to the v0.1.0 draft release:
gh release upload v0.1.0 \
    .build/release/herminal-v0.1.0.zip \
    .build/release/herminal-v0.1.0.dmg \
    --clobber
```

`--clobber` replaces the existing signed-but-not-notarized assets
with the notarized versions.

---

## Step 4 (optional) — verify Gatekeeper accepts the notarized bundle

```sh
spctl --assess --type execute --verbose=4 .build/release/herminal.app
# Expected: "...: accepted"  (was "rejected: Unnotarized Developer ID")

# Stapled ticket check:
xcrun stapler validate .build/release/herminal.app
# Expected: "The validate action worked!"
```

If both pass, the bundle is genuinely Gatekeeper-clean. Users
downloading will see no warning at all.

---

## Step 5 — publish the v0.1.0 release

After notarization completes and assets are uploaded, the draft
release is ready to flip to public:

```sh
gh release edit v0.1.0 --draft=false
```

Or via the GitHub UI: open the release page, click "Publish release".

---

## Where this state lives today

- **Signed (Developer-ID, NEW GENERATION AI):** ✅
  - `.build/release/herminal.app` — signed locally
  - `.build/release/herminal-v0.1.0.zip` (5.95 MB) — signed, on GitHub
  - `.build/release/herminal-v0.1.0.dmg` (6.12 MB) — signed, on GitHub
- **Hardened runtime enabled:** ✅ (`flags=0x10000(runtime)`)
- **Notarized:** ❌ (waiting on Step 1's app-specific password)
- **Stapled:** ❌ (waits on notarization)
- **Gatekeeper status:** "Unnotarized Developer ID — rejected"
- **User-visible behaviour today:** download → "downloaded from
  internet" warning on first launch → user clicks Open Anyway →
  subsequent launches silent

After Steps 1-5 the user-visible behaviour becomes: download →
silent launch.

---

## If notarization fails

The most common failure mode is a nested binary inside libghostty
not having `--options runtime`. `sign-and-notarize.sh` runs
`codesign --deep --options runtime` so the standard case should
work, but if Apple rejects:

```sh
# Fetch the rejection log (replace SUBMISSION_ID with the value
# the script printed before exiting):
xcrun notarytool log SUBMISSION_ID --keychain-profile herminal-notarize
```

The log JSON names each binary that failed validation. Fix the
ones it lists (usually by re-signing them with `--options runtime`)
and re-run Step 2.

The four hardened-runtime entitlements in
`App/herminal.entitlements` are documented per-flag with the reason
libghostty needs them. If Apple ever rejects an entitlement claim,
remove the claim and re-test in a debug build first.
