#!/bin/bash
# Better Vest for Safari - one-step install on a Mac (needs Xcode and Safari 18+).
#
#   bash safari/install-mac.sh
#
# Builds the Safari extension, wraps it in an app with Xcode, signs it for this Mac only (ad hoc, no Apple
# account needed), copies the app to ~/Applications and opens it once so Safari picks the extension up.
# Safari then shows it under Settings > Extensions once "Allow unsigned extensions" is on.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_DIR="$HOME/Applications"
BUNDLE_ID="${BUNDLE_ID:-local.$(id -un | tr -cd 'a-zA-Z0-9').better-vest}"

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Xcode is missing or not selected. Install it from the App Store, open it once, then run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app"
    exit 1
fi

echo "==> Building the Safari extension and the Xcode project"
python3 safari/build.py --xcode --bundle-id "$BUNDLE_ID"

PROJ="$(find safari/build/xcode -maxdepth 2 -name '*.xcodeproj' | head -1)"
[ -n "$PROJ" ] || { echo "No Xcode project found in safari/build/xcode"; exit 1; }
SCHEME="$(xcodebuild -list -project "$PROJ" 2>/dev/null | awk '/Schemes:/{f=1;next} f&&NF{print;exit}' | sed 's/^ *//')"
[ -n "$SCHEME" ] || SCHEME="Better Vest"

echo "==> Building the app (scheme: $SCHEME)"
xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath safari/build/derived \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    build | grep -E "error|warning: .*sign|BUILD (SUCCEEDED|FAILED)" || true

BUILT="$(find safari/build/derived/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
[ -n "$BUILT" ] || { echo "The build failed: open $PROJ in Xcode and press Cmd+R to see the error."; exit 1; }

echo "==> Installing to $APP_DIR"
mkdir -p "$APP_DIR"
NAME="$(basename "$BUILT")"
osascript -e "quit app \"${NAME%.app}\"" >/dev/null 2>&1 || true
rm -rf "$APP_DIR/$NAME"
cp -R "$BUILT" "$APP_DIR/"
open "$APP_DIR/$NAME"

cat <<'MSG'

Done. Now in Safari:
  1. Settings > Advanced: tick "Show features for web developers".
  2. Settings > Developer: tick "Allow unsigned extensions" (Safari turns this off each time it quits).
  3. Settings > Extensions: tick "Better Vest".
  4. Open https://next.vestmarkets.com, click the Better Vest toolbar icon and choose
     "Always Allow on This Website", then reload the page.
MSG
