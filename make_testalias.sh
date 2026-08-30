#!/bin/bash
# Build testdata/<name>: an alias to a real folder in this Mac's OneDrive whose
# stored path is rewritten to a foreign user, simulating an alias from another
# Mac. Pass the path relative to the OneDrive root (default: Documents).
set -euo pipefail
cd "$(dirname "$0")"

RELATIVE="${1:-Documents}"
ROOT="$(python3 -c 'import sys; sys.path.insert(0, "src"); import remap; roots = remap.local_roots(); print(roots[0] if roots else "")')"
[ -n "$ROOT" ] || { echo "no OneDrive folder found on this Mac"; exit 1; }

TARGET="$ROOT/$RELATIVE"
[ -e "$TARGET" ] || { echo "no such item: $TARGET"; exit 1; }

OUT="testdata/$(basename "$RELATIVE")"
mkdir -p testdata
rm -f "$OUT"
osascript -l JavaScript src/make_alias.js "$TARGET" "$PWD/$OUT" >/dev/null

OUT="$OUT" python3 - <<'PY'
# Same-length username swap keeps the length-prefixed bookmark strings valid.
import getpass, os

path = os.environ["OUT"]
user = getpass.getuser().encode()
fake = (b"otherperson" * (len(user) // 11 + 1))[:len(user)]

data = open(path, "rb").read()
assert user in data, "username not found in bookmark data"
open(path, "wb").write(data.replace(user, fake))
PY
echo "$OUT -> $(python3 src/bookmark.py "$OUT")"
