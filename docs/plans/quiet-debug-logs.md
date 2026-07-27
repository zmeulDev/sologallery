# Quiet debug-mode logs to errors and warnings

## Context

The debug logger currently emits every level (`FINE` / `INFO` / `WARNING` /
`SEVERE`) on iOS and Android, so a normal session logs tens of thousands of
lines per hour — `previewImage(...) bytes=...` at ~50ms cadence during a
fling, `[SoloGallery.photos] Listed 14 device folder(s)` on every state
change, `[SoloGallery.ml] Indexing pass complete` per pass, etc. Real
errors get drowned in noise, and grep for `error` in logcat is dominated by
unrelated matches. The release path already filters at `Level.WARNING`; the
debug path should match.

## Decision

Filter the debug logger at `Level.WARNING` instead of `Level.ALL`. Errors
and warnings still come through to logcat; `INFO`/`FINE`/`FINEST` are dropped
at the source. The documented `adb logcat -s flutter:V SoloGallery:V`
workflow keeps working identically — same records reach it for the levels
that matter.

Why this matches the project's rules:

- **Speed and UX come first** (CLAUDE.md Absolute rules). Hot-path
  `FINE`/`INFO` logs are real work (string formatting, `developer.log`
  calls, `debugPrint` allocations) that has no upside in normal operation.
  Bumping the level removes that overhead in every debug build, on every
  device.
- **`adb logcat -s flutter:V SoloGallery:V` is the canonical debug
  workflow** (`docs/gotchas.md` "developer.log alone reaches nothing but
  DevTools"). Reducing verbosity makes that filter actually useful for
  surface-level triage; deeper investigation can lower the level on a
  per-session basis (see below).

## Edits

One-line change in `lib/core/logging_config.dart:27`:

```diff
-  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
+  Logger.root.level = Level.WARNING;
```

Both branches collapse to the same value. The `kReleaseMode` switch is
removed; the line becomes a single, deliberate statement of intent.

No changes to:
- The `developer.log` mirror (still useful in DevTools; this change only
  affects what reaches the mirror).
- The `debugPrint` mirror (still emits WARNING+ in debug).
- Feature log call sites — they remain correct at their existing levels;
  nothing needs to be re-graded.
- The `kReleaseMode` import in `logging_config.dart` if it's used
  elsewhere in the file (check before deleting the import — but the only
  use is on line 27, so `kReleaseMode` is no longer referenced).

## Per-session deeper inspection

When a bug needs the full level of detail back, a one-shot `Logger.root.level
= Level.ALL` from a debug breakpoint in DevTools (or a temporary
`Logger('SoloGallery.<area>').level = Level.ALL` override in code) restores
everything. The default is quiet; the escape hatch is one line. Logged in
this plan so a future investigator doesn't have to rediscover the override.

## Verification

1. `tool/check.sh` passes — analyze + build_runner + 777 tests. No test
   asserts on log output levels today, but the test suite still runs and
   confirms the import graph compiles.
2. On-device, hot reload and run for 60s while scrolling Library:
   - Before this change: hundreds of `previewImage(...) bytes=...` /
     `adjacentThumbnail(...) bytes=...` lines in logcat.
   - After this change: zero `FINE`/`INFO` lines; only warnings and
     errors.
3. Trigger an error deliberately (e.g. revoke photo permission mid-session
   while a thumbnail request is in flight — that surfaces as a
   `[SoloGallery.photos]` error/warning), and confirm it still appears in
   `adb logcat -s flutter:V SoloGallery:V`.

## Out of scope

- Per-logger thresholds (`SoloGallery.ml.level = Level.INFO` while the rest
  stays WARNING). Worth considering later if ML indexing produces noise
  that's useful to keep but everything else wants silencing, but it's a
  finer-grained decision than the current "everything is loud" vs. "only
  errors" split the user asked for.
- Removing the `FINE`/`INFO` log statements from feature code. They stay —
  cheap when the level filter rejects them, and a clear record of what
  *would* have logged for the deeper-inspection path above.
