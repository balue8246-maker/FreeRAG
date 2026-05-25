# FreeRAG FAQ

## What is FreeRAG?

FreeRAG is a native macOS menu bar app for collecting local raw context: screenshots, clipboard text/images, and voice notes. It writes that material to `~/Documents/Corpus/`.

## What problem does it solve?

LLM and coding-agent work often loses context that lives outside the chat: screenshots, copied snippets, app states, meetings, and temporary notes. FreeRAG makes those fragments easy to collect locally so they can be mined later.

## Is this a screenshot tool?

Not exactly. FreeRAG uses screenshots as raw evidence, but the product goal is local context collection for later LLM use.

## What is MyRAG?

MyRAG is the bundled LLM-side workflow. It reads the local corpus in Codex / Claude Code, folds repeated material, groups entries by matter, and summarizes evidence in the chat.

## Does FreeRAG upload my screenshots, clipboard, or recordings?

No. FreeRAG does not upload raw material by itself. It writes to your local `~/Documents/Corpus/` folder.

If you ask Codex, Claude Code, or another LLM tool to read that corpus, then that tool's own privacy boundary applies.

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

The current beta is open source but not Apple Developer ID signed or notarized. macOS may warn before opening it.

The app currently uses a self-signed local stable signing identity for local beta builds. That is better than ad-hoc signing for local permission stability, but it is not the same as Apple Developer ID signing.

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
- let MyRAG / LLM tooling decide what is worth OCR, transcription, or deeper reading.

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
4. FreeRAG cleanup removes only marked raw directories.

`processed/` is not deleted by FreeRAG cleanup.

