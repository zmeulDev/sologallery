# People: merge two clusters into one person

Status: **Done and verified on device.** The reported bug is closed: the user
appears once.

On the reporting Pixel, merging `Zml` (47) and `ZmlG` (10) in the running app
produced one **Zml, 57 photos** entry — and it **survived a forced global
re-cluster** (algorithm stamp cleared to trigger one; the stamp came back as
`2`, the redirect `26 → 18` was still there, and Zml still resolved to 57 faces).
That is the failure this whole design exists to prevent, checked against the real
app rather than argued.

## Why

`docs/plans/people-clustering-oversplit.md` took the reporting device from 130
"people" to 48 and the reporting user from 6 entries to 2. The residual split is
`Zml` (47 photos) and `ZmlG` (10 photos, the same man wearing sunglasses), and it
is **not** fixable by tuning `clusterMergeThreshold`: at 0.40 those two do merge,
but three of the four extra merges 0.40 introduces are wrong (two different women
fused, etc.), verified by eye on the live embeddings. That reproduces the same
finding from Phase 1 on a different embedding set, so it is a property of this
pipeline: no global threshold reunites a person across an appearance change
without fusing distinct people.

Better embeddings (Phase 3, aligned crops) should reduce how often this happens.
They will not eliminate it. A photo app needs a way for the user to say "these two
are the same person" — so build that, and treat Phase 3 as the separate quality
work it is.

## The hard part: surviving the global re-cluster

