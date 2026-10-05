#!/bin/bash
# Better Vest for Safari - build, sign and upload to TestFlight (needs a paid Apple Developer account).
#
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.yourname.better-vest BUILD_NUMBER=2 bash safari/testflight.sh
#
# One-time setup before the first run (see safari/README.md):
#   - Xcode > Settings > Accounts: sign in with the developer account.
#   - developer.apple.com > Identifiers: register BUNDLE_ID and BUNDLE_ID.Extension as App IDs.
#   - App Store Connect > Apps > New App: macOS, with that bundle id.
# BUILD_NUMBER has to be higher than the last upload's.
set -euo pipefail

cd "$(dirname "$0")/.."
: "${TEAM_ID:?set TEAM_ID to your Apple developer team id}"
: "${BUNDLE_ID:?set BUNDLE_ID to the bundle id registered in App Store Connect}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHIVE="safari/build/BetterVest.xcarchive"
OPTIONS="safari/build/ExportOptions.plist"

echo "==> Building the Safari extension and the Xcode project"
python3 safari/build.py --xcode --bundle-id "$BUNDLE_ID"
PROJ="$(find safari/build/xcode -maxdepth 2 -name '*.xcodeproj' | head -1)"
[ -n "$PROJ" ] || { echo "No Xcode project found in safari/build/xcode"; exit 1; }

echo "==> Archiving (build $BUILD_NUMBER)"
rm -rf "$ARCHIVE" safari/build/export
xcodebuild -project "$PROJ" -scheme "Better Vest" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    archive | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$ARCHIVE" ] || { echo "The archive failed: open $PROJ in Xcode and use Product > Archive to see the error."; exit 1; }

cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

echo "==> Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
    -exportPath safari/build/export -allowProvisioningUpdates 2>&1 \
    | grep -E "error:|Upload (succeeded|failed)|EXPORT (SUCCEEDED|FAILED)|invalid|Invalid"

cat <<'MSG'

Uploaded. In App Store Connect > your app > TestFlight:
  1. Wait for the build to finish processing, then answer the encryption question on it (Manage).
  2. Add the build to a testing group. Internal groups are for users on your account; external groups
     go through a short Beta App Review first.
MSG
