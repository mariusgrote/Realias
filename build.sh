#!/bin/bash
# Build Realias.app and the Finder Quick Action from src/.
# Re-run after changing anything in src/, then ./install.sh.
set -euo pipefail
cd "$(dirname "$0")"

APP="Realias.app"
WORKFLOW="Create Local Alias.workflow"

rm -rf "$APP"
osacompile -o "$APP" src/Realias.applescript

RES="$APP/Contents/Resources/src"
mkdir -p "$RES"
cp src/realias.py src/bookmark.py src/config.py src/remap.py src/make_alias.js "$RES/"

/usr/libexec/PlistBuddy -c "Set :CFBundleName Realias" \
	-c "Add :CFBundleIdentifier string io.github.mariusgrote.realias" \
	"$APP/Contents/Info.plist"

# The Quick Action points at the installed app, so build it for /Applications.
python3 src/make_quickaction.py "/Applications/$APP" "$WORKFLOW"

echo "Built $PWD/$APP"
echo "Built $PWD/$WORKFLOW"
