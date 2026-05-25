# FreeRAG

FreeRAG is a native macOS tool for collecting local raw context: screen evidence, clipboard text/images, and voice notes. It writes material to `~/Documents/Corpus/` so an LLM-side MyRAG skill can later read the fragments, deduplicate noise, and summarize what matters in the current Codex / Claude Code chat.

[简体中文说明](README.zh-CN.md)

## What It Does

- Captures local raw material into a consistent corpus folder.
- Keeps the macOS app small: no automatic cloud analysis, no default OCR, no default transcription.
- Lets MyRAG read the local corpus and produce a matter-by-matter summary table for the user.
- Marks raw material as done only after the user has reviewed the summary and confirmed that the raw evidence has been taken over.

## Product Boundary

FreeRAG collects. MyRAG reads and mines.

FreeRAG does not upload screenshots, clipboard content, or voice recordings by itself. The local corpus is intended for explicit use by the user through Codex / Claude Code and the bundled MyRAG skill.

MyRAG output is table-first: one matter per row, with facts, numbers, people/projects, judgment, risk, next step, evidence, and confidence merged into the same row. Large repeated clipboard images are folded by exact SHA-256 before reading representative samples.

## Repository Layout

```text
FreeRAG/
  Packaging/                 Build scripts for the native app and DMG.
  Resources/Assets/           App icon and status assets.
  Sources/main.swift          Swift/AppKit app implementation.
shared/skills/myrag/          MyRAG skill and local corpus helper script.
docs/                         Product docs, public status, and overview pages.
release/github/               GitHub publication plan, checklist, release notes.
```

## Build

```bash
FreeRAG/Packaging/build_native_app.sh
FreeRAG/Packaging/build_dmg.sh
```

Local build output goes to `dist/`. `dist/` is intentionally ignored by Git; public binaries should be attached to GitHub Releases instead of committed to the source repository.

Current app version: `0.5.1`, build `3`.

## Install

1. Download the DMG from a GitHub Release.
2. Drag `FreeRAG.app` to `/Applications`.
3. Launch it from `/Applications` so macOS permissions stay tied to a stable app location.
4. Grant Screen Recording, Accessibility, and Microphone permissions when needed.
5. Copy the bundled `myrag` skill into your Codex / Claude Code skill directory if you want LLM-side corpus mining.

This beta build uses a self-signed local stable signing identity and is not Apple Developer ID signed or notarized. macOS may show Gatekeeper warnings.

## Local Corpus

```text
~/Documents/Corpus/
  _index.json
  _library.json
  README_FOR_LLM.md
  screen/
  clipboard/
  voice/
  processed/
```

`processed/` is optional and should contain only high-density summaries, worklogs, project notes, or confirmed representative evidence. MyRAG should not convert hundreds of noisy raw entries into hundreds of processed directories.

## Privacy

See [PRIVACY.md](PRIVACY.md). Short version: raw evidence stays local by default. Do not commit or publish a corpus folder, screenshots, recordings, transcripts, API keys, or private team/customer data.

## Security

See [SECURITY.md](SECURITY.md) for reporting and release-safety notes.

## Product Pages

- [Simplified Chinese product overview](docs/product_overview.zh-CN.html)
- [English product overview](docs/product_overview.en.html)

## License

MIT. See [LICENSE](LICENSE).
