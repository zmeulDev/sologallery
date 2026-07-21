# Search — top 10 on-device labels by frequency

## Goal

The Search idle screen's "On-device labels" section currently renders the whole
curated allowlist (`MemoryBuilder.presentableLabels`, 33 chips, alphabetical),
regardless of whether the library actually contains any of them — so most chips
lead to "No matches.". Show **only the 10 most frequent** labels in *this*
library instead.

## Decisions (locked with the user)

- **Candidate set:** the curated allowlist only. ML Kit's raw label set is too
  coarse ("Person", "Room", "Event") to browse; ranking happens *within* the
  allowlist.
- **Order:** count descending, ties broken alphabetically.
- **Empty state:** hide the section entirely when no allowlisted label has
  photos yet (fresh install / indexer still running). The idle hint then stands
  alone, as it does with content search off.
- **No count badge** on the chip — `FilterPill` is unchanged, no golden churn.

## Steps

- [x] `IndexDao.watchTopLabels({required Set<String> allow, int limit = 10})` →
      `Stream<List<({String label, int count})>>`. `selectOnly(photoLabels)`,
      `assetId.count(distinct: true)`, `isIn(allow)`, `groupBy(label)`,
      order count desc + label asc, `limit`. Reactive so chips appear as the
      background indexer progresses.
      **Aggregate must be in `addColumns`** (CLAUDE.md gotcha).
- [x] `topBrowseLabelsProvider` (`StreamProvider.autoDispose<List<String>>`) in
      `search_providers.dart` — feeds the allowlist + limit 10 to the DAO and
      projects to label strings. The allowlist stays owned by `MemoryBuilder`
      so "browsable" and "presentable as a memory" remain one list; the DAO
      takes it as a parameter rather than importing a feature domain.
- [x] `search_screen.dart`: drop the module-level `_browseLabels` list;
      `_IdleView` watches the provider and passes the list down;
      `_BrowseLabels` renders nothing when the list is empty. Idle-hint
      condition becomes `people.isEmpty && labels.isEmpty` (was
      `people.isEmpty && !searchOn`), so an indexing-but-empty library still
      gets a prompt.
- [x] Tests (written, **not run** — user asked to hold off):
      - `test/core/database/index_dao_test.dart`: ranking, allowlist filter,
        distinct-asset counting, limit, tie-break, reactivity.
      - `test/features/search/search_providers_test.dart`: provider wiring
        against an in-memory DB (allowlist applied, capped at 10, order kept).
      - `test/features/search/search_screen_test.dart`: chips come from the
        provider (override), section hidden when empty, tap still commits the
        query.

## Next step

Run `tool/check.sh` (deferred at the user's request), then on-device
verification: open Search with content search on and confirm the 10 chips
reflect the real library and each returns results.
