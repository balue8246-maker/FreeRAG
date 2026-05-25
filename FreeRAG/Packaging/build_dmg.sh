#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NATIVE="$ROOT/FreeRAG"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/FreeRAG/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/FreeRAG/Info.plist")"
APP="$ROOT/dist/FreeRAG.app"
DMG="$ROOT/dist/FreeRAG-${VERSION}-build-${BUILD}.dmg"
STAGE="/private/tmp/freerag-dmg-${VERSION}-${BUILD}"
TMP_DMG="/private/tmp/freerag-dmg-${VERSION}-${BUILD}.rw.dmg"
BACKGROUND="$NATIVE/Resources/Assets/dmg_background.png"

if [ ! -d "$APP" ]; then
  "$ROOT/FreeRAG/Packaging/build_native_app.sh" >/dev/null
fi

rm -rf "$STAGE" "$DMG" "$TMP_DMG"
mkdir -p "$STAGE/MyRAG skill" "$STAGE/assets" "$STAGE/.background"

ditto "$APP" "$STAGE/FreeRAG.app"
ln -s /Applications "$STAGE/Applications"
ditto "$ROOT/shared/skills/myrag" "$STAGE/MyRAG skill/myrag"
ditto "$ROOT/docs/assets" "$STAGE/assets"
ditto "$ROOT/docs/product_overview.html" "$STAGE/Product Overview.html"
ditto "$ROOT/docs/product_overview.en.html" "$STAGE/assets/product_overview.en.html"
ditto "$ROOT/docs/product_overview.zh-CN.html" "$STAGE/assets/product_overview.zh-CN.html"
if [ -f "$BACKGROUND" ]; then
  cp "$BACKGROUND" "$STAGE/.background/background.png"
fi
perl -0pi -e 's/href="product_overview\.en\.html"/href="assets\/product_overview.en.html"/g; s/href="product_overview\.zh-CN\.html"/href="assets\/product_overview.zh-CN.html"/g' "$STAGE/Product Overview.html"

cat > "$STAGE/README.txt" <<EOF
FreeRAG ${VERSION} (${BUILD})

Contents:
- FreeRAG.app
- Applications shortcut
- Product Overview.html
- README.txt
- MyRAG skill/myrag
- assets/

Install:
1. Drag FreeRAG.app onto Applications.
2. Launch FreeRAG from Applications so macOS permissions stay tied to a stable app location.
3. Open Product Overview.html if you want the product overview.
4. Copy MyRAG skill/myrag into your Codex/Claude Code skill directory only when needed.

MyRAG:
FreeRAG collects raw local material. MyRAG reads it in Codex/Claude Code, summarizes by matter/item in the chat, and only marks raw as done after the user confirms the summary.

Permissions:
macOS permissions are tied mainly to bundle id, signing identity, and app location.
Changing only CFBundleShortVersionString/CFBundleVersion should not require re-authorizing.
This beta package is self-signed locally and is not Apple Developer ID signed or notarized.
If macOS blocks it, open System Settings > Privacy & Security and choose Open Anyway.
EOF

hdiutil create \
  -volname "FreeRAG ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$TMP_DMG" >/dev/null

MOUNT_DIR="$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}' | tail -1)"
if [ -z "$MOUNT_DIR" ]; then
  echo "failed to mount temporary DMG" >&2
  exit 1
fi

if [ -d "$MOUNT_DIR/.background" ]; then
  SetFile -a V "$MOUNT_DIR/.background" || true
fi

osascript <<EOF
tell application "Finder"
  tell disk "FreeRAG ${VERSION}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 980, 660}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 72
    set background picture of viewOptions to file ".background:background.png"
    set position of item "FreeRAG.app" of container window to {170, 184}
    set position of item "Applications" of container window to {690, 184}
    set position of item "Product Overview.html" of container window to {122, 366}
    set position of item "README.txt" of container window to {314, 366}
    set position of item "MyRAG skill" of container window to {506, 366}
    set position of item "assets" of container window to {698, 366}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TMP_DMG"

echo "$DMG"
