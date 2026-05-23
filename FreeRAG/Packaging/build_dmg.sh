#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/FreeRAG/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/FreeRAG/Info.plist")"
APP="$ROOT/dist/FreeRAG.app"
DMG="$ROOT/dist/FreeRAG-${VERSION}-build-${BUILD}.dmg"
STAGE="/private/tmp/freerag-dmg-${VERSION}-${BUILD}"

if [ ! -d "$APP" ]; then
  "$ROOT/FreeRAG/Packaging/build_native_app.sh" >/dev/null
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE/Copy MyRAG skill to Codex-Claude"

ditto "$APP" "$STAGE/FreeRAG.app"
ln -s /Applications "$STAGE/Applications"
ditto "$ROOT/shared/skills/myrag" "$STAGE/Copy MyRAG skill to Codex-Claude/myrag"
ditto "$ROOT/docs/product_overview.html" "$STAGE/Read Me - Product Overview.html"

cat > "$STAGE/README.txt" <<EOF
FreeRAG ${VERSION} (${BUILD})

Contents:
- FreeRAG.app
- Applications shortcut
- Read Me - Product Overview.html
- Copy MyRAG skill to Codex-Claude/myrag

Install:
1. Open Read Me - Product Overview.html for the product overview.
2. Drag FreeRAG.app onto Applications.
3. Launch FreeRAG from Applications so macOS permissions stay tied to a stable app location.
4. Copy Copy MyRAG skill to Codex-Claude/myrag into your Codex/Claude Code skill directory when needed.

MyRAG:
FreeRAG collects raw local material. MyRAG reads it in Codex/Claude Code, summarizes by matter/item in the chat, and only marks raw as done after the user confirms the summary.

Permissions:
macOS permissions are tied mainly to bundle id, signing identity, and app location.
Changing only CFBundleShortVersionString/CFBundleVersion should not require re-authorizing.
This local package is ad-hoc signed and not notarized.
EOF

hdiutil create \
  -volname "FreeRAG ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "$DMG"
