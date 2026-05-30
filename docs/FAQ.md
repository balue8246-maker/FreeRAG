# FreeRAG FAQ

## What is FreeRAG?

FreeRAG is a native macOS menu bar app for collecting local raw context: screenshots, clipboard text/images, and voice notes. It writes that material to `~/Documents/Corpus/`.

## What problem does it solve?

LLM and coding-agent work often loses context that lives outside the chat: screenshots, copied snippets, app states, meetings, and temporary notes. FreeRAG makes those fragments easy to collect locally so they can be mined later.

## Is this a screenshot tool?

Not exactly. FreeRAG uses screenshots as raw evidence, but the product goal is local context collection for later LLM use.

## What is MyRAG?

MyRAG is the bundled LLM-side workflow. It reads the local corpus in Codex / Claude Code, folds repeated material, groups entries by matter, and summarizes evidence in the chat.

It is intentionally split into two files:

- `SKILL.md` for normal runtime corpus mining.
- `INSTALL_ADAPTERS.md` for model-specific Vision / ASR setup.

If your model cannot read images or transcribe audio, configure a Vision or ASR backend with `shared/skills/myrag/INSTALL_ADAPTERS.md`.

## Does FreeRAG upload my screenshots, clipboard, or recordings?

No. FreeRAG does not upload raw material by itself. It writes to your local `~/Documents/Corpus/` folder.

If you ask Codex, Claude Code, or another LLM tool to read that corpus, then that tool's own privacy boundary applies.

## Can agents control FreeRAG from the command line?

The first CLI layer is offline: `FreeRAG/CLI/freerag` writes directly to `~/Documents/Corpus/` and updates the same `_index.json` / `_library.json` files used by the app.

Examples:

```bash
FreeRAG/CLI/freerag note "Save this context"
FreeRAG/CLI/freerag shot
FreeRAG/CLI/freerag list --limit 10
```

This CLI does not control the running menu bar app. Commands that capture the screen use the terminal or agent process's macOS permissions.

## Where is the data stored?

```text
~/Documents/Corpus/
```

with raw folders:

```text
screen/
clipboard/
voice/
```

and optional processed material:

```text
processed/
```

## Why does macOS show a security warning?

The current beta DMG is Developer ID signed and Apple-notarized, so it should pass normal Gatekeeper checks.

macOS may still show normal first-run or permission prompts. FreeRAG needs Screen Recording for screenshots, Accessibility for front-window context, and Microphone for local voice notes.

Normal beta install flow:

1. Drag `FreeRAG.app` into `/Applications`.
2. Open it from `/Applications`.
3. Grant requested macOS privacy permissions as needed.

## Why do permissions sometimes look enabled but not work?

macOS TCC permissions are tied to app identity, signing, and location. If you run different copies of the app, move it around, or switch from an ad-hoc build to a signed build, macOS may show confusing stale permission state.

Use `/Applications/FreeRAG.app` as the stable location. If needed, reset:

```bash
tccutil reset ScreenCapture com.acegent.freerag
tccutil reset Accessibility com.acegent.freerag
tccutil reset Microphone com.acegent.freerag
```

Then launch FreeRAG and grant permissions again.

## Why not do OCR and transcription inside the app?

FreeRAG intentionally keeps the app small. The current approach is:

- collect raw material cheaply in the macOS app;
- let MyRAG / LLM tooling decide what is worth OCR, transcription, or deeper reading;
- keep model-specific Vision / ASR setup in `INSTALL_ADAPTERS.md` instead of baking it into the app or the runtime skill.

This avoids turning every noisy raw entry into expensive processed output.

## Who is this for?

FreeRAG is most useful if you:

- work with Codex / Claude Code or similar coding agents;
- often need to explain app states, permissions, UI issues, or copied snippets;
- prefer local-first raw collection;
- want the LLM to summarize by matter after the fact.

## Who is this not for?

It is probably not a fit if you want:

- a polished notarized commercial Mac app today;
- automatic cloud OCR/transcription built in;
- team sync or cloud knowledge base features;
- a general-purpose screenshot annotation tool.

## Can I delete raw entries?

Yes, but the intended flow is:

1. MyRAG summarizes the relevant material.
2. The user confirms the raw evidence has been taken over.
3. MyRAG writes `_myrag_done.json`.
4. FreeRAG cleanup moves only marked raw directories to `~/Documents/Corpus/_trash/`.

`processed/` is not deleted by FreeRAG cleanup, and moved raw material remains recoverable from `_trash/`.
