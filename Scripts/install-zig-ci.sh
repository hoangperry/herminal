#!/usr/bin/env bash
# Install the exact Zig toolchain required by vendored Ghostty.
# Intended for ephemeral CI runners; local developers may install the same
# archive manually at ~/.local/zig/0.15.2.

set -euo pipefail

VERSION="0.15.2"
ARCHIVE="zig-aarch64-macos-${VERSION}.tar.xz"
URL="https://ziglang.org/download/${VERSION}/${ARCHIVE}"
SHA256="3cc2bab367e185cdfb27501c4b30b1b0653c28d9f73df8dc91488e66ece5fa6b"
DEST="${HOME}/.local/zig/${VERSION}"

if [ -x "${DEST}/zig" ]; then
    "${DEST}/zig" version
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl --fail --silent --show-error --location "$URL" --output "${TMP_DIR}/${ARCHIVE}"
echo "${SHA256}  ${TMP_DIR}/${ARCHIVE}" | shasum -a 256 --check
mkdir -p "$(dirname "$DEST")"
tar -xJf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"
rm -rf "$DEST"
mv "${TMP_DIR}/zig-aarch64-macos-${VERSION}" "$DEST"
"${DEST}/zig" version
