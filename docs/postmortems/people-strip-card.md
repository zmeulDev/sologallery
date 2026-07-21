# People strip — carded, circular, airier

**Status:** implemented; host tests + golden green. Awaiting on-device check.
**Next step:** step 6 — verify circles crop on the face on the Pixel (Search idle
and Albums, default + large text).

## Brief (user)

> in people strip, that needs a background, same background as in "Search runs
> entirely on…" and face thumbnails should be rounded, also allow some padding
> on that strip for an airy feeling.

Clarified: "rounded" = **circular avatars**, matching the People screen — names
move to a caption line under each circle.

## Target shape

```
 ┌ AppCard (surface + r12 + hairline) ─────────────────────┐
 │  PEOPLE                                        See all  │
 │                                                         │
 │    ⬤       ⬤       ⬤       ⬤       ⬤       ⬤          │
 │   Ada     Mihai                                         │
 └─────────────────────────────────────────────────────────┘
```

Consumers are unchanged: `search_screen.dart:401` (idle view) and
`albums_screen.dart:177`. The card makes the strip read as the same grouping
container as the privacy note directly below it on Search.

## Decisions

1. **Background = `AppCard`** — the app's one grouping container (surface,
   `AppRadius.br12`, hairline border), exactly what `_PrivacyNote` uses. Card
   sits in `EdgeInsets.fromLTRB(s16, s12, s16, s4)`, unchanged from today's
   outer padding, so neither host screen's rhythm shifts.
2. **Circular avatars, 64pt** — `FaceAvatar` with `borderRadius: null` (its
   default `ClipOval` path). 64 is the People-grid size; 88 as a circle reads
   heavy inside a card. No change to `face_avatar.dart`.
3. **Caption = name only, no photo count.** One line, `styles.caption`,
   centered, `maxLines: 1` + ellipsis, clamped to the avatar's 64pt column.
   The count belongs on `/people`, where there is room for it; two stacked
   lines under a circle is exactly the height-fragility this widget was
   rewritten to escape.
4. **Unnamed people get no caption** — no "Unknown", no id, no index. Most
   clusters are unnamed, so the bare circle stays the common case.
5. **Airiness** — inner card padding `s16` all round; `s16` between tiles (up
   from `s8`); `s8` between header and row; the horizontal `ListView` gets an
   explicit `padding: EdgeInsets.zero` (never null — see the BoxScrollView
   gotcha) and the card's own padding does the insetting.

## The height trap (must not regress)

A horizontal `ListView` constrains children's height **tightly**, so the
`SizedBox(height:)` *is* the tile height, not a maximum — adding a caption
squashes the circle into an oval instead of overflowing, silently. So the
strip computes its height:

```dart
final scaler = MediaQuery.textScalerOf(context);
final band = anyNamed ? gap + scaler.scale(captionFontSize) * lineHeight : 0;
final height = avatar + band;
```

- The caption band is added **only when at least one person has a name**, so
  the common all-unnamed row has no dead space under it.
- `lineHeight` is taken with headroom (1.45) — the previous caption version
  overflowed by 0.29px at 1.4 on a device whose font ran fractionally taller.
- The tile column is `Column(mainAxisSize: min)` with the caption in a
  `SizedBox(height: band)` so the text can never push the circle.

**Consequence to accept:** row height now legitimately varies with text scale
and with whether any person is named. The old invariant "height is independent
of names and text scale" (people_strip_test.dart:100–114) is retired by this
design; the invariant that stays is **"no overflow and the avatar stays
circular at any text scale"**.

## Steps

- [x] 1. `lib/widgets/people_strip.dart`: wrap in `AppCard`; `_PersonTile` →
      circle + caption column; height computation as above; tile gap `s16`;
      explicit `ListView` padding.
- [x] 2. `test/widgets/people_strip_test.dart`: keep the "avatar per person",
      "name shown", "no Unknown/index for unnamed", "long name ellipsized"
      cases. Replace the two retired cases with:
      - avatar stays **square-bounded** (width == height, i.e. not ovalled) at
        textScale 1.0 / 1.15 / 1.6 / 2.0, no exception;
      - all-unnamed row is **shorter** than a row with one named person
        (proves the band is conditional, not always reserved);
      - `find.byType(ClipOval)` present / `ClipRRect` absent for the avatar
        (proves circles);
      - the photo count is **not** in the strip.
- [x] 3. Check `test/features/search/search_screen_test.dart` and
      `test/features/albums/albums_screen_test.dart` for assertions on the
      strip's count text or tile size; update if any.
- [x] 4. Golden: add the carded strip (named + unnamed) to
      `test/widgets/design_goldens_test.dart`, light + dark. Goldens can't see
      icon glyphs but do pin layout/colour — the card border and circle crop
      are exactly what this needs.
- [x] 5. `flutter analyze` (clean, whole project) + the touched test files.
      Full `tool/check.sh` **not** run to green: this branch already carries
      unrelated failures (see Outcome), so it can't pass until the in-flight
      nav/goldens work lands.
- [ ] 6. On-device verification. Host tests feed `FaceAvatar` undecodable
      bytes, so avatar geometry only shows on a real device — confirm on the
      Pixel that circles crop on the face (not off-centre) on Search idle and
      on Albums, at default and large text.

## Outcome

- `people_strip.dart` rewritten: `AppCard` + s16 inner padding, 64pt circles
  (`FaceAvatar` with no `borderRadius`), name-only caption in a measured band,
  s16 tile gap, explicit `EdgeInsets.zero` on the `ListView`.
- `test/widgets/people_strip_test.dart`: 11 cases green, including the four
  text-scale cases now asserting the circle stays 64×64 rather than the row
  height staying constant.
- Golden `test/widgets/goldens/ci/people_strip.png` added (light + dark),
  generated with `--plain-name "PeopleStrip"` so the branch's other stale
  goldens were not silently rewritten.
- **Pre-existing failures on this branch, unrelated and untouched:** 12
  `design_goldens_test` cases, 3 in `albums_screen_test` (including "People
  shows when faces are on…", which fails identically with this change stashed),
  1 in `people_screen_test`. Verified by stashing.

## Follow-ups / notes

- CLAUDE.md's `PeopleStrip` gotcha (horizontal-ListView tight height, caption
  band computed and conditional) becomes accurate again for this widget after
  step 1 — it currently describes a shape the widget had abandoned. Update its
  wording, don't delete it.
