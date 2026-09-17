#!/bin/bash
# Regenerates Resources/Realias.icns from Tools/make_icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swift Tools/make_icon.swift "$TMP/Realias.iconset"
iconutil -c icns "$TMP/Realias.iconset" -o Resources/Realias.icns
echo "Wrote $PWD/Resources/Realias.icns"
