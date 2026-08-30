#!/bin/bash
# Build testdata/<name>: an alias to a real folder in this Mac's OneDrive whose
# stored path is rewritten to a foreign user, simulating an alias from another
# Mac. Pass the path relative to the OneDrive root (default: Documents).
set -euo pipefail
cd "$(dirname "$0")"

REALIAS="$(swift build -c release --show-bin-path)/Realias"
[ -x "$REALIAS" ] || { echo "run ./build.sh first"; exit 1; }

RELATIVE="${1:-Documents}"
ROOT="$("$REALIAS" --onedrive-roots | head -1)"
[ -n "$ROOT" ] || { echo "no OneDrive folder found on this Mac"; exit 1; }

TARGET="$ROOT/$RELATIVE"
[ -e "$TARGET" ] || { echo "no such item: $TARGET"; exit 1; }

OUT="testdata/$(basename "$RELATIVE")"
mkdir -p testdata
rm -f "$OUT"
"$REALIAS" --make-alias "$TARGET" "$PWD/$OUT"

# Same-length username swap keeps the length-prefixed bookmark strings valid,
# so pad "otherperson" to exactly the length of the real name.
USERNAME="$(id -un)"
FAKE=""
while [ "${#FAKE}" -lt "${#USERNAME}" ]; do FAKE="${FAKE}otherperson"; done
FAKE="${FAKE:0:${#USERNAME}}"

LC_ALL=C perl -0777 -pe "\$c = s/\Q$USERNAME\E/$FAKE/g; END { exit(\$c ? 0 : 1) }" \
	"$OUT" > "$OUT.tmp" || { rm -f "$OUT.tmp"; echo "username not found in bookmark data"; exit 1; }
mv "$OUT.tmp" "$OUT"

echo "$OUT -> $("$REALIAS" --target-of "$OUT")"
