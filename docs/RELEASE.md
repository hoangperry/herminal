# Release pipeline — herminal

Steps to ship a Developer-ID signed, notarized, and stapled `.app`, ZIP, and
DMG that Gatekeeper accepts. Public release paths fail closed when signing or
notarization configuration is absent; ad-hoc bundles are development artifacts
only.

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

## Check owner prerequisites

```sh
export HERMINAL_SIGNING_IDENTITY="Developer ID Application: …"
export HERMINAL_NOTARY_PROFILE="herminal-notarize"
Scripts/check-release-readiness.sh
# Optional authenticated network check:
Scripts/check-release-readiness.sh --online-notary-check
```

The checker prints capability outcomes only—not identity/profile values. It
signs a temporary copy of `/usr/bin/true` to catch locked or unusable private
keys before an expensive build.

## Verify the release guards

```sh
Scripts/verify-release-guards.sh
Scripts/verify-owner-gate-tools.sh
```

This check proves the local release driver refuses missing signing/notary
configuration and that pretty-printed notarytool JSON is parsed correctly. CI
runs it before the expensive native build.

## Cutting a release locally

Prepare the changelog, export both owner-held variables, and run:

```sh
Scripts/release.sh 1.0.0
```

The driver runs the dogfood gate, builds through
`Scripts/sign-and-notarize.sh`, then independently verifies the Developer ID
signature, stapled ticket, and Gatekeeper assessment before creating a local
annotated tag. It never pushes the tag or publishes a release.

`Scripts/sign-and-notarize.sh` supports ad-hoc output for developer smoke tests;
that output cannot pass `Scripts/release.sh` and must never be uploaded as a
public release.

## GitHub Actions release

Pushing an existing `vX.Y.Z` tag (or manually dispatching the Release workflow
for one) checks out that exact tag, imports the certificate into an ephemeral
keychain, signs, notarizes, staples, packages ZIP + DMG, generates
`SHA256SUMS` and `dependency-manifest.txt`, and creates or refreshes a **draft**
GitHub release. A maintainer reviews and publishes the draft.

Required repository secrets:

- `APPLE_DEVELOPER_CERT_P12`
- `APPLE_CERT_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Missing values stop the workflow; it does not fall back to an ad-hoc artifact.
Homebrew is updated only after the final public DMG URL and SHA-256 exist.

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

## Final owner checklist

```sh
codesign --verify --deep --strict .build/release/herminal.app
xcrun stapler validate .build/release/herminal.app
spctl --assess --type execute --verbose=4 .build/release/herminal.app
shasum -a 256 .build/release/herminal-v1.0.0.dmg
```

Also verify a clean DMG install and Homebrew installation on a machine/account
that did not build the artifact. Keep credentials and complete command output
containing local paths out of issues and agent prompts.
