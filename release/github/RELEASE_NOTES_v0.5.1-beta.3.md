# FreeRAG v0.5.1 Beta 3

This is a small hotfix release for the notarized `0.5.1` beta.

## Microphone Permission Fix

- Bumped the app build to `4`.
- Added the hardened-runtime `com.apple.security.device.audio-input` entitlement so macOS can grant microphone access in the notarized build.
- Updated the settings window so a previously denied microphone permission opens System Settings instead of silently re-requesting access.

## Assets

- `FreeRAG-0.5.1-build-4.dmg`
- `FreeRAG-0.5.1-build-4.dmg.sha256`
