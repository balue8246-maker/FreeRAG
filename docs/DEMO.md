# FreeRAG Demo Walkthrough

This walkthrough shows the intended flow without requiring a video.

## Scenario

You are working with a coding agent. Useful context appears in places that are easy for you to see but hard for the agent to recover later:

- a permissions screen;
- a product page;
- a copied error message;
- a quick voice note;
- a UI state that changes after a few seconds.

FreeRAG captures those fragments locally so they can be mined later.

## Flow

```text
Mac screen / clipboard / microphone
        |
        v
FreeRAG menu bar HUD
        |
        v
~/Documents/Corpus/
        |
        v
MyRAG in Codex / Claude Code
        |
        v
Matter-by-matter summary table
        |
        v
User chooses: worklog, project note, external research, or raw cleanup
```

## Step 1. Collect

Use the floating HUD:

- `Record` for continuous screen evidence.
- `Shot` for one capture.
- `Mic` for a local voice note.
- Clipboard text and images are saved automatically when the clipboard changes.

FreeRAG writes raw entries under:

```text
~/Documents/Corpus/screen/
~/Documents/Corpus/clipboard/
~/Documents/Corpus/voice/
```

## Step 2. Inspect

Open the corpus browser from the HUD folder button.

You can:

- search title, summary, and `llm_context.md`;
- open an entry;
- reveal it in Finder;
- move raw entries that MyRAG has already marked as processed into `_trash/`.

## Step 3. Mine With MyRAG

In Codex / Claude Code, ask MyRAG to inspect recent material.

Use `SKILL.md` for the normal mining workflow. If the current model cannot read images or transcribe audio, configure that first with `shared/skills/myrag/INSTALL_ADAPTERS.md`; otherwise MyRAG should clearly limit itself to text and existing transcripts.

Example:

```text
Use MyRAG to inspect my recent FreeRAG corpus. First group the material into candidate matters. Do not mark anything processed yet.
```

Useful local checks:

```bash
python3 shared/skills/myrag/scripts/myrag_search.py --recent 10 --format text
python3 shared/skills/myrag/scripts/myrag_search.py --suggest-projects 40 --format text
python3 shared/skills/myrag/scripts/myrag_search.py --image-clusters 20
```

## Step 4. Expected MyRAG Output

MyRAG should return a table like this in the chat:

| Matter | What happened | Evidence | Risk / uncertainty | Next step |
| --- | --- | --- | --- | --- |
| Permission onboarding | FreeRAG permission state was captured across app and System Settings. | screen entry, clipboard representative images | Need user confirmation after relaunch. | Keep as release troubleshooting evidence. |
| Corpus browser flow | Browser search/open/reveal/cleanup flow appears in screenshots. | clipboard clusters, screen storyboard | Need a cleaner demo image. | Turn into README demo material. |

The exact columns may change, but the output should stay matter-first, not file-first.

## Step 5. Confirm

Only after the user confirms that a raw entry has been taken over should MyRAG write:

```text
screen|clipboard|voice/<entry_id>/_myrag_done.json
```

FreeRAG's cleanup action only moves raw directories with that marker into `_trash/`. It does not delete `processed/`.

## What This Demo Proves

- FreeRAG is not trying to be a full AI app.
- The macOS app collects raw evidence cheaply.
- MyRAG does the reading and synthesis inside an LLM tool the user already controls, with model-specific Vision / ASR setup kept in the adapter guide.
- The user stays in charge of when raw material becomes processed knowledge.
