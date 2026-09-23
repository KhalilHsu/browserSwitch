#!/usr/bin/env bash
set -euo pipefail

# Build, Developer ID sign, notarize, and package BrowserRouter as a DMG.
#
# Signing and notarization go through the Apple ID signed in to Xcode
# (Xcode → Settings → Accounts), using Xcode's cloud-managed Developer ID
# certificate. No local Developer ID certificate or notarytool password is
# needed. The source is taken from the committed HEAD, so uncommitted changes
# are never shipped.
#
# Usage: scripts/release.sh
# Output: dist/BrowserRouter-<version>.dmg and its .sha256 file.

APP_NAME="BrowserRouter"
TEAM_ID="${TEAM_ID:-9RTFX3H9YL}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
BUILT_APP_PATH=".build/${APP_NAME}.app"
ENTITLEMENTS=""

build_app() {
  UNIVERSAL=1 scripts/build-app.sh
}

cd "$REPO_ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree has uncommitted changes. Commit them before releasing."
  exit 1
fi

# The archive must carry a certificate-based signature with the hardened
# runtime before Xcode re-signs it with Developer ID. Select by SHA-1 because
# Xcode can leave several certificates with the same name, and skip revoked
# ones: find-identity -v still lists them, and Xcode treats a revoked
# signature as ad hoc and drops the app's entitlements during export.
IDENTITY_LINE=$(security find-identity -v -p codesigning | grep '"Apple Development' | grep -v REVOKED | head -1 || true)
PRESIGN_IDENTITY="${PRESIGN_IDENTITY:-$(echo "$IDENTITY_LINE" | awk '{ print $2 }')}"
PRESIGN_NAME=$(echo "$IDENTITY_LINE" | awk -F'"' '{ print $2 }')
if [ -z "$PRESIGN_IDENTITY" ]; then
  echo "Error: no Apple Development signing identity found. Sign in to Xcode with your developer account first."
  exit 1
fi

WORK_DIR=$(mktemp -d "/private/tmp/${APP_NAME}-release.XXXXXX")
trap 'rm -rf "${WORK_DIR}"' EXIT
SRC_DIR="${WORK_DIR}/src"
mkdir -p "$SRC_DIR"

# 1. Build a universal app from a clean export of HEAD. Building outside
#    Desktop/iCloud also avoids File Provider touching sources mid-build.
git archive HEAD | tar -x -C "$SRC_DIR"
echo "=== Building ${APP_NAME} ==="
(cd "$SRC_DIR" && build_app >/dev/null)

BUILT_APP="${SRC_DIR}/${BUILT_APP_PATH}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${BUILT_APP}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${BUILT_APP}/Contents/Info.plist")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${BUILT_APP}/Contents/Info.plist")
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
echo "=== Releasing ${APP_NAME} ${VERSION} (${BUILD}) ==="

# 2. Wrap the app in a minimal Xcode archive.
ARCHIVE="${WORK_DIR}/${APP_NAME}.xcarchive"
ARCHIVED_APP="${ARCHIVE}/Products/Applications/${APP_NAME}.app"
mkdir -p "$(dirname "$ARCHIVED_APP")"
ditto --norsrc "$BUILT_APP" "$ARCHIVED_APP"
xattr -cr "$ARCHIVED_APP"
SIGN_ARGS=(--force --deep --options runtime --timestamp --sign "$PRESIGN_IDENTITY")
if [ -n "${ENTITLEMENTS:-}" ]; then
  SIGN_ARGS+=(--entitlements "${SRC_DIR}/${ENTITLEMENTS}")
fi
codesign "${SIGN_ARGS[@]}" "$ARCHIVED_APP"

cat > "${ARCHIVE}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ApplicationProperties</key>
  <dict>
    <key>ApplicationPath</key><string>Applications/${APP_NAME}.app</string>
    <key>Architectures</key><array><string>arm64</string><string>x86_64</string></array>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>SigningIdentity</key><string>${PRESIGN_NAME}</string>
    <key>Team</key><string>${TEAM_ID}</string>
  </dict>
  <key>ArchiveVersion</key><integer>2</integer>
  <key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
  <key>Name</key><string>${APP_NAME}</string>
  <key>SchemeName</key><string>${APP_NAME}</string>
</dict>
</plist>
PLIST

cat > "${WORK_DIR}/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict>
</plist>
PLIST

# 3. Re-sign with Developer ID and submit to Apple's notary service.
echo "Signing with Developer ID and submitting for notarization..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "${WORK_DIR}/ExportOptions.plist" \
  -exportPath "${WORK_DIR}/upload" -allowProvisioningUpdates >/dev/null

# 4. Wait for notarization, then export the stapled app.
NOTARIZED_DIR="${WORK_DIR}/notarized"
for attempt in $(seq 1 60); do
  if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" \
    -exportPath "$NOTARIZED_DIR" >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo "Error: notarization did not finish within 30 minutes."
    exit 1
  fi
  echo "Waiting for notarization (${attempt})..."
  sleep 30
done

NOTARIZED_APP="${NOTARIZED_DIR}/${APP_NAME}.app"
xcrun stapler validate "$NOTARIZED_APP"
spctl --assess --type exec --verbose=2 "$NOTARIZED_APP"
if [ -n "${ENTITLEMENTS:-}" ]; then
  for key in $(/usr/libexec/PlistBuddy -c "Print" "${SRC_DIR}/${ENTITLEMENTS}" | awk -F' = ' '/ = /{ gsub(/ /, "", $1); print $1 }'); do
    if ! codesign -d --entitlements - "$NOTARIZED_APP" 2>/dev/null | grep -q "$key"; then
      echo "Error: the notarized app lost the ${key} entitlement."
      exit 1
    fi
  done
fi

# 5. Package the stapled app with an /Applications shortcut.
STAGING="${WORK_DIR}/dmg"
mkdir -p "$STAGING" "$DIST_DIR"
ditto "$NOTARIZED_APP" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$STAGING" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

(cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256")

echo "=== Release package ready ==="
echo "$DMG_PATH"
cat "${DMG_PATH}.sha256"
