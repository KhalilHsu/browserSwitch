#!/bin/bash
set -e

APP_NAME="BrowserRouter"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo "0.1.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
TEMPLATE_DMG="template.dmg"
STAGING_DIR="dmg_staging"
VOL_NAME="${APP_NAME} Installer"

echo "🚀 Building Release version..."
scripts/build-app.sh >/dev/null

echo "📂 Preparing staging folder..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R ".build/${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary r/w DMG
echo "💾 Creating temporary disk image..."
rm -f "$TEMPLATE_DMG"
hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOL_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100M "$TEMPLATE_DMG"

echo "💿 Mounting disk image..."
DEVICE=$(hdiutil attach -readwrite -noverify "$TEMPLATE_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# Set background and icons using AppleScript
echo "🎨 Customizing DMG appearance..."
mkdir -p "/Volumes/$VOL_NAME/.background"
cp Resources/background.png "/Volumes/$VOL_NAME/.background/background.png"

echo "Running AppleScript for layout..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set theViewOptions to icon view options of container window
        set icon size of theViewOptions to 90
        set arrangement of theViewOptions to not arranged
        set background picture of theViewOptions to (POSIX file "/Volumes/$VOL_NAME/.background/background.png")
        
        # Position icons precisely relative to the 600x400 background
        # Coordinate system origin is top-left
        set position of item "$APP_NAME.app" to {150, 200}
        set position of item "Applications" to {450, 200}
        
        # Set bounds: {left, top, right, bottom}
        set bounds of container window to {400, 100, 1000, 500} 
        update (every item)
        # Give it a moment to save
        delay 2
        close
    end tell
end tell
EOF

echo "🔒 Finalizing DMG..."
sync
hdiutil detach "$DEVICE"
rm -f "$DMG_NAME"
hdiutil convert "$TEMPLATE_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

echo "✨ Cleaning up..."
rm -rf "$STAGING_DIR"
rm -f "$TEMPLATE_DMG"

echo "✅ Success! Created professional DMG: $DMG_NAME"
