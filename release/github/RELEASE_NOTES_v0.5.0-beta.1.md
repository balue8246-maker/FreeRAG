# FreeRAG v0.5.0 Beta 1

FreeRAG is a local-first macOS raw context collector for LLM workflows. It captures the fragments that are hard to API into an LLM: screenshots, current screen states, clipboard text/images, voice notes, and short-lived thinking traces.

## Highlights

- Native macOS menu bar app.
- Screen, clipboard, and voice raw material collection.
- Local corpus under `~/Documents/Corpus/`.
- Corpus browser with search, open, Finder reveal, and clean-processed-raw flow.
- Bundled MyRAG skill for Codex / Claude Code.
- MyRAG goldmine workflow: summarize by matter, one row per item, with evidence and next steps.
- Exact SHA-256 clustering for repeated clipboard images.

## Privacy

FreeRAG does not upload raw material by itself. It stores local evidence under `~/Documents/Corpus/`. MyRAG reads that corpus only when the user explicitly invokes it in an LLM tool.

See `PRIVACY.md` before using FreeRAG with sensitive material.

## macOS Permissions

FreeRAG may request:

- Screen Recording;
- Accessibility;
- Microphone.

Launch the app from `/Applications` so macOS permissions stay tied to a stable app location.

## Known Limitations

- This beta build is ad-hoc signed and not notarized.
- OCR and ASR are not built into the app yet.
- MyRAG depends on the user's Codex / Claude Code environment.

## Assets

- `FreeRAG-0.5.0-build-2.dmg`
- `FreeRAG-0.5.0-build-2.dmg.sha256`
