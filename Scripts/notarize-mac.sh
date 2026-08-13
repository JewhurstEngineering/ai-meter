#!/usr/bin/env bash
# Archive, Developer ID-export, notarize, and staple the Mac app.
# Requires a Developer ID Application certificate on the team, and:
#   xcrun notarytool store-credentials AC_PASSWORD
# Override the profile with NOTARY_KEYCHAIN_PROFILE.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AC_PASSWORD}"
DIST="${PWD}/dist/mac"
ARCHIVE="${DIST}/CursorUsageTracker.xcarchive"
EXPORT="${DIST}/export"
ZIP="${DIST}/CursorUsageTracker.zip"

mkdir -p "${DIST}"
xcodegen generate

echo "Archiving Mac Release…"
xcodebuild \
  -project CursorUsageTracker.xcodeproj \
  -scheme CursorUsageTracker \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  -archivePath "${ARCHIVE}" \
  archive

echo "Exporting Developer ID…"
if ! xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportPath "${EXPORT}" \
  -exportOptionsPlist Scripts/export-options-mac-developer-id.plist \
  -allowProvisioningUpdates
then
  echo "Developer ID export failed. Archive is at ${ARCHIVE}." >&2
  echo "Install a Developer ID Application certificate for team 6998422DKP, then re-run." >&2
  exit 1
fi

APP="${EXPORT}/CursorUsageTracker.app"
if [[ ! -d "${APP}" ]]; then
  echo "Export did not produce CursorUsageTracker.app" >&2
  exit 1
fi

ditto -c -k --keepParent "${APP}" "${ZIP}"

if ! xcrun notarytool history --keychain-profile "${PROFILE}" >/dev/null 2>&1; then
  echo "No notary keychain profile named ${PROFILE}." >&2
  echo "Create one (app-specific password or App Store Connect API key):" >&2
  echo "  xcrun notarytool store-credentials ${PROFILE}" >&2
  echo "Zip ready at ${ZIP} — submit after storing credentials." >&2
  exit 2
fi

echo "Submitting to Apple notary service…"
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait
xcrun stapler staple "${APP}"
echo "Notarized app: ${APP}"
