# FreeRAG v0.5.1 Beta 1

This is a focused bugfix release for the macOS HUD bar and local beta signing behavior.

## Fixes

- Fixed the HUD bar not returning above full-screen apps after clicking the HUD hide button and then choosing "Show HUD" from the macOS menu bar.
- The HUD now reapplies full-screen/Space floating behavior whenever it is shown.
- The hide button no longer removes the HUD panel from the window stack; it makes the HUD transparent and non-interactive so showing it again preserves the floating behavior more reliably.

## Signing

- The beta package now uses a stable local self-signed code signing identity instead of ad-hoc signing.
- This is intended to make local macOS permissions more stable across FreeRAG rebuilds on the same signing identity.
- This is not Apple Developer ID signing and the app is still not notarized, so macOS Gatekeeper may still warn on first launch.

## Assets

- `FreeRAG-0.5.1-build-3.dmg`
- `FreeRAG-0.5.1-build-3.dmg.sha256`
