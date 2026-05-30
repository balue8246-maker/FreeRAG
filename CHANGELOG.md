# Changelog

## v0.5.1-beta.3 - 2026-05-30

- Bumped the `0.5.1` app build to `4` for a microphone permission hotfix.
- Added the hardened-runtime entitlement for microphone audio input.
- Updated the settings window so microphone permission requests open System Settings when macOS has already denied or restricted access.

## v0.5.1-beta.2 - 2026-05-30

- Kept the `0.5.1` app version and build `3`, but upgraded the public DMG distribution to Developer ID signed and Apple-notarized.
- Added repeatable Developer ID release packaging through `FreeRAG/Packaging/build_release_dmg.sh`, including signing, notarization, stapling, Gatekeeper validation, and checksum generation.
- Added the offline `FreeRAG/CLI/freerag` helper for agent/script workflows that write directly to the local corpus schema.
- Made processed-raw cleanup recoverable by moving marked raw entries into `~/Documents/Corpus/_trash/<timestamp>/` with a cleanup manifest instead of deleting them permanently.
- Tightened MyRAG safety rules: only structured `_myrag_done.json` markers are cleanable, voice entries require a usable transcript before marking, and sampling cannot justify marking unreviewed entries as processed.
- Updated public README, release notes, release checklist, and product docs for the notarized beta distribution path.

## v0.5.1-beta.1 - 2026-05-25

- Fixed the HUD bar not returning above full-screen Spaces after hiding it and using the menu bar "Show HUD" command.
- Reworked HUD hiding to avoid removing the panel from macOS Space/full-screen association.
- Added stable local code signing support through `FreeRAG Local Developer`, with `FREERAG_CODESIGN_IDENTITY` override for future Developer ID signing.
- Updated the beta package from ad-hoc signing to self-signed local stable signing. It is still not Apple Developer ID signed or notarized.

## v0.5.0-beta.1 - 2026-05-25

- Native macOS menu bar app for collecting screen, clipboard, and voice raw material.
- Local corpus written to `~/Documents/Corpus/`.
- Corpus browser with search, Finder reveal, and clean-processed-raw flow.
- MyRAG skill bundled for Codex / Claude Code.
- MyRAG goldmine workflow: table-first summary, one matter per row, user confirmation before raw cleanup.
- Clipboard image exact SHA-256 clustering for repeated screenshots.
- DMG packaging script with bundled product overview and MyRAG skill.

Known limitations:

- Build is ad-hoc signed and not notarized.
- OCR and ASR are not productized inside the app.
- MyRAG depends on the user's LLM environment.
