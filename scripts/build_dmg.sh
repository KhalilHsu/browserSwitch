#!/bin/bash
set -e

APP_NAME="BrowserRouter"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo "0.1.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="dmg_staging"

echo "🚀 Building Release version..."
scripts/build-app.sh >/dev/null

echo "📂 Preparing staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy the app bundle
cp -R ".build/${APP_NAME}.app" "$STAGING_DIR/"

# Create link to Applications
ln -s /Applications "$STAGING_DIR/Applications"

echo "💾 Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

echo "✨ Cleaning up..."
rm -rf "$STAGING_DIR"

echo "✅ Success! Created: $DMG_NAME"
