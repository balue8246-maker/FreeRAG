# Changelog

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
