#!/usr/bin/env bash
# Shared release helpers kept pure so safety guards can exercise them without
# building, signing, or mutating tags.

normalize_release_version() {
    local value="$1"
    printf '%s\n' "${value#v}"
}

# plutil accepts compact and pretty-printed notarytool JSON and is available on
# every supported macOS/Xcode release runner.
notary_json_value() {
    local file="$1"
    local key="$2"
    /usr/bin/plutil -extract "$key" raw -o - "$file" 2>/dev/null
}
