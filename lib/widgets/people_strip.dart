import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/database/daos/faces_dao.dart' show PersonSummary;
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../features/people/widgets/face_avatar.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'section_header.dart';

/// A horizontal row of circular person tiles under a "People" header, linking
/// into the People screens. Shared by the Search idle view and the Albums tab so
/// both read as the same browse affordance.
///
/// The row sits in an [AppCard] — the app's one grouping container — so on
/// Search it reads as the same kind of box as the privacy note below it, and
/// the faces get air on all four sides instead of running to the screen edge.
///
/// Names come from [PersonSummary.displayName], which is **nullable** —
/// clustering names nobody on its own. A named person carries their name on a
/// caption line under the circle; an unnamed one is just the face, with no
/// caption, no "Unknown" and no index. Most clusters are unnamed, so the bare
/// circle is the common case and has to look deliberate rather than unfinished.
/// The photo count is not shown here — it lives on `/people`, where a second
/// line has room; two stacked lines under a circle is what makes this row's
/// height fragile (below).
class PeopleStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final captionSize = styles.caption.fontSize ?? 11;

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
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
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
              SizedBox(
                height: _avatarSize + band,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: people.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpace.s16),
                  itemBuilder: (context, i) => _PersonTile(
                    person: people[i],
                    size: _avatarSize,
                    captionBand: band,
                    captionGap: _captionGap,
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

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.size,
    required this.captionBand,
    required this.captionGap,
  });

  final PersonSummary person;
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

    return GestureDetector(
      onTap: () => context.push('/person/${person.id}'),
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            FaceAvatar(personId: person.id, size: size),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
