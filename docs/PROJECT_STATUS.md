# Project Status

FreeRAG is currently prepared for a public GitHub beta release.

## Current Release Target

- Version: `0.5.0`
- Build: `2`
- Suggested tag: `v0.5.0-beta.1`
- License: MIT

## Product Boundary

- FreeRAG app: collects local raw material on macOS.
- MyRAG skill: reads the local corpus in Codex / Claude Code and summarizes it by matter.
- Raw material cleanup happens only after the user confirms the MyRAG summary.

## Current Limitations

- The beta build is ad-hoc signed and not notarized.
- OCR and ASR are not built into the app yet.
- MyRAG depends on the user's LLM environment.
- Public release binaries should be attached to GitHub Releases, not committed to source.

## Release Prep Documents

See:

- `release/github/PUBLISHING_PLAN.md`
- `release/github/RELEASE_CHECKLIST.md`
- `release/github/RELEASE_NOTES_v0.5.0-beta.1.md`
