#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/WindowPaste/Info.plist")"
APP_NAME="窗贴"
VOL_NAME="窗贴"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

if [[ "${1:-}" != "--dmg-only" ]]; then
  "$ROOT/build.sh"
fi

BUILT_APP="$ROOT/build/DerivedData/Build/Products/Release/WindowPaste.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "找不到编译产物：$BUILT_APP" >&2
  exit 1
fi

swift "$ROOT/scripts/generate_dmg_background.swift" "$ROOT/Design"
BG_PNG="$ROOT/Design/dmg-background.png"

WORK="$ROOT/build/dmg"
STAGE="$WORK/stage"
RW_DMG="$WORK/rw.dmg"
DIST="$ROOT/dist"
FINAL_DMG="$DIST/$DMG_NAME"
MOUNT_POINT="/Volumes/${VOL_NAME}"

hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
hdiutil detach "/Volumes/${VOL_NAME} 1.0.0" -quiet 2>/dev/null || true
sleep 1

rm -rf "$WORK"
mkdir -p "$STAGE/.background" "$DIST"

ditto "$BUILT_APP" "$STAGE/${APP_NAME}.app"
xattr -cr "$STAGE/${APP_NAME}.app" || true
dot_clean -m "$STAGE" 2>/dev/null || true
find "$STAGE" \( -name '._*' -o -name '.DS_Store' \) -delete
codesign --force --deep --sign - "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
ditto "$BG_PNG" "$STAGE/.background/background.png"
chflags hidden "$STAGE/.background"

ditto "$STAGE/${APP_NAME}.app" "$DIST/${APP_NAME}.app"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -ov \
  "$RW_DMG" >/dev/null

hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" >/dev/null
sleep 1

osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    delay 0.8
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {280, 140, 940, 560}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set text size of theViewOptions to 12
    set background color of theViewOptions to {1769, 5112, 4391}
    set background picture of theViewOptions to file ".background:background.png"
    delay 0.4
    set position of item "${APP_NAME}.app" of container window to {180, 185}
    set position of item "Applications" of container window to {480, 185}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
sleep 1
hdiutil detach "$MOUNT_POINT" >/dev/null || diskutil eject "$MOUNT_POINT" >/dev/null || true
sleep 1

rm -f "$FINAL_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
xattr -c "$FINAL_DMG" || true

echo "DMG: $FINAL_DMG"
ls -lh "$FINAL_DMG"
