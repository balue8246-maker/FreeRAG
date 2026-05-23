#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NATIVE="$ROOT/FreeRAG"
APP="$ROOT/dist/FreeRAG.app"
EXE="$APP/Contents/MacOS/FreeRAG"
ICON="$NATIVE/Resources/Assets/freerag.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc \
  -module-cache-path /private/tmp/freerag-swift-module-cache \
  -target arm64-apple-macosx13.0 \
  "$NATIVE/Sources/main.swift" \
  -framework AppKit \
  -framework AVFoundation \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -o "$EXE"

cp "$NATIVE/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ICON" ]; then
  cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
fi

codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
