# Documentation overhaul — 2026-09-04

**Status:** complete.
**Next step:** none. Follow-up work is tracked in
[2026-09-04-remediation.md](2026-09-04-remediation.md).

## Goal

Audit the codebase and produce a canonical documentation set: `PRD.md`,
`ARCHITECTURE.md`, `AGENTS.md`, a refreshed `CLAUDE.md`, plus a drift report,
a tech-debt report, a rewritten `README.md`, and a remediation plan an agent can
execute.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| `ARCHITECTURE.md` vs `docs/spec.md` | Promote and expand; **delete spec.md** | The two would have held the same facts. Duplication is exactly what let spec.md drift to "Schema v8" while the code moved to v10. |
| Design system location | Split to `docs/design-system.md` | Tokens plus prose in one place; ARCHITECTURE.md stays about structure. |
| PRD audience | Internal source of truth | For the maintainer and coding agents, not a pitch. Documents what exists, its guarantees, and the known gaps. |
| Agent instructions | **AGENTS.md canonical**, CLAUDE.md a pointer | AGENTS.md is the vendor-neutral convention other tools read. One source of truth; CLAUDE.md keeps only Claude Code specifics (plan-then-wait, delegation, model routing, session hygiene). |
| Signing-material finding | Documented only, no remediation task | Owner's call; recorded in `PRD.md#known-gaps` and `AGENTS.md#environment`, and explicitly scoped out of the remediation plan. |
| Refactor depth in the plan | Full — services **and** screens | All eight 400+ line files are planned, with coverage phases sequenced before the risky service splits. |

## Audit method

Four parallel read-only agents: data/service layer · features/UI · doc-vs-code
drift · tests and tech debt. Findings were cross-checked against the code before
being written into the docs; the committed-keystore finding was verified directly
in the main session.

## What the audit found

**The codebase is in good shape.** 124 Dart files, ~18k LOC. All 7 DAOs
unit-tested, migration tests cover every upgrade path v1→v10, ~54 widget tests,
32 goldens, 17 on-device Patrol tests. Zero TODO/FIXME, zero stray `print`, no
layering violations — domain is genuinely Flutter-free and `photo_manager` is
genuinely confined to one service. The fake-pairing rule is honoured, with each
integration test naming the fake it counterparts. Every design token, every named
component, the app-id consistency and the manifest permission strips verified
correct.

**Ten drift findings**, four material:

1. `docs/spec.md` said "Schema v8 (current)"; the code is at **v10**. The
   `recently_viewed` table and the `photo_asset_dated_created` index were
   undocumented.
2. `CLAUDE.md` said release signing was "still the debug key" and the keystore
   files "don't exist". A real signing config exists and both files are
   **committed to git**.
3. `CLAUDE.md` said the detail viewer pre-warms "±3" neighbours; it is ±5
   full-resolution and ±7 thumbnails.
4. `CLAUDE.md` called the first nav destination "Home Gallery"; code and spec both
   say "Library".

Plus: three routes missing from the routing table (`/year/:year`, `/day/:date`,
`/settings/analysis`); the structure tree listed 7 of 11 services and 3 of 19
shared widgets and omitted `core/format/` and `core/logging_config.dart`; README
was untouched `flutter create` boilerplate.

**Tech debt:** eight files over 400 lines (top four: `indexing_service.dart`
1027, `photo_library_service.dart` 853, `ml_service.dart` 668, `index_dao.dart`
634); `EditInstructionsDao` registered but uncalled; `AppRadius.r8` defined with
no call sites; two structurally identical LRU caches; `IndexDao` repeating five
query shapes across four grouping axes; a spacing token used as a radius; a bare
`Colors.white60` over media; committed golden-failure PNGs; and three generated
test fixtures — including the mandated HEIC OOM asset — referenced by no test,
with `ml_indexing_test.dart` reading arbitrary device photos instead.

## Changes made

**Created:** `PRD.md` · `ARCHITECTURE.md` · `AGENTS.md` ·
`docs/design-system.md` · `docs/plans/2026-09-04-remediation.md` · this file.

**Rewritten:** `CLAUDE.md` (16KB → a pointer plus Claude Code specifics) ·
`README.md` (flutter-create stub → real project README).

**Deleted:** `docs/spec.md`, fully absorbed.

**Repointed references** — no logic touched, doc comments only:
- 13 files in `lib/`: `docs/spec.md#architecture|#data-model|#routing` →
  `ARCHITECTURE.md#layers|#data-model|#routing`.
- ~30 files across `lib/`, `test/`, `integration_test/` and `docs/gotchas.md`:
  `CLAUDE.md` → `AGENTS.md`, except rule-specific citations, which now point at
  `docs/gotchas.md` or `docs/design-system.md` as appropriate.

**Unchanged:** `docs/gotchas.md` content (verified accurate; only its
cross-references were repointed).

## Verification

- `flutter analyze` — **clean**, no issues.
- `flutter test` — 777 pass, **1 fail**: `library_providers_test.dart`, "this week
  groups dated assets into day counts, newest first". **Pre-existing and unrelated
  to this work** — the only source changes here are comment text. The test seeds
  hardcoded dates (2026-08-27/28) against a rolling last-7-days window, so it
  began failing on 2026-09-03 when the older date aged out. Captured as task 1.7
  in the remediation plan, and listed in `PRD.md#known-gaps`.

## Follow-ups

- Execute [2026-09-04-remediation.md](2026-09-04-remediation.md), starting at
  task 1.1.
- The committed signing material is the owner's to resolve; it is recorded in
  `PRD.md#known-gaps` and deliberately excluded from the remediation backlog.
