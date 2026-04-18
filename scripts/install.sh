#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserRouter"
SOURCE_APP=".build/${APP_NAME}.app"
TARGET_APP="/Applications/${APP_NAME}.app"
BUNDLE_ID="local.browser-router"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

scripts/build-app.sh >/dev/null

osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
pkill -f "${TARGET_APP}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || true
sleep 0.5

rm -rf "${TARGET_APP}"
cp -R "${SOURCE_APP}" /Applications/
"${LSREGISTER}" -f "${TARGET_APP}" >/dev/null 2>&1 || true
open "${TARGET_APP}"

echo "Installed and relaunched ${TARGET_APP}"
