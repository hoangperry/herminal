#!/usr/bin/env bash
# Shared release helpers kept pure so safety guards can exercise them without
# building, signing, or mutating tags.

normalize_release_version() {
    local value="$1"
    printf '%s\n' "${value#v}"
}

# A public release section must be finalized with an ISO date. Merely finding
# `## [VERSION]` is insufficient because Keep a Changelog drafts commonly use
# `- Unreleased`, which must never be tagged as a completed release.
validate_release_changelog() {
    local file="$1"
    local version="$2"
    local section="## [$version]"
    local prefix="$section - "
    local header date

    header=$(grep -F -m 1 "$section" "$file" || true)
    if [ -z "$header" ]; then
        echo "ERROR: no '$section' section in $file" >&2
        return 1
    fi
    if [ "$header" = "$section - Unreleased" ]; then
        echo "ERROR: '$section' is still marked Unreleased" >&2
        return 1
    fi
    if [ "${header:0:${#prefix}}" != "$prefix" ]; then
        echo "ERROR: '$section' must include a release date (YYYY-MM-DD)" >&2
        return 1
    fi
    date=${header#"$prefix"}
    if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "ERROR: '$section' has an invalid release date; expected YYYY-MM-DD" >&2
        return 1
    fi
}

# plutil accepts compact and pretty-printed notarytool JSON and is available on
# every supported macOS/Xcode release runner.
notary_json_value() {
    local file="$1"
    local key="$2"
    /usr/bin/plutil -extract "$key" raw -o - "$file" 2>/dev/null
}
