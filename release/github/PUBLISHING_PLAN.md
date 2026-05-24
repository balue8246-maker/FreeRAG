# GitHub Publishing Plan

Goal: publish FreeRAG as an open-source beta project that is easy to understand, safe to try, and clear about privacy.

## Positioning

FreeRAG is a local-first raw context collector for macOS. It helps users collect raw evidence that is otherwise hard to API into an LLM: screen states, clipboard fragments, screenshots, voice notes, product dashboards, chats, and thinking traces.

MyRAG is the LLM-side skill that mines those fragments into a matter-by-matter summary table.

## Suggested GitHub Repo

- Name: `FreeRAG`
- Description: `Local-first macOS raw context collector for LLM workflows. Capture screen, clipboard, and voice; mine it later with MyRAG.`
- Topics: `macos`, `swift`, `appkit`, `llm`, `rag`, `local-first`, `productivity`, `clipboard`, `screen-capture`, `privacy`
- Website: GitHub Pages pointing to `docs/product_overview.html`

## Publishing Shape

- Source repository: no `dist/`, no local corpus, no secrets.
- GitHub Release: attach DMG and checksum.
- README: English first, with Simplified Chinese link.
- Product pages: English and Simplified Chinese.
- License: MIT.

## First Release Tag

Use:

```bash
git tag v0.5.0-beta.1
```

Release title:

```text
FreeRAG v0.5.0 Beta 1
```

Release assets:

- `FreeRAG-0.5.0-build-2.dmg`
- `FreeRAG-0.5.0-build-2.dmg.sha256`

## Do Not Publish

- `~/Documents/Corpus/`
- real screenshots, recordings, transcripts, or tables;
- API keys or local keychain dumps;
- private customer/team/project data;
- `.DS_Store`;
- local-only debug files.
