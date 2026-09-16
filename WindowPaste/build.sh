#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

swift "$ROOT/scripts/generate_icon.swift" "$ROOT/WindowPaste/Assets.xcassets/AppIcon.appiconset"

xcodebuild \
  -project "$ROOT/WindowPaste.xcodeproj" \
  -scheme WindowPaste \
  -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual

APP="$ROOT/build/DerivedData/Build/Products/Release/WindowPaste.app"
echo "Built $APP"

if [[ "${1:-}" == "--open" ]]; then
  open "$APP"
fi
