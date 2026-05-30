# Terminal Release Handoff

This project is functionally complete for `v0.5.1-beta.3`; the remaining task is to produce a clean public DMG from a Terminal-based release environment.

## Goal

Produce a FreeRAG DMG that can be sent to other Mac users:

- Developer ID signed with `Developer ID Application: yichen ge (989VA3KALZ)`.
- Apple notarized and stapled.
- Gatekeeper accepted.
- Final mounted DMG contains a `FreeRAG.app` whose signature verifies.
- Final mounted app includes `com.apple.security.device.audio-input`.

## Why Terminal

The Codex desktop app execution environment can attach `com.apple.provenance` extended attributes to generated app bundle files. In this project, that polluted code-signing verification and produced confusing intermediate DMGs. Run the final release from Terminal.app or Terminal Codex instead.

## Important State

- Bundle id: `com.acegent.freerag`
- Version: `0.5.1`
- Build: `4`
- Intended release tag: `v0.5.1-beta.3`
- Notary profile: `freerag-notary`
- Entitlement file: `FreeRAG/Packaging/FreeRAG.entitlements`
- Required entitlement: `com.apple.security.device.audio-input`

## Release Command

From the repo root:

```bash
cd "/Users/acegent/Documents/GPT Projects/FreeRAG"
git status --short
plutil -lint FreeRAG/Info.plist FreeRAG/Packaging/FreeRAG.entitlements
FreeRAG/Packaging/build_release_dmg.sh
```

The release script now verifies the packaged app before DMG signing and again after notarization/stapling.

## Manual Final Checks

If you want to double-check manually after the script succeeds:

```bash
cd "/Users/acegent/Documents/GPT Projects/FreeRAG"
hdiutil attach dist/FreeRAG-0.5.1-build-4.dmg -nobrowse -readonly -noverify
codesign --verify --deep --strict --verbose=2 "/Volumes/FreeRAG 0.5.1/FreeRAG.app"
codesign -d --entitlements - "/Volumes/FreeRAG 0.5.1/FreeRAG.app"
spctl -a -vvv -t install dist/FreeRAG-0.5.1-build-4.dmg
hdiutil detach "/Volumes/FreeRAG 0.5.1"
cat dist/FreeRAG-0.5.1-build-4.dmg.sha256
```

The entitlement output must include:

```text
com.apple.security.device.audio-input
```

## User Permission Note

Future upgrades should inherit macOS privacy permissions as long as the bundle id, Team ID, Developer ID signing identity, and install location remain stable. Users who already installed the broken build `3` may need to reset microphone permission once:

```bash
tccutil reset Microphone com.acegent.freerag
```
