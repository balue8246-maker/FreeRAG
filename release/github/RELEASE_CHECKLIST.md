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
- [ ] `plutil -lint FreeRAG/Packaging/FreeRAG.entitlements`
- [ ] `codesign --verify --deep --strict --verbose=1 dist/FreeRAG.app`
- [ ] `codesign -d --entitlements - dist/FreeRAG.app` includes `com.apple.security.device.audio-input`.
- [ ] Mount the final DMG and verify the contained `FreeRAG.app` signature and microphone entitlement.
- [ ] `codesign --verify --verbose=2 dist/FreeRAG-0.5.1-build-4.dmg`
- [ ] `xcrun stapler validate dist/FreeRAG-0.5.1-build-4.dmg`
- [ ] `spctl -a -vvv -t install dist/FreeRAG-0.5.1-build-4.dmg`
- [ ] `hdiutil imageinfo dist/FreeRAG-0.5.1-build-4.dmg`

## Release Assets

- [ ] For local beta/self-signed build: `FreeRAG/Packaging/build_dmg.sh`.
- [ ] For Developer ID release build: `FreeRAG/Packaging/build_release_dmg.sh`.
- [ ] Generate checksum:

```bash
shasum -a 256 dist/FreeRAG-0.5.1-build-4.dmg > dist/FreeRAG-0.5.1-build-4.dmg.sha256
```

- [ ] Attach both files to GitHub Release.

## Release Text

- [ ] Mention local-first privacy model.
- [ ] Mention whether the attached DMG is self-signed beta or Developer ID signed and notarized.
- [ ] Mention permissions: Screen Recording, Accessibility, Microphone.
- [ ] Mention MyRAG runtime skill is optional and LLM-side.
- [ ] Mention `INSTALL_ADAPTERS.md` is for model-specific Vision / ASR setup, not part of the app runtime.
- [ ] Link `PRIVACY.md`, `SECURITY.md`, and product overview.
