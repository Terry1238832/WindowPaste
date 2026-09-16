#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/WindowPaste/Info.plist")"
IDENTIFIER="com.liangyu.windowpaste"
APP_NAME="窗贴"
PKG_NAME="${APP_NAME}-${VERSION}.pkg"

"$ROOT/build.sh"

BUILT_APP="$ROOT/build/DerivedData/Build/Products/Release/WindowPaste.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "找不到编译产物：$BUILT_APP" >&2
  exit 1
fi

WORK="$ROOT/build/pkg"
PAYLOAD="$WORK/payload"
COMPONENT="$WORK/WindowPaste-component.pkg"
COMPONENT_PLIST="$WORK/component.plist"
SCRIPTS="$ROOT/packaging/scripts"
DIST="$ROOT/dist"

rm -rf "$WORK"
mkdir -p "$PAYLOAD" "$DIST"

ditto "$BUILT_APP" "$PAYLOAD/${APP_NAME}.app"
xattr -cr "$PAYLOAD/${APP_NAME}.app" || true
dot_clean -m "$PAYLOAD" 2>/dev/null || true
find "$PAYLOAD" \( -name '._*' -o -name '.DS_Store' \) -delete
codesign --force --deep --sign - "$PAYLOAD/${APP_NAME}.app"

chmod 755 "$SCRIPTS/postinstall"

pkgbuild --analyze --root "$PAYLOAD" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Add :0:BundleIdentifier string $IDENTIFIER" "$COMPONENT_PLIST" 2>/dev/null || true

pkgbuild \
  --root "$PAYLOAD" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location /Applications \
  --component-plist "$COMPONENT_PLIST" \
  --scripts "$SCRIPTS" \
  "$COMPONENT"

productbuild \
  --distribution "$ROOT/packaging/distribution.xml" \
  --resources "$ROOT/packaging/Resources" \
  --package-path "$WORK" \
  "$DIST/$PKG_NAME"

ditto "$PAYLOAD/${APP_NAME}.app" "$DIST/${APP_NAME}.app"

echo "Installer: $DIST/$PKG_NAME"
