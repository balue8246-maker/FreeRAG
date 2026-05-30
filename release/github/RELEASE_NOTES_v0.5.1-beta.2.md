# FreeRAG v0.5.1 Beta 2

This beta refresh keeps the `0.5.1` app build, but changes the distribution quality: the DMG is now Developer ID signed and Apple-notarized.

## Signing and Distribution

- The DMG is signed with `Developer ID Application: yichen ge (989VA3KALZ)`.
- Apple notarization status: `Accepted`.
- The notarization ticket is stapled to the DMG.
- Gatekeeper verification passes with `source=Notarized Developer ID`.
- The DMG includes a clearer install guide for the notarized package.

## Raw Cleanup Safety

- FreeRAG cleanup now moves marked raw entries into `~/Documents/Corpus/_trash/<timestamp>/` instead of permanently deleting them.
- Cleanup writes a `cleanup_manifest.json` for recovery and audit.
- FreeRAG only treats structured `_myrag_done.json` markers as cleanable.
- If moving a raw directory fails, that entry remains in the library index.

## MyRAG Safety

- MyRAG refuses to mark voice entries as processed unless a usable transcript exists.
- A deliberate `--force-mark-voice` override is available for cases where the user has explicitly confirmed the recording was handled elsewhere.
- MyRAG instructions now state that sampling can discover candidates, but cannot justify marking all remaining entries as cleanable.

## CLI and Packaging

- Added `FreeRAG/CLI/freerag`, an offline CLI for agent/script workflows that write directly into the local corpus schema.
- Added `FreeRAG/Packaging/build_release_dmg.sh` for repeatable Developer ID signing, DMG signing, notarization, stapling, Gatekeeper validation, and checksum generation.
- Updated release checklist and docs for the notarized DMG path.

## Assets

- `FreeRAG-0.5.1-build-3.dmg`
- `FreeRAG-0.5.1-build-3.dmg.sha256`
