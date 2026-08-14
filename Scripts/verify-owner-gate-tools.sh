#!/usr/bin/env bash
# Non-interactive regression checks for owner-only gate runners.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

expect_failure() {
    local expected="$1"
    shift
    local output status
    set +e
    output=$("$@" </dev/null 2>&1)
    status=$?
    set -e
    if [ "$status" -eq 0 ] || ! grep -Fq "$expected" <<< "$output"; then
        echo "FAIL: expected fail-closed message: $expected" >&2
        echo "$output" >&2
        exit 1
    fi
}

expect_failure \
    "HERMINAL_SIGNING_IDENTITY is not configured" \
    env -u HERMINAL_SIGNING_IDENTITY -u HERMINAL_NOTARY_PROFILE \
    Scripts/check-release-readiness.sh
expect_failure \
    "requires a human at an interactive terminal" \
    Scripts/record-vietnamese-ime-gate.sh
expect_failure \
    "usage: Scripts/run-entitlement-experiment.sh" \
    Scripts/run-entitlement-experiment.sh

# One-at-a-time signed debug and release experiments proved these exceptions
# unnecessary. Guard against accidentally restoring the retired permissions.
for key in \
    com.apple.security.cs.allow-jit \
    com.apple.security.cs.allow-unsigned-executable-memory \
    com.apple.security.cs.allow-dyld-environment-variables \
    com.apple.security.cs.disable-library-validation; do
    if /usr/libexec/PlistBuddy -c "Print :$key" App/herminal.entitlements >/dev/null 2>&1; then
        echo "FAIL: retired hardened-runtime exception was restored: $key" >&2
        exit 1
    fi
 done

# shellcheck disable=SC2016 # Match the literal destination variable.
if ! grep -Fq 'cp App/herminal.entitlements "$entitlements"' \
    Scripts/run-entitlement-experiment.sh; then
    echo "FAIL: entitlement experiment no longer starts from a copied plist" >&2
    exit 1
fi

echo "PASS: owner gate tools fail closed and preserve production inputs"
