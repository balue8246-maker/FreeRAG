# Project Status

FreeRAG `v0.5.1-beta.3` is the current pause point for this version line.

## Current Version

- Version: `0.5.1`
- Build: `4`
- Release tag: `v0.5.1-beta.3`
- License: MIT

## Wrap-Up State

- The public DMG path should point to the Developer ID signed and Apple-notarized beta hotfix package.
- Build `4` fixes microphone access for hardened-runtime builds by adding the required audio-input entitlement.
- The repo is intended to stay source-only: release binaries remain attached to GitHub Releases, not committed.
- The core product boundary is stable for now: FreeRAG collects local raw material; MyRAG reads, mines, summarizes, and only marks raw material after user confirmation.
- Further work should be treated as a new iteration rather than part of this version wrap-up.

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
- `release/github/RELEASE_NOTES_v0.5.1-beta.3.md`
