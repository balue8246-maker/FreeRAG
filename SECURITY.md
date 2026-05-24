# Security

## Supported Versions

FreeRAG is currently a beta local tool. Security fixes should target the latest commit on `main` unless a release branch is explicitly created.

## Reporting

If this repository is public and you find a security issue, please open a GitHub Security Advisory if available. If advisories are not enabled, open an issue with a minimal description and avoid posting private user data, tokens, or exploit details.

## Security Model

FreeRAG is local-first:

- it collects local screenshots, clipboard material, and voice recordings;
- it stores raw material under `~/Documents/Corpus/`;
- it does not automatically upload raw material;
- it relies on macOS permissions for Screen Recording, Accessibility, and Microphone access.

MyRAG is a separate LLM-side workflow. When the user asks an LLM tool to read the corpus, that tool's own security and privacy behavior applies.

## Release Safety Checklist

Before publishing a release:

- verify that no corpus material is committed;
- verify that no secrets are committed;
- verify that `dist/` binaries are attached to GitHub Releases, not committed to source;
- include a DMG SHA-256 checksum;
- state clearly whether the build is notarized.
