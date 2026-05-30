#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/FreeRAG/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/FreeRAG/Info.plist")"
APP="$ROOT/dist/FreeRAG.app"
DMG="$ROOT/dist/FreeRAG-${VERSION}-build-${BUILD}.dmg"
SHA_FILE="$DMG.sha256"
NOTARY_PROFILE="${FREERAG_NOTARY_PROFILE:-freerag-notary}"
SIGN_IDENTITY="${FREERAG_CODESIGN_IDENTITY:-}"

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | awk -F '"' '/Developer ID Application:/ {print $2; exit}'
  )"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  echo "error: no Developer ID Application signing identity found" >&2
  exit 1
fi

echo "Using signing identity: $SIGN_IDENTITY"
echo "Using notary profile: $NOTARY_PROFILE"

verify_packaged_app() {
  local dmg="$1"
  local mount_dir
  mount_dir="$(
    hdiutil attach "$dmg" -nobrowse -readonly -noverify \
      | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}' \
      | tail -1
  )"
  if [ -z "$mount_dir" ]; then
    echo "error: failed to mount DMG for verification" >&2
    return 1
  fi
  codesign --verify --deep --strict --verbose=2 "$mount_dir/FreeRAG.app"
  if ! codesign -d --entitlements - "$mount_dir/FreeRAG.app" 2>/dev/null \
    | grep -F "com.apple.security.device.audio-input" >/dev/null; then
    echo "error: packaged app is missing microphone audio-input entitlement" >&2
    hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
    return 1
  fi
  hdiutil detach "$mount_dir" >/dev/null
}

FREERAG_CODESIGN_IDENTITY="$SIGN_IDENTITY" \
FREERAG_CODESIGN_HARDENED=1 \
  "$ROOT/FreeRAG/Packaging/build_native_app.sh" >/dev/null

codesign --verify --deep --strict --verbose=2 "$APP"

FREERAG_DISTRIBUTION=notarized \
  "$ROOT/FreeRAG/Packaging/build_dmg.sh" >/dev/null

verify_packaged_app "$DMG"

codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG" >/dev/null
codesign --verify --verbose=2 "$DMG"

xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t install "$DMG"
verify_packaged_app "$DMG"

shasum -a 256 "$DMG" > "$SHA_FILE"
cat "$SHA_FILE"
echo "$DMG"
