#!/bin/bash
# Build Cutting Mat.app (menu bar app) and a DMG with the usual "drag to Applications" window.
# Needs the Xcode command line tools (swiftc, codesign, hdiutil, iconutil, sips).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_DIR="$DIST_DIR/CuttingMat.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "=== Building Cutting Mat for macOS ==="

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/engine"

# 1. Drawing engine: the website's own scripts, plus the small bridge
echo "Copying the drawing engine..."
cp "$ROOT_DIR/js/devices.js" "$ROOT_DIR/js/draw-mat.js" "$ROOT_DIR/js/render.js" "$RESOURCES_DIR/engine/"
cp "$SCRIPT_DIR/Resources/engine.html" "$SCRIPT_DIR/Resources/bridge.js" "$RESOURCES_DIR/engine/"

# 2. Info.plist and icon
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ ! -f "$SCRIPT_DIR/Resources/AppIcon.icns" ] && [ -f "$SCRIPT_DIR/Resources/AppIcon-1024.png" ]; then
    echo "Making AppIcon.icns..."
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$SCRIPT_DIR/Resources/AppIcon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) "$SCRIPT_DIR/Resources/AppIcon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$SCRIPT_DIR/Resources/AppIcon.icns"
fi
[ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ] && cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# 3. Compile
echo "Compiling..."
swiftc -O \
    -framework Cocoa \
    -framework WebKit \
    -framework ServiceManagement \
    "$SCRIPT_DIR/Sources/LaunchAtLoginHelper.swift" \
    "$SCRIPT_DIR/Sources/AppDelegate.swift" \
    "$SCRIPT_DIR/Sources/main.swift" \
    -o "$MACOS_DIR/CuttingMat"

# 4. Ad-hoc signing for local use
echo "Signing..."
codesign --force --deep --sign - "$APP_DIR"

# 5. DMG: the app next to a shortcut to Applications
echo "Packaging the DMG..."
DMG_PATH="$DIST_DIR/CuttingMat.dmg"
STAGING="$DIST_DIR/dmg_staging"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Cutting Mat" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"

echo "=================================================="
echo "Done: $DMG_PATH"
echo "Open it, drag Cutting Mat onto Applications, then open the app once."
echo "=================================================="
