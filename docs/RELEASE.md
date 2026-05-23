# Release pipeline — herminal

Steps to ship a Gatekeeper-clean, notarized `.app` that users can
double-click without the "downloaded from the internet" warning.

## One-time setup

### 1. Developer ID Application certificate

Required: a paid Apple Developer Program membership ($99/year).

1. https://developer.apple.com/account/resources/certificates → **+** →
   **Developer ID Application** → create + download the `.cer`.
2. Double-click the downloaded `.cer` to import into the **login**
   keychain.
3. Verify: `security find-identity -p codesigning -v` should list
   `Developer ID Application: <Your Name> (<TEAMID>)`.
4. Export the full common name as the `HERMINAL_SIGNING_IDENTITY` env
   var — example:
   ```sh
   export HERMINAL_SIGNING_IDENTITY="Developer ID Application: Hoang Perry (ABCDE12345)"
   ```

### 2. App-specific password + notarytool keychain profile

notarytool needs Apple to vouch for the submitting account. The
clean path: an app-specific password (not your Apple ID password).

1. https://appleid.apple.com → Sign-In and Security → App-Specific
   Passwords → generate one labelled `herminal-notarize`.
2. Store it once in the keychain so the script never sees it:
   ```sh
   xcrun notarytool store-credentials herminal-notarize \
       --apple-id "you@example.com" \
       --team-id ABCDE12345 \
       --password "xxxx-xxxx-xxxx-xxxx"
   ```
3. Export the profile name:
   ```sh
   export HERMINAL_NOTARY_PROFILE="herminal-notarize"
   ```

### 3. (Recommended) persist the env vars

Add the two `export` lines to `~/.zshrc` or a `.env.local` you source
before running the release script. Don't commit them — the team id is
benign but the convention is to keep signing config out of the repo.

## Cutting a release

```sh
Scripts/sign-and-notarize.sh
```

The script:

1. Runs `Scripts/make-app-bundle.sh release` for a release build.
2. Copies the result into `.build/release/herminal.app`.
3. `codesign` with hardened runtime + `App/herminal.entitlements`.
4. `codesign --verify` + `spctl --assess` sanity check.
5. Zips + submits to `notarytool` with `--wait`.
6. Parses the JSON result — fails loudly if Apple rejected.
7. Staples the ticket back onto the `.app`.

End result: `.build/release/herminal.app` is ready to ship.

## Distribution

Easiest: zip the stapled `.app` and put it behind a download link.

```sh
cd .build/release
ditto -c -k --keepParent herminal.app herminal-$(git rev-parse --short HEAD).zip
```

DMG creation (nicer UX) and Sparkle auto-update are deferred to
post-MVP.

## Troubleshooting

- **`spctl: rejected`** after signing — usually means the entitlements
  granted aren't enough for what libghostty does at runtime. Re-run with
  `--verbose=4` and check Console.app for AMFI / TCC denials.
- **notarytool says "Invalid"** — fetch the log with the command the
  script prints on failure. The common culprits are: unsigned binaries
  inside the bundle (need `--deep`), missing hardened runtime (need
  `--options runtime`), or a nested framework with its own out-of-date
  signature. Use `codesign -dvv --verbose=4` on each binary to spot.
- **First run gets killed by AMFI** — happens when the cdhash recorded
  at signing doesn't match the install location. Don't move or rename
  the `.app` between signing and notarization; if you must rename, re-sign.

## CI / GitHub Actions (post-MVP)

For automated releases we'd want:

- Secrets: `APPLE_DEVELOPER_CERT_P12` (base64 of the exported cert +
  private key), `APPLE_CERT_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`,
  `APPLE_APP_SPECIFIC_PASSWORD`.
- The runner imports the cert into a temporary keychain, stores
  notarytool credentials, runs this script, uploads the signed `.app`.
- Suggested workflow: `.github/workflows/release.yml` triggered on tags
  matching `v*`. Not wired in M5 — owner will add when the project has
  contributors needing pre-built releases.
