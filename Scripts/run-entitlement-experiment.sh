#!/usr/bin/env bash
# Remove exactly one hardened-runtime exception from a copied release bundle,
# Developer-ID sign it, and record a privacy-safe manual runtime matrix.

set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
usage: Scripts/run-entitlement-experiment.sh <jit|unsigned-memory|dyld-env|library-validation> [app-path]

Requires HERMINAL_SIGNING_IDENTITY and an interactive owner session. The source
app and App/herminal.entitlements are never modified.
USAGE
    exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
[ -t 0 ] || { echo "ERROR: runtime verification requires a human" >&2; exit 1; }
[ -n "${HERMINAL_SIGNING_IDENTITY:-}" ] || {
    echo "ERROR: HERMINAL_SIGNING_IDENTITY is required" >&2
    exit 1
}

case "$1" in
    jit) key="com.apple.security.cs.allow-jit" ;;
    unsigned-memory) key="com.apple.security.cs.allow-unsigned-executable-memory" ;;
    dyld-env) key="com.apple.security.cs.allow-dyld-environment-variables" ;;
    library-validation) key="com.apple.security.cs.disable-library-validation" ;;
    *) usage ;;
esac
variant="$1"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
source_app="${2:-.build/release/herminal.app}"
[ -d "$source_app" ] || { echo "ERROR: source app not found" >&2; exit 1; }
if ! /usr/libexec/PlistBuddy -c "Print :$key" App/herminal.entitlements >/dev/null 2>&1; then
    echo "ERROR: selected entitlement is already absent from production" >&2
    exit 1
fi

if ! security find-identity -v -p codesigning 2>/dev/null \
    | grep -Fq "\"$HERMINAL_SIGNING_IDENTITY\""; then
    echo "ERROR: configured signing identity was not found" >&2
    exit 1
fi

stamp=$(date +%Y-%m-%d-%H%M%S)
work_dir=".build/entitlement-audit/$variant-$stamp"
app="$work_dir/herminal.app"
entitlements="$work_dir/herminal.entitlements"
record="docs/QA/results/entitlement-$variant-$stamp.md"
mkdir -p "$work_dir" "$(dirname "$record")"
cp -R "$source_app" "$app"
cp App/herminal.entitlements "$entitlements"

/usr/libexec/PlistBuddy -c "Delete :$key" "$entitlements" >/dev/null
if /usr/libexec/PlistBuddy -c "Print :$key" "$entitlements" >/dev/null 2>&1; then
    echo "ERROR: experiment failed to remove exactly the selected entitlement" >&2
    exit 1
fi

# Re-sign only the copy. Timestamp + runtime match the public signing posture;
# re-signing invalidates any old staple, so this is a runtime experiment—not a
# distributable artifact.
codesign --force --deep --options runtime --timestamp \
    --entitlements "$entitlements" \
    --sign "$HERMINAL_SIGNING_IDENTITY" "$app" >/dev/null
codesign --verify --deep --strict "$app" >/dev/null

cat <<EOF
Signed experiment copy: $app
Removed: $key
The copy is NOT distributable and its previous notarization ticket is invalid.
Launch it now, then check only behavior—do not paste commands or terminal output.
EOF
open -n "$app"

checks=(
    "Metal renderer displays and remains responsive"
    "A new login shell starts and accepts input"
    "tmux starts, redraws, and accepts input"
    "One agent CLI starts and appears in the dashboard"
)
results=()
for check in "${checks[@]}"; do
    while true; do
        printf '%s [p/f]: ' "$check"
        read -r answer
        case "$answer" in
            p|P) results+=(PASS); break ;;
            f|F) results+=(FAIL); break ;;
            *) echo "Enter p or f; do not paste diagnostic content." ;;
        esac
    done
done

overall=PASS
for result in "${results[@]}"; do
    [ "$result" = PASS ] || overall=FAIL
done

{
    echo "# Hardened-runtime entitlement experiment — $stamp"
    echo
    echo "- Commit: \`$(git rev-parse HEAD)\`"
    echo "- Removed from copied build: \`$key\`"
    echo "- Signature: Developer ID + hardened runtime (identity omitted)"
    echo "- Notarization: not submitted; copied build is not distributable"
    echo "- Runtime matrix: **$overall**"
    echo
    echo "| Check | Result |"
    echo "|---|---|"
    for i in "${!checks[@]}"; do
        printf '| %s | %s |\n' "${checks[$i]}" "${results[$i]}"
    done
    echo
    echo "No terminal content, commands, identity details, credentials, or local paths"
    echo "are included. Production entitlements were not changed."
} > "$record"

printf 'WROTE %s\n' "$record"
if [ "$overall" != PASS ]; then
    echo "KEEP ENTITLEMENT: runtime matrix failed" >&2
    exit 1
fi
echo "CANDIDATE FOR REMOVAL: review evidence; do not modify production automatically"
