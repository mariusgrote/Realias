#!/bin/bash
# Install the app into /Applications and the Quick Action into ~/Library/Services.
set -euo pipefail
cd "$(dirname "$0")"

APP="Realias.app"
WORKFLOW="Create Local Alias.workflow"

[ -d "$APP" ] || { echo "run ./build.sh first"; exit 1; }

rm -rf "/Applications/$APP"
cp -R "$APP" "/Applications/$APP"

mkdir -p "$HOME/Library/Services"
rm -rf "$HOME/Library/Services/$WORKFLOW"
cp -R "$WORKFLOW" "$HOME/Library/Services/$WORKFLOW"

# Make the Services menu pick up the change without a logout.
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

echo "Installed /Applications/$APP"
echo "Installed $HOME/Library/Services/$WORKFLOW"