`_maybeGlobalRecluster` re-derives every group from scratch and `planClusters`
reassigns all faces. A naive merge (move B's faces to A, delete B) is undone by
the very next re-cluster: `clusterAll` splits them again, the 47-group re-claims
`Zml`, and the 10-group — finding its faces' person already claimed — mints a
fresh person. The split silently returns.

Note also that **face row ids are not stable**: `insertFaces` deletes and
re-inserts an asset's faces, so re-indexing renumbers them. Any override keyed on
face id breaks on the next pipeline change.

### Chosen design: `persons.merged_into`, resolved at read time

Do not move faces and do not delete the absorbed person. Record a redirect:

```
persons.merged_into  INTEGER NULL REFERENCES persons(id) ON DELETE SET NULL
```

Merging B into A sets `B.merged_into = A`. Faces stay pointing at B.

This survives re-clustering *because* clustering is deterministic and
`planClusters` already reuses a group's dominant prior person: the 47-group
re-claims A, the 10-group re-claims B, and B still redirects to A. Nothing has to
be re-derived or matched.

Behaviour that falls out for free:
- If a later re-cluster (or Phase 3's better embeddings) groups them naturally,
  the losing row is reused by no group, `planClusters` drops it, and the redirect
  goes with it. Correct: they are already one person.
- Chains (C→B→A) resolve transitively, with a cycle guard.
- Deleting the survivor nulls the redirect (`ON DELETE SET NULL`) rather than
  orphaning — the absorbed person reappears on its own instead of vanishing.

Rejected alternatives: a `person_merges` table keyed on face ids (breaks on
re-index, see above); matching absorbed clusters by stored centroid after each
re-cluster (robust to id churn but can misfire silently, and it re-introduces a
threshold — the exact thing this feature exists to work around).

## Phase A — data layer ✅ done

1. ✅ Schema **v8**: `persons.merged_into`, nullable, self-referencing,
   `ON DELETE SET NULL`. Dump committed (`drift_schemas/drift_schema_v8.json`),
   migration helpers regenerated, every path re-validated *to current*.
   `persons` is created at v3 but changes shape at v8, so its migration needed
   the documented `else if (from < 8) addColumn` guard — a `from < 3` run already
   builds the current shape and must not then add the column again.
2. ✅ `FacesDao`: `mergePersons`, `unmergePerson`, `mergedPeopleOf`, and an
   `_effectivePersonId` (`COALESCE(merged_into, id)`) now used by
   `watchPersonSummaries` (joins an aliased `survivor` so the entry shows the
   survivor's name/cover, not an arbitrary row of the group) and
   `assetsForPerson`.

   **Chains are normalized at write time** rather than resolved recursively at
   read time: `mergePersons` resolves the target to its root and re-points
   anything already aimed at the absorbed row, so `merged_into` is never more
   than one hop deep and cannot cycle. That is what lets every read be a single
   `COALESCE` instead of a recursive CTE.
3. ✅ `PeopleActions.merge` / `.separate`, plus `mergedPeopleProvider`. The
   summaries stream updates itself; the per-person futures are invalidated
   explicitly.

Tests (9 new, all passing): fold + counts, photos of both clusters, unmerge,
`mergedPeopleOf`, one-hop chain normalization, refusing a merge that would cycle,
`setNull` on survivor delete, and — the one that matters — **a global re-cluster
running the real `clusterAll` + `planClusters` + `rebuildClusters` over a merged
pair, asserting it still reads as one person.** `tool/check.sh` failure set is
unchanged from the branch baseline.

## Phase B — UI

Follows the existing design system exactly (CLAUDE.md § Design system); this is a
feature inside an established identity, not a new visual direction.

**Selection mode on the People grid** — the mental model is "these two are the
same person", which is a comparison across the grid, so selection lives there
rather than in a per-person picker.

```
┌──────────────────────────────┐
│  ← People            Select  │   app bar action, quiet AppButton
├──────────────────────────────┤
│  (Zml)   (ZmlG)   ( )   ( )  │
│   47      10       12    10  │
│   [✓]     [✓]                │   check disc over avatar
├──────────────────────────────┤
│      Merge 2 people          │   primary AppButton, full width
└──────────────────────────────┘
```

- App bar gains **Select** (and **Cancel** while selecting). Title becomes
  "2 selected" in selection mode.
- `_PersonCard` gains a selected state: a `CircleIconButton.overMedia`-style
  check disc bottom-right of the avatar, plus a ring in `pillActiveBg`. Fades in
  over `AppMotion.short`.
- A bottom bar (surface + hairline top border, safe-area padded) holds one
  primary `AppButton` labelled **Merge 2 people**, disabled below two selections.
- Confirm dialog (r20, themed `TextButton`s): title **Merge people?**, body
  "Zml and ZmlG become one person, named Zml." Actions **Cancel** / **Merge**.
  The survivor is the most-photographed of the selection — stated, not chosen, so
  there is no extra picker to learn.
- On success: inverted-ink snackbar **Merged** with an **Undo** action.
- Permanent undo: Person detail gains **Separate people** when the person has
  absorbed others (only shown then).

Copy follows the writing rules: the action is "Merge" everywhere, and the
completed state says "Merged".

Tests: widget tests for entering/leaving selection mode, the disabled→enabled
button, the dialog naming the right survivor, and the undo path; a golden for the
selected `_PersonCard` (light + dark). Existing `people_screen_test` cases need
the dispose-tree teardown if they don't already have it (CLAUDE.md gotcha).

## Phase B — UI ✅ done

`PeopleScreen` became a `ConsumerStatefulWidget` holding `Set<int>? _selected`
(null = not selecting, so "selecting nothing" stays distinguishable). **Select**
appears in the app bar only once there are two people to choose between; the
title becomes "N selected"; `_MergeBar` holds the one primary action, inert below
two selections. `_PersonCard` gained an always-built selected overlay — ink ring
plus check disc, faded by `AnimatedOpacity` — never a conditional child, so the
tree shape stays stable across selection changes (CLAUDE.md gotcha about
structural rebuilds killing gestures). Confirm dialog, "Merged" snackbar with
**Undo**, and **Separate people** on the person screen, shown only when
`mergedPeopleOf` is non-empty.

12 People-screen tests + 3 person-screen tests. Two harness traps worth knowing:

- `peopleActionsProvider` is created **lazily**, so a test whose path never reads
  it (the cancel case) was still holding the *previous* test's recorder and read
  its merges. The fake is now `implements PeopleActions` (no `Ref` needed),
  built in `setUp` and injected with `overrideWithValue`, so every test owns one
  from the start.
- "Cancel" exists in both the app bar and the dialog; scope the finder with
  `find.descendant(of: find.byType(AlertDialog), ...)`.
- A `SnackBarAction` is not hittable until its entrance frame has run — pump
  ~750 ms before tapping **Undo**.

## Phase C — verification

- `tool/check.sh`.
- On-device: merge `Zml` + `ZmlG` in the running app, confirm People shows one
  entry with 57 photos, then force a global re-cluster and confirm it still reads
  as one. This is the real acceptance test for the reported bug.
- Update `docs/plans/people-clustering-oversplit.md` to point here.

## Out of scope

Splitting a cluster (the inverse), moving individual faces between people, and
Phase 3's aligned crop. The dog (5 photos) and plant (4 photos) entries stay
until Phase 3 — a merge action does not help them; hiding them is Phase 4.
