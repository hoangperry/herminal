#!/usr/bin/env bash
# Non-secret preflight for the owner-held macOS release prerequisites.
# Prints capability names only; never prints identity/profile values.

set -euo pipefail

online=false
if [ "${1:-}" = "--online-notary-check" ]; then
    online=true
elif [ "$#" -ne 0 ]; then
    echo "usage: $0 [--online-notary-check]" >&2
    exit 2
fi

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures=$((failures + 1)); }

for tool in xcodebuild xcrun codesign security spctl hdiutil ditto; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "tool available: $tool"
    else
        fail "tool missing: $tool"
    fi
done

DEVELOPER_PATH=$(xcode-select -p 2>/dev/null || true)
if [[ "$DEVELOPER_PATH" == *".app/Contents/Developer" ]] && \
   xcodebuild -version >/dev/null 2>&1; then
    pass "full Xcode selected"
else
    fail "full Xcode is not selected"
fi

if xcrun notarytool --version >/dev/null 2>&1; then
    pass "notarytool available"
else
    fail "notarytool unavailable"
fi

if [ -z "${HERMINAL_SIGNING_IDENTITY:-}" ]; then
    fail "HERMINAL_SIGNING_IDENTITY is not configured"
elif security find-identity -v -p codesigning 2>/dev/null \
    | grep -Fq "\"$HERMINAL_SIGNING_IDENTITY\""; then
    pass "configured Developer ID identity exists"

    probe=$(mktemp)
    trap 'rm -f "$probe"' EXIT
    cp /usr/bin/true "$probe"
    if codesign --force --options runtime --sign "$HERMINAL_SIGNING_IDENTITY" \
        "$probe" >/dev/null 2>&1 && codesign --verify --strict "$probe" >/dev/null 2>&1; then
        pass "Developer ID private key is usable non-interactively"
    else
        fail "Developer ID private key is not usable non-interactively"
    fi
else
    fail "configured Developer ID identity was not found"
fi

if [ -z "${HERMINAL_NOTARY_PROFILE:-}" ]; then
    fail "HERMINAL_NOTARY_PROFILE is not configured"
elif $online; then
    if xcrun notarytool history --keychain-profile "$HERMINAL_NOTARY_PROFILE" \
        --output-format json >/dev/null 2>&1; then
        pass "notary profile authenticated successfully"
    else
        fail "notary profile authentication failed"
    fi
else
    pass "notary profile name configured (authentication not tested)"
fi

if [ "$failures" -ne 0 ]; then
    echo "NOT READY: $failures release prerequisite(s) failed" >&2
    exit 1
fi

echo "READY: local release prerequisites passed"
