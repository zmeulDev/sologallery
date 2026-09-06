# Gesture & navigation consistency fix

## Problem

User report: "full gesture and proper support for zoom, pinch, navigation
... now its not consistent", concretely: swiping back on the Saved screen
exits the app instead of returning to the main (Library) tab.

Investigated live on the connected Samsung SM-S938B (adb + Dart Tooling
Daemon / `dart-mcp` widget inspector + flutter driver, temporarily enabling
`enableFlutterDriverExtension()` in `main.dart` for the session only —
reverted before any real change landed). Two independent, unrelated root
causes found and confirmed:

### 1. Back-navigation exits the app from non-default tabs

`lib/widgets/app_shell.dart` hosts the 4 tabs (Library, Search, Saved,
Albums) via `StatefulNavigationShell`, each with its own nested `Navigator`,
and never intercepts the system back button (no `PopScope`/`WillPopScope`
anywhere in the app).

Reproduced with `adb shell input keyevent 4` + `dumpsys activity
activities`: back while on **Saved** or **Search** exits straight to the
Samsung launcher instead of returning to Library. **Albums** shares the
identical code path (same `StatefulShellBranch` pattern, no
special-casing), so it has the same bug even though it wasn't separately
driven on-device.

Screens pushed on top of the shell (`parentNavigatorKey:
_rootNavigatorKey` — Settings, Person/Album/Folder/Photo detail, month/
year/day grids) popped back correctly in testing — confirmed with
`Settings`. None of the branches push anything onto their *own* nested
navigator (every cross-feature navigation targets the root navigator), so
there's no deeper stack depth to account for.

**Fix:** wrap `AppShell`'s `Scaffold` in `PopScope`:
`canPop: navigationShell.currentIndex == 0`; on an intercepted pop
(`didPop == false`), call `navigationShell.goBranch(0)`. Library
(index 0) keeps normal back-exits-app behavior since that's the actual
home. One file.

### 2. Pinch-to-zoom gets hijacked into a page-swipe

`PhotoDetailScreen`'s `PageView.builder`
(`lib/features/detail/detail_screen.dart`) is an ancestor `Scrollable`
with its own horizontal-drag recognizer, sitting above each page's
`InteractiveViewer` (`lib/features/detail/widgets/photo_page.dart:46`,
`scaleEnabled` never gated). Two fingers rarely land in the same frame;
the brief single-finger touch-down before the second finger lands is
enough for the PageView's drag recognizer to claim the gesture arena
first, hijacking the pinch attempt into a page-swipe (or, if the arena
resolves mid-gesture, the zoom just stops responding). This is a distinct
conflict from the already-handled vertical-dismiss-vs-zoom one described
in `DismissiblePhoto`'s doc comment ("sibling `VerticalDragGestureRecognizer`"
gotcha — that one's fixed).

**Fix:** track live pointer count in `PhotoDetailScreen` with a raw
`Listener` around the `PageView` (same non-arena-competing pattern
`DismissiblePhoto` already uses), and set the `PageView`'s `physics` to
`NeverScrollableScrollPhysics()` whenever 2+ fingers are down, reverting
to normal once back to ≤1. Removes the PageView as an arena competitor
the instant a second finger touches, so `InteractiveViewer`'s scale
recognizer wins pinch attempts cleanly; single-finger swipe-between-photos
is untouched. One file; `DismissiblePhoto`/`PhotoPage` untouched.

## Both designs approved by user (2026-09-06).

## Steps

- [x] Implement fix 1: `PopScope` in `lib/widgets/app_shell.dart`.
- [x] Verify fix 1 on-device (see resolution below) — Saved/Search/Albums
      back now returns to Library; Library itself still exits as normal.
- [x] Implement fix 2: pointer-count-gated `physics` in
      `lib/features/detail/detail_screen.dart`.
- [x] Fix 2 cannot be verified by automation (adb has no multi-touch pinch
      simulation) — user physically tested pinch-zoom on-device (2026-09-06):
      confirmed it "feels much better," no longer swipes to next/prev photo.
- [x] Run `tool/check.sh` — analyze, codegen, and all 884 tests pass.
- [x] Clean up: stopped the background `flutter run` session; confirmed
      `git status` only shows the three intended files changed.

## Blocker found and resolved verifying fix 1 (2026-09-06)

`PopScope` alone didn't fix the back-exit bug on this device at first.
Logcat (`adb shell input keyevent 4` + `flutter_run2.log`) showed, on
every fresh launch, before any navigation happened:

```
D/WindowOnBackDispatcher: setTopOnBackInvokedCallback (unwrapped): io.flutter.embedding.android.FlutterActivity$1@...
D/WindowOnBackDispatcher: setTopOnBackInvokedCallback (unwrapped): android.app.Activity$$ExternalSyntheticLambda0@...
```

Android's own default back callback (`Activity$$ExternalSyntheticLambda0`,
which just finishes the activity) re-registered itself as "top"
immediately after Flutter's `FlutterActivity$1` callback registered,
permanently shadowing it — deterministic across independent fresh
launches on this Samsung SM-S938B (One UI). Every back press invoked
`Activity$$ExternalSyntheticLambda0.onBackInvoked`, never Flutter's
callback, so `PopScope`/`Navigator` never saw the back event at all —
nothing to do with `canPop` logic.

User asked to research before deciding on a native-code fix. Found
[flutter/flutter#156967](https://github.com/flutter/flutter/issues/156967)
and a community writeup describing the same predictive-back-callback
takes precedence over `PopScope`/`WillPopScope` symptom, with the fix
being to explicitly set `android:enableOnBackInvokedCallback="false"` —
forcing Flutter back onto its legacy dispatch path, which routes through
`Navigator`/`PopScope` correctly and doesn't compete with Android's own
default callback for "top" at all. Tried it: **confirmed fixed** —
rebuilt, reconnected via DTD, drove Saved/Search/Albums + Library through
`adb shell input keyevent 4` + `dumpsys activity activities`, all four
came back correct. Kept the manifest flag as an explicit `false` (not
omitted) with a comment explaining why, so a future Flutter/AGP upgrade
doesn't accidentally "fix" it back to `true` without re-testing. The only
cost is losing the animated predictive-back gesture preview; the app
never used FlutterFragmentActivity or drew on that anyway.

No native `MainActivity.kt` changes were needed.

## Done (2026-09-06)

Both fixes implemented, verified on-device (back-navigation via adb/logcat,
pinch-zoom by the user physically testing), and `tool/check.sh` passes.
Also recorded both root causes in `docs/gotchas.md` (Android manifest /
`Flutter widget / layout / gesture` sections) so they don't get
rediscovered the hard way. Nothing pending; not yet committed.
