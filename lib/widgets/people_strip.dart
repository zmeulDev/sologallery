import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/daos/faces_dao.dart' show PersonSummary;
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../features/people/people_providers.dart';
import '../features/people/widgets/face_avatar.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'section_header.dart';

/// A "People" section header plus a horizontally scrolling row of circular
/// person tiles inside a rounded card, linking into the People screens. Shared
/// by the Search idle view and the Albums tab so both read as the same browse
/// affordance.
///
/// The section header sits outside the card so it aligns with other screen
/// sections; the row of faces sits in an [AppCard] with the navbar-matched
/// `br30` radius, giving the faces air on all four sides instead of running to
/// the screen edge.
///
/// Names come from [PersonSummary.displayName], which is **nullable** —
/// clustering names nobody on its own. A named person carries their name on a
/// caption line under the circle; an unnamed one is just the face, with no
/// caption, no "Unknown" and no index. Most clusters are unnamed, so the bare
/// circle is the common case and has to look deliberate rather than unfinished.
/// The photo count is not shown here — it lives on `/people`, where a second
/// line has room; two stacked lines under a circle is what makes this row's
/// height fragile (below).
class PeopleStrip extends ConsumerWidget {
  const PeopleStrip({super.key, required this.people});

  final List<PersonSummary> people;

  /// Diameter of each face circle — the People grid's size.
  static const double _avatarSize = 64;

  /// Gap between the circle and its caption.
  static const double _captionGap = AppSpace.s8;

  /// Line-height multiplier for the reserved caption band. Deliberately roomier
  /// than the text's own metrics: an earlier caption version reserved
  /// `fontSize * 1.4` and overflowed by a fraction of a pixel on a device whose
  /// font ran fractionally taller.
  static const double _captionLineHeight = 1.45;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final captionSize = styles.caption.fontSize ?? 11;
    // Resolved once for the whole row, instead of each tile's avatar hitting
    // the DB on its own as it scrolls into view (B2).
    final covers =
        ref.watch(personCoversProvider).value ?? const <int, CoverFace>{};

    // A horizontal ListView constrains its children's height *tightly*, so this
    // height is the tile's height, not a maximum — a caption that doesn't fit
    // squashes the circle into an oval rather than overflowing, silently. So the
    // band is measured, and reserved only when someone actually has a name, so
    // the common all-unnamed row carries no dead space under it.
    final anyNamed = people.any((p) => p.displayName != null);
    final band = anyNamed
        ? _captionGap +
              MediaQuery.textScalerOf(context).scale(captionSize) *
                  _captionLineHeight
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'People',
            trailing: AppButton.quiet(
              label: 'See all',
              onPressed: () => context.push('/people'),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          AppCard(
            borderRadius: AppRadius.br30,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: SizedBox(
                height: _avatarSize + band,
                child: RepaintBoundary(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: people.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpace.s20),
                    itemBuilder: (context, i) => _PersonTile(
                      person: people[i],
                      cover: covers[people[i].id],
                      size: _avatarSize,
                      captionBand: band,
                      captionGap: _captionGap,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    this.cover,
    required this.size,
    required this.captionBand,
    required this.captionGap,
  });

  final PersonSummary person;

  /// This person's cover face, resolved up front by [personCoversProvider] —
  /// see [FaceAvatar.cover].
  final CoverFace? cover;
  final double size;

  /// Height reserved under the circle for the caption line, gap included. Zero
  /// when no one in the row is named.
  final double captionBand;
  final double captionGap;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final name = person.displayName;
    void open() => context.push('/person/${person.id}');

    // Without a label of its own the tile contributes no semantics node at all,
    // and the section collapses into the header's — a screen reader lands on
    // one "People, See all" target covering the whole strip and can neither
    // name nor reach an individual face. The action is repeated here because
    // excludeSemantics drops the GestureDetector's node along with the caption's;
    // without it the tile announces as a button that cannot be activated.
    return Semantics(
      container: true,
      button: true,
      label: name ?? 'Unnamed person',
      onTap: open,
      // The caption repeats the name the label already carries, and the avatar
      // has nothing to say — the tile is one target, so it gets one node.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open,
        child: SizedBox(
          width: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              FaceAvatar(personId: person.id, size: size, cover: cover),
              // The band is fixed for the whole row, so a named and an unnamed
              // tile stay the same height and the circles line up.
              if (captionBand > 0)
                SizedBox(
                  height: captionBand,
                  child: name == null
                      ? null
                      : Padding(
                          padding: EdgeInsets.only(top: captionGap),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: styles.caption.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
