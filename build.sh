#!/bin/bash
# Build Realias.app from the Swift package and stage the Finder Quick Action.
# Re-run after changing anything in Sources/, then ./install.sh.
set -euo pipefail
cd "$(dirname "$0")"

APP="Realias.app"
WORKFLOW="Create Local Alias.workflow"

swift build -c release --disable-sandbox
BINARY="$(swift build -c release --show-bin-path)/Realias"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Realias"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: unsigned bundles are refused the Automation permission
# they need to read the Finder selection.
codesign --force --sign - "$APP"

# The Quick Action calls the app installed in /Applications, so it is the same
# bundle every time; just stage it next to the app.
rm -rf "$WORKFLOW"
cp -R "QuickAction/$WORKFLOW" "$WORKFLOW"

echo "Built $PWD/$APP"
echo "Built $PWD/$WORKFLOW"
