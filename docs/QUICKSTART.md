# FreeRAG Quickstart

This guide is for people who want to try FreeRAG quickly without reading the whole repository.

## 1. Download

Download the latest DMG from:

```text
https://github.com/balue8246-maker/FreeRAG/releases/latest
```

Open the DMG and drag `FreeRAG.app` to `/Applications`.

Use `/Applications/FreeRAG.app` as the stable launch location. macOS privacy permissions are tied to app identity and location, so repeatedly running random extracted copies may cause permission confusion.

## 2. First Launch

Open `FreeRAG.app` from `/Applications`.

The current beta is not Apple Developer ID signed or notarized. If macOS blocks it:

1. Open System Settings.
2. Go to Privacy & Security.
3. Scroll to the security warning.
4. Choose Open Anyway.

## 3. Grant Permissions

FreeRAG may ask for:

- Screen Recording: needed for screenshots and continuous screen evidence.
- Accessibility: needed to read the current front window title and region.
- Microphone: needed for local voice notes.

After granting Screen Recording or Accessibility, restart FreeRAG if the app still says the permission is not active.

## 4. Collect Raw Context

Use the floating HUD:

- Record: continuously collect screen evidence.
- Shot: take one screen capture.
- Mic: record a local voice note.
- Folder: open the local corpus browser.
- Hide: hide the HUD.

Clipboard text and images are collected in the background when the clipboard changes.

## 5. Find The Corpus

FreeRAG writes raw material to:

```text
~/Documents/Corpus/
```

The important folders are:

```text
screen/
clipboard/
voice/
processed/
```

Raw entries usually include `_meta.json`, `llm_context.md`, and the original material.

## 6. Use MyRAG

The DMG includes a `myrag` skill folder. Copy it into your Codex / Claude Code skill directory if you want LLM-side corpus mining.

MyRAG is split into two responsibilities:

- `SKILL.md`: the normal runtime workflow for searching, deduplicating, reading, and summarizing the corpus.
- `INSTALL_ADAPTERS.md`: setup instructions for model environments that need external Vision / ASR support.

If your current LLM environment cannot read images or transcribe audio, follow the adapter guide:

```text
shared/skills/myrag/INSTALL_ADAPTERS.md
```

Useful local commands:

```bash
python3 shared/skills/myrag/scripts/myrag_search.py --recent 10 --format text
python3 shared/skills/myrag/scripts/myrag_search.py --suggest-projects 40 --format text
python3 shared/skills/myrag/scripts/myrag_search.py --image-clusters 20
```

MyRAG should summarize by matter in the chat first. It should only mark raw material as processed after the user confirms that the evidence has been taken over.

## Troubleshooting

### The app says a permission is not active, but macOS shows it is enabled

Try these in order:

1. Quit FreeRAG.
2. Make sure you are launching the copy in `/Applications`.
3. Toggle the permission off and on in System Settings.
4. Launch FreeRAG again.

If a beta build was previously ad-hoc signed, macOS may have stale TCC permission records. Resetting permissions can help, but it will require granting them again:

```bash
tccutil reset ScreenCapture com.acegent.freerag
tccutil reset Accessibility com.acegent.freerag
tccutil reset Microphone com.acegent.freerag
```

### The HUD is not visible in a full-screen app

Use the macOS menu bar FreeRAG icon and choose Show HUD. If the HUD still does not appear, quit and reopen FreeRAG.

### The corpus contains many repeated clipboard images

That is expected when a workflow repeatedly copies the same image. MyRAG can fold exact duplicates:

```bash
python3 shared/skills/myrag/scripts/myrag_search.py --image-clusters 20
```

### I do not want FreeRAG to collect clipboard material

This beta starts clipboard collection automatically. Do not run the app around sensitive clipboard workflows unless you are comfortable with local raw material being saved under `~/Documents/Corpus/`.
