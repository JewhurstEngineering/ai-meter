#!/usr/bin/env bash
# Archive the iOS app (embeds Watch + widgets) for TestFlight / App Store Connect.
# Create the App Store Connect record for com.jamesware.aimeter.ios first.
# Upload with Transporter or:
#   xcrun altool --upload-app -f dist/ios/export/*.ipa -t ios --apiKey … --apiIssuer …
set -euo pipefail
cd "$(dirname "$0")/.."

DIST="${PWD}/dist/ios"
ARCHIVE="${DIST}/AIMeteriOS.xcarchive"
EXPORT="${DIST}/export"

mkdir -p "${DIST}"
xcodegen generate

echo "Archiving iOS Release (Watch + widgets embedded)…"
xcodebuild \
  -project AIMeter.xcodeproj \
  -scheme AIMeteriOS \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "${ARCHIVE}" \
  archive \
  -allowProvisioningUpdates

echo "Exporting App Store IPA…"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportPath "${EXPORT}" \
  -exportOptionsPlist Scripts/export-options-ios-appstore.plist \
  -allowProvisioningUpdates

echo "IPA at ${EXPORT}"
echo "Upload in Xcode Organizer or Transporter. Watch is embedded; do not upload it separately."
