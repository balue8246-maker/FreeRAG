# Changelog

## v0.5.0-beta.1 - Unreleased

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
