# FreeRAG Launch Kit

This is a lightweight launch pack for getting the first real users and feedback. The goal is not to maximize stars directly. The goal is to get 20 people to understand the problem, try the app, and report where the flow breaks.

## One-Line Pitch

FreeRAG is a tiny macOS menu bar app that turns screenshots, clipboard fragments, and voice notes into a local corpus for Codex / Claude Code workflows.

## Short Pitch

I built FreeRAG because LLM work often loses context in the places agents cannot naturally see: screenshots, copied snippets, app states, meetings, and half-finished thoughts.

FreeRAG collects that raw material locally under `~/Documents/Corpus/`. The bundled MyRAG skill can then read recent material inside Codex / Claude Code, fold repeated screenshots, and summarize by matter in a table.

The app does not upload raw material by itself. It is a local-first collector plus an LLM-side mining workflow.

## Show HN Draft

Title:

```text
Show HN: FreeRAG - a tiny Mac menu bar app for collecting local context for LLMs
```

Body:

```text
I built FreeRAG because my coding-agent context was scattered across screenshots, clipboard snippets, browser tabs, voice notes, and transient app states.

FreeRAG is a small native macOS menu bar app. It collects raw material locally into ~/Documents/Corpus/: screen evidence, clipboard text/images, and voice notes. A bundled MyRAG skill can then read that local corpus in Codex / Claude Code, fold duplicates, and summarize by matter in a table.

It does not upload raw material by itself. The current beta is open source, local-first, and intentionally simple. OCR/ASR are not productized inside the app yet.

I am looking for feedback on:
- whether this context-collection workflow makes sense;
- where macOS permissions or installation feel rough;
- whether the MyRAG side should prioritize Codex, Claude Code, Obsidian, or something else next.
```

## X / LinkedIn Draft

```text
I built a tiny macOS menu bar app for a problem I keep hitting with coding agents:

useful context lives in screenshots, clipboard snippets, voice notes, and short-lived app states.

FreeRAG collects that raw material locally into ~/Documents/Corpus/, then a bundled MyRAG skill can mine it inside Codex / Claude Code.

Open source beta:
https://github.com/balue8246-maker/FreeRAG
```

## Reddit Draft

```text
I made a small local-first macOS app for collecting context that LLM/coding agents usually cannot see.

FreeRAG lives in the menu bar and saves screenshots, clipboard text/images, and voice notes into ~/Documents/Corpus/. It ships with a MyRAG skill that can read that local corpus from Codex / Claude Code, deduplicate repeated screenshots, and summarize by matter.

It does not upload raw material by itself. Current beta is open source and still rough around signing/notarization.

I am not trying to sell anything. I mostly want feedback from people who use local-first or coding-agent workflows:
- Is this context collection problem real for you?
- Would you want this to connect to Codex, Claude Code, Obsidian, or local LLM tooling first?
- What would make the install/trust story acceptable?
```

## V2EX / 即刻 Draft

```text
做了一个很小的 macOS 菜单栏工具 FreeRAG，用来解决和 Codex / Claude Code 协作时上下文到处散的问题。

它不做复杂 AI，不默认联网分析，只负责把截图、剪贴板文字/图片、语音笔记这些 raw 材料低成本收进本地 ~/Documents/Corpus/。

后面用仓库里附带的 MyRAG skill，在 Codex / Claude Code 对话里读取这些材料，先去重，再按“事项”输出一行一项的 summary 表格，让人判断哪些值得保存、哪些 raw 可以清理。

目前是开源 beta，macOS signing/notarization 还不完整。想找真实用户反馈：
- 这个工作流你会不会用？
- 更希望先接 Codex / Claude Code / Obsidian / 本地模型？
- 安装和权限哪里最劝退？

GitHub:
https://github.com/balue8246-maker/FreeRAG
```

## First Week Checklist

1. Pin the latest release in every post.
2. Use one short video or GIF before posting to Product Hunt or larger channels.
3. Ask for feedback, not stars.
4. Reply to every concrete installation or permission issue within 24 hours.
5. Convert repeated feedback into GitHub issues with `good first issue` or `help wanted`.
6. Ship a small patch release after the first feedback batch.

## Good First Issues To Open

- Add a real demo GIF to README.
- Improve Gatekeeper / permission troubleshooting docs.
- Add a MyRAG end-to-end example with sample anonymized corpus.
- Add an Obsidian export target for processed worklogs.
- Split `FreeRAG/Sources/main.swift` into smaller AppKit modules.

