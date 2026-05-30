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
FREERAG_DISTRIBUTION="${FREERAG_DISTRIBUTION:-beta}"

if [ ! -d "$APP" ]; then
  "$ROOT/FreeRAG/Packaging/build_native_app.sh" >/dev/null
fi

rm -rf "$STAGE" "$DMG" "$TMP_DMG"
mkdir -p "$STAGE/MyRAG skill" "$STAGE/.background"

ditto --noextattr --noqtn "$APP" "$STAGE/FreeRAG.app"
xattr -cr "$STAGE/FreeRAG.app" 2>/dev/null || true
ln -s /Applications "$STAGE/Applications"
ditto "$ROOT/shared/skills/myrag" "$STAGE/MyRAG skill/myrag"
if [ -f "$BACKGROUND" ]; then
  cp "$BACKGROUND" "$STAGE/.background/background.png"
fi

if [ "$FREERAG_DISTRIBUTION" = "notarized" ]; then
  DISTRIBUTION_EN="FreeRAG is distributed through GitHub Releases as a Developer ID signed and Apple-notarized DMG."
  DISTRIBUTION_ZH="FreeRAG 通过 GitHub Release 发布 DMG。当前包已使用 Apple Developer ID 签名并完成 Apple notarization。"
  PERMISSIONS_EN="This package is Developer ID signed and notarized. If macOS still blocks launch, open System Settings > Privacy & Security and choose Open Anyway."
else
  DISTRIBUTION_EN="FreeRAG is distributed through GitHub Releases as a DMG. This beta is not Apple Developer ID signed or notarized, so the first launch may require manual approval in macOS settings."
  DISTRIBUTION_ZH="FreeRAG 通过 GitHub Release 发布 DMG。当前 beta 尚未使用 Apple Developer ID 签名或公证，所以首次打开时可能需要在 macOS 设置里手动允许。"
  PERMISSIONS_EN="This beta package is self-signed locally and is not Apple Developer ID signed or notarized. If macOS blocks it, open System Settings > Privacy & Security and choose Open Anyway."
fi

cat > "$STAGE/Install Guide.txt" <<EOF
FreeRAG ${VERSION} (${BUILD})

Contents:
- FreeRAG.app
- Applications shortcut
- Install Guide.txt
- MyRAG skill/myrag

Install:
1. Drag FreeRAG.app onto Applications.
2. Launch FreeRAG from Applications so macOS permissions stay tied to a stable app location.
3. If macOS says Apple cannot verify FreeRAG, click Done, then open System Settings > Privacy & Security > Open Anyway.
4. Copy MyRAG skill/myrag into your Codex/Claude Code skill directory only when needed.

中文安装：
1. 把 FreeRAG.app 拖到 Applications。
2. 从 Applications 启动，避免权限绑定到临时位置。
3. 如果 macOS 提示“Apple 无法验证 FreeRAG”，点“完成”，再到 系统设置 > 隐私与安全性 > 仍要打开。
4. 如需 MyRAG，把 MyRAG skill/myrag 复制到 Codex / Claude Code 的 skill 目录。

MyRAG skill install:
- Codex: copy MyRAG skill/myrag into your Codex skills directory.
- Claude Code: copy MyRAG skill/myrag into your Claude Code skills directory.
- Use SKILL.md for normal corpus mining.
- Use INSTALL_ADAPTERS.md only when your model needs Vision/OCR or ASR setup.

Open Source Beta:
${DISTRIBUTION_EN}

开源 Beta：
${DISTRIBUTION_ZH}

Permissions:
macOS permissions are tied mainly to bundle id, signing identity, and app location.
Changing only CFBundleShortVersionString/CFBundleVersion should not require re-authorizing.
${PERMISSIONS_EN}
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
set mountPath to "$MOUNT_DIR"
tell application "Finder"
  set dmgFolder to POSIX file mountPath as alias
  open dmgFolder
  delay 0.2
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set the bounds of container window of dmgFolder to {120, 120, 980, 700}
  set viewOptions to the icon view options of container window of dmgFolder
  tell viewOptions
    set arrangement to not arranged
    set icon size to 72
  end tell
  set background picture of viewOptions to file ".background:background.png" of dmgFolder
  set position of item "FreeRAG.app" of dmgFolder to {170, 212}
  set position of item "Applications" of dmgFolder to {690, 212}
  set position of item "Install Guide.txt" of dmgFolder to {255, 390}
  set position of item "MyRAG skill" of dmgFolder to {535, 390}
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
EOF

hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TMP_DMG"

echo "$DMG"
