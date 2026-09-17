#!/bin/bash
# Build Realias.app from the Swift package and stage the Finder Quick Action.
# Re-run after changing anything in Sources/, then ./install.sh.
# Usage: ./build.sh [--arch <arm64|x86_64>]  (default: the host architecture)
set -euo pipefail
cd "$(dirname "$0")"

APP="Realias.app"
WORKFLOW="Create Local Alias.workflow"
BUILD_ARGS=(-c release)

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)
            [ $# -ge 2 ] || { echo "--arch needs a value" >&2; exit 2; }
            BUILD_ARGS+=(--arch "$2")
            shift 2
            ;;
        *)
            echo "unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# CI passes VERSION and BUILD for releases. Local builds identify the current
# commit through git describe and start at 0.1.0 before the first tag exists.
VERSION="${VERSION:-$(git describe --tags --dirty 2>/dev/null || echo v0.1.0)}"
VERSION="${VERSION#v}"
BUILD="${BUILD:-0}"

swift build "${BUILD_ARGS[@]}"
BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/Realias"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Realias"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
cp Resources/Realias.icns "$APP/Contents/Resources/Realias.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: unsigned bundles are refused the Automation permission
# they need to read the Finder selection.
codesign --force --sign - "$APP"

# The Quick Action calls the app installed in /Applications, so it is the same
# bundle every time; just stage it next to the app.
rm -rf "$WORKFLOW"
cp -R "QuickAction/$WORKFLOW" "$WORKFLOW"

echo "Built $PWD/$APP $VERSION ($BUILD)"
echo "Built $PWD/$WORKFLOW"
