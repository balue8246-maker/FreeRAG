# FreeRAG v0.5.1 Beta 1

This is a focused bugfix release for the macOS HUD bar and local beta signing behavior.

## Fixes

- Fixed the HUD bar not returning above full-screen apps after clicking the HUD hide button and then choosing "Show HUD" from the macOS menu bar.
- The HUD now reapplies full-screen/Space floating behavior whenever it is shown.
- The hide button no longer removes the HUD panel from the window stack; it makes the HUD transparent and non-interactive so showing it again preserves the floating behavior more reliably.
- Voice notes and screen collection can now run at the same time. While recording audio, users can still take a one-off screenshot or start continuous screen sampling; while sampling the screen, users can still start a voice note.
- Screen and voice entries captured during the same live session now share a `capture_group` value so MyRAG can connect them later.
- The corpus library now displays entry times in the Mac's current system time zone instead of showing raw UTC timestamps.

## Signing

- The beta package now uses a stable local self-signed code signing identity instead of ad-hoc signing.
- This is intended to make local macOS permissions more stable across FreeRAG rebuilds on the same signing identity.
- This is not Apple Developer ID signing and the app is still not notarized, so macOS Gatekeeper may still warn on first launch.

## Packaging and Docs

- The DMG now uses a guided Finder layout with background labels for the app, Applications shortcut, product overview, README, MyRAG skill, and assets.
- The DMG README now includes the short macOS beta install path and clearly states that the beta is not Apple Developer ID signed or notarized.
- MyRAG docs are split into the runtime `SKILL.md` and `INSTALL_ADAPTERS.md` for model-specific Vision / ASR setup.

## Assets

- `FreeRAG-0.5.1-build-3.dmg`
- `FreeRAG-0.5.1-build-3.dmg.sha256`
