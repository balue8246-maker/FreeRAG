# Privacy

FreeRAG is designed as a local-first raw context collector.

## What FreeRAG Stores

By default, FreeRAG writes local material under:

```text
~/Documents/Corpus/
```

This may include:

- screen captures and storyboard images;
- clipboard text and clipboard images;
- local voice recordings;
- local index files such as `_index.json` and `_library.json`;
- optional MyRAG processing output under `processed/`.

## What FreeRAG Does Not Do By Itself

FreeRAG does not automatically upload screenshots, clipboard content, recordings, transcripts, or corpus indexes.

FreeRAG does not automatically run cloud OCR, cloud transcription, or cloud analysis. The app collects raw material; the user decides when to use MyRAG in Codex / Claude Code to read and summarize it.

## MyRAG And LLM Tools

MyRAG is an LLM-side skill. When you use MyRAG in Codex / Claude Code, the LLM tool may read files from your local corpus because you explicitly asked it to. Whether any content leaves your machine depends on the LLM tool and provider you run.

Do not run MyRAG on private material unless you understand the privacy behavior of your LLM environment.

## Publishing Safety

Never commit or publish:

- `~/Documents/Corpus/`;
- screenshots, recordings, transcripts, or extracted tables from real work;
- API keys, tokens, `.env` files, passwords, or certificates;
- customer, employee, team, business, financial, medical, legal, or personal data.

The repository `.gitignore` is configured to avoid common local outputs and secrets, but users are still responsible for reviewing files before publishing.
