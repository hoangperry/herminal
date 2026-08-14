# Vietnamese IME live-input evidence — partial

- Date: 2026-08-15
- App: Developer-ID signed, notarized, release-optimized owner-gate candidates
- macOS input sources: Apple's **Simple Telex** and **VNI**
- Shell fixture: `/tmp/herminal-ime-tab/tiếng-việt-project`

A local accessibility harness focused a fresh Herminal tab, selected the actual
macOS Simple Telex input source, entered `cd tieengs`, and pressed Tab exactly
once while the Vietnamese composition was active. It then pressed Return and,
after restoring the ABC input source, recorded `pwd` to a synthetic result file.
The resulting directory was:

```text
/tmp/herminal-ime-tab/tiếng-việt-project
```

Result: **PASS** for the core Telex one-Tab commit-and-complete path on the
notarized release candidate. This used the live macOS input method rather than
Herminal's synthetic text-injection test hook.

The same objective test was repeated after CI removed all four hardened-runtime
exceptions. Apple's actual VNI source entered `cd tie61ng`; one Tab followed by
Return changed into the same `tiếng-việt-project` directory. Result: **PASS** for
the core VNI one-Tab path on the notarized no-exception candidate from workflow
run `31831816811`.

This result does not replace the owner T1–T7 visual matrix: VNI, marked-text
appearance, Shift-Tab, zsh menu completion, surrounding text, and duplicate/drop
inspection still require the privacy-safe human run in
`docs/QA/vietnamese-ime-checklist.md`.
