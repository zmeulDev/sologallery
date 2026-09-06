# Per-version release-notes doc

## Problem

Release "What's New" copy currently only lives inside one-off
`docs/plans/release-prep-*.md` files (see `release-prep-26.9.6.md`). There's
no durable, easy-to-find record of what was actually published to each store
for each version. Need a standing per-version doc.

## Decisions (confirmed with user)

- **Location/shape:** `docs/releases/`, one file per version **per platform**
  — `docs/releases/<version>-android.md` and `docs/releases/<version>-ios.md`
  (mirrors the existing `docs/plans/<task>.md` convention).
- **Content:** only the store "What's New" copy, ready to paste into Play
  Console / App Store Connect. No internal change list, no build metadata —
  those already live in the release-prep plan doc and git history.
- **Cross-platform mentions:** each file must never name the other platform
  (already required for App Store copy by Guideline 2.3.10 — this makes it
  the rule for both, symmetrically, so Play notes don't reference iOS either).
- Filename uses the **marketing version only** (`26.9.6`), not the build
  number — the build number isn't user-visible in store listings.

## Steps

- [x] Create `docs/releases/` directory.
- [x] Backfill `docs/releases/26.9.6-android.md` and
      `docs/releases/26.9.6-ios.md` from the copy already drafted in
      `docs/plans/release-prep-26.9.6.md`.
- [x] Add a one-line pointer to `docs/releases/` in `AGENTS.md`'s Workflow
      section, next to the plan-doc bullet.
- [x] Fix the stale "new day resets `+N` to 1" line in
      `docs/plans/release-prep-26.9.6.md`.

## Done (2026-09-06)

`docs/releases/` created with the two 26.9.6 files; AGENTS.md points to it;
the stale versioning line in `release-prep-26.9.6.md` is corrected. Nothing
pending — future releases should add their two files here as part of the
release-prep flow.
