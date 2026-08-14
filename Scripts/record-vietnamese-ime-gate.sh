#!/usr/bin/env bash
# Interactive recorder for the real macOS Telex/VNI release gate.
# Records case outcomes only—never terminal history, typed text, or credentials.

set -euo pipefail

if [ ! -t 0 ]; then
    echo "ERROR: this gate requires a human at an interactive terminal" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

commit=$(git rev-parse HEAD)
date_stamp=$(date +%Y-%m-%d)
time_stamp=$(date +%H%M%S)
os_version=$(sw_vers -productVersion)
os_build=$(sw_vers -buildVersion)
output="docs/QA/results/vietnamese-ime-${date_stamp}-${time_stamp}.md"
mkdir -p "$(dirname "$output")"

cat <<'SETUP'
Prepare the isolated fixture exactly as documented:
  mkdir -p /tmp/herminal-ime-tab && cd /tmp/herminal-ime-tab
  mkdir 'tiếng-việt-project'
  touch 'kiểm-thử.txt'

For each case, enter p=pass, f=fail, or s=skipped. Do not paste terminal
history or typed content. A failed case may be classified with one safe label:
PREEDIT, COMMIT, DROP, DUP, CURSOR, COMPLETION, or OTHER.
SETUP

case_ids=(T1 T2 T3 T4 T5 T6 T7)
case_labels=(
    "Telex/zsh: underlined unique prefix + Tab"
    "VNI/zsh: underlined unique prefix + Tab"
    "Telex/bash: underlined unique prefix + Tab"
    "Telex/fish: underlined unique prefix + Tab"
    "Telex/zsh: underlined preedit + Shift-Tab"
    "US/zsh: ordinary ASCII prefix + Tab"
    "Telex/zsh: repeat T1 ten times"
)
results=()
defects=()

for i in "${!case_ids[@]}"; do
    while true; do
        printf '%s — %s [p/f/s]: ' "${case_ids[$i]}" "${case_labels[$i]}"
        read -r answer
        case "$answer" in
            p|P) results+=("PASS"); defects+=("—"); break ;;
            s|S) results+=("SKIPPED"); defects+=("—"); break ;;
            f|F)
                while true; do
                    printf 'Defect label [PREEDIT/COMMIT/DROP/DUP/CURSOR/COMPLETION/OTHER]: '
                    read -r defect
                    defect=$(printf '%s' "$defect" | tr '[:lower:]' '[:upper:]')
                    case "$defect" in
                        PREEDIT|COMMIT|DROP|DUP|CURSOR|COMPLETION|OTHER)
                            results+=("FAIL"); defects+=("$defect"); break 2 ;;
                        *) echo "Choose one listed label; do not enter diagnostic content." ;;
                    esac
                done
                ;;
            *) echo "Enter p, f, or s." ;;
        esac
    done
done

mandatory=(0 1 4 5 6)
gate=PASS
for index in "${mandatory[@]}"; do
    if [ "${results[$index]}" != PASS ]; then
        gate=FAIL
    fi
done
if printf '%s\n' "${defects[@]}" | grep -Eq '^(DROP|DUP)$'; then
    gate=FAIL
fi

{
    echo "# Vietnamese IME release gate — $date_stamp"
    echo
    echo "- Commit: \`$commit\`"
    echo "- macOS: \`$os_version ($os_build)\`"
    echo "- Recorder: \`Scripts/record-vietnamese-ime-gate.sh\`"
    echo "- Release gate: **$gate**"
    echo
    echo "| Case | Input source / shell | Result | Defect class |"
    echo "|---|---|---|---|"
    for i in "${!case_ids[@]}"; do
        printf '| %s | %s | %s | %s |\n' \
            "${case_ids[$i]}" "${case_labels[$i]}" "${results[$i]}" "${defects[$i]}"
    done
    echo
    echo "This record contains no terminal history, typed content, paths, credentials,"
    echo "or user identity. T1/T2/T5/T6/T7 are mandatory; T3/T4 are optional only when"
    echo "the corresponding shell is unavailable."
} > "$output"

printf 'WROTE %s\n' "$output"
if [ "$gate" != PASS ]; then
    echo "NOT RELEASE-ELIGIBLE: mandatory Vietnamese IME gate failed" >&2
    exit 1
fi
echo "PASS: Vietnamese IME release gate recorded; review before committing"
