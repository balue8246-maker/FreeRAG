# GitHub Release Checklist

## Source Audit

- [ ] `git status --short` is clean before tagging.
- [ ] `git ls-files | rg '(^|/)dist/|CURRENT_STATE|\\.DS_Store|\\.env|\\.pem|\\.key|\\.p12'` returns nothing.
- [ ] Search for local absolute home paths and common secret names; confirm any hits are only documentation examples, not real credentials.
- [ ] `dist/` is ignored and not tracked.

## Build Verification

- [ ] `PYTHONPYCACHEPREFIX=/private/tmp/freerag_pycache python3 -m py_compile shared/skills/myrag/scripts/myrag_search.py`
- [ ] `python3 -m html.parser docs/product_overview.html`
- [ ] `python3 -m html.parser docs/product_overview.en.html`
- [ ] `python3 -m html.parser docs/product_overview.zh-CN.html`
- [ ] `plutil -lint FreeRAG/Info.plist dist/FreeRAG.app/Contents/Info.plist`
- [ ] `codesign --verify --deep --strict --verbose=1 dist/FreeRAG.app`
- [ ] `hdiutil imageinfo dist/FreeRAG-0.5.0-build-2.dmg`

## Release Assets

- [ ] Build `dist/FreeRAG-0.5.0-build-2.dmg`.
- [ ] Generate checksum:

```bash
shasum -a 256 dist/FreeRAG-0.5.0-build-2.dmg > dist/FreeRAG-0.5.0-build-2.dmg.sha256
```

- [ ] Attach both files to GitHub Release.

## Release Text

- [ ] Mention local-first privacy model.
- [ ] Mention ad-hoc signed / not notarized.
- [ ] Mention permissions: Screen Recording, Accessibility, Microphone.
- [ ] Mention MyRAG skill is optional and LLM-side.
- [ ] Link `PRIVACY.md`, `SECURITY.md`, and product overview.
