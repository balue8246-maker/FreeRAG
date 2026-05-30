# Project Status

FreeRAG is currently prepared for a public GitHub beta release.

## Current Release Target

- Version: `0.5.1`
- Build: `3`
- Suggested tag: `v0.5.1-beta.2`
- License: MIT

## Product Boundary

- FreeRAG app: collects local raw material on macOS.
- MyRAG runtime skill: reads the local corpus in Codex / Claude Code and summarizes it by matter.
- MyRAG adapter guide: documents Vision / ASR setup for model environments that cannot directly read images or transcribe audio.
- Raw material cleanup happens only after the user confirms the MyRAG summary.

## Current Limitations

- The beta DMG is Developer ID signed and Apple-notarized.
- OCR and ASR are not built into the app; they are configured on the MyRAG / LLM-tool side when needed.
- MyRAG still depends on the user's LLM environment and configured local tools.
- Public release binaries should be attached to GitHub Releases, not committed to source.

## Release Prep Documents

See:

- `release/github/PUBLISHING_PLAN.md`
- `release/github/RELEASE_CHECKLIST.md`
- `release/github/RELEASE_NOTES_v0.5.1-beta.2.md`
