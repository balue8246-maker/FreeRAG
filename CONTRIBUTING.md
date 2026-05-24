# Contributing

FreeRAG is early-stage and intentionally small. Contributions are welcome, but please keep the product boundary clear:

- FreeRAG collects local raw material.
- MyRAG reads local material and summarizes it in the LLM chat.
- Raw material should be marked done only after the user confirms the summary.

## Development

```bash
FreeRAG/Packaging/build_native_app.sh
PYTHONPYCACHEPREFIX=/private/tmp/freerag_pycache python3 -m py_compile shared/skills/myrag/scripts/myrag_search.py
```

## Pull Request Expectations

- Keep user privacy and local-first behavior intact.
- Do not add automatic uploads, cloud OCR, cloud transcription, or telemetry without explicit product discussion.
- Do not commit personal corpus data, screenshots, recordings, API keys, or local machine paths.
- Update `README.md`, `README.zh-CN.md`, and release notes when behavior changes.

## Style

- Swift/AppKit code should follow the existing single-app structure unless a split is clearly useful.
- MyRAG output should stay table-first, one matter per row.
- Build artifacts belong in `dist/` locally and GitHub Releases publicly, not in source commits.
