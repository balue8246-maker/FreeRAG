#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NATIVE="$ROOT/FreeRAG"
APP="$ROOT/dist/FreeRAG.app"
EXE="$APP/Contents/MacOS/FreeRAG"
ICON="$NATIVE/Resources/Assets/freerag.icns"
STATUS_ICON="$NATIVE/Resources/Assets/freerag_status_template.png"
DEFAULT_SIGN_IDENTITY="FreeRAG Local Developer"
SIGN_IDENTITY="${FREERAG_CODESIGN_IDENTITY:-}"
HARDENED_RUNTIME="${FREERAG_CODESIGN_HARDENED:-0}"

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
if [ -f "$STATUS_ICON" ]; then
  cp "$STATUS_ICON" "$APP/Contents/Resources/StatusIcon.png"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  if security find-identity -v -p codesigning | grep -F "\"$DEFAULT_SIGN_IDENTITY\"" >/dev/null; then
    SIGN_IDENTITY="$DEFAULT_SIGN_IDENTITY"
  else
    SIGN_IDENTITY="-"
    echo "warning: '$DEFAULT_SIGN_IDENTITY' signing identity not found; using ad-hoc signing" >&2
  fi
fi

CODE_SIGN_ARGS=(--force --deep --sign "$SIGN_IDENTITY")
if [ "$HARDENED_RUNTIME" = "1" ]; then
  CODE_SIGN_ARGS+=(--options runtime --timestamp)
fi
codesign "${CODE_SIGN_ARGS[@]}" "$APP" >/dev/null
echo "$APP"
