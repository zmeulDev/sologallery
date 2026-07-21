import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/database/daos/faces_dao.dart' show PersonSummary;
import '../core/format/count_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../features/people/widgets/face_avatar.dart';
import 'app_button.dart';
import 'section_header.dart';

/// A horizontal row of person tiles under a "People" header, linking into the
/// People screens. Shared by the Search idle view and the Albums tab so both
/// read as the same browse affordance.
///
/// Names come from [PersonSummary.displayName], which is **nullable** —
/// clustering names nobody on its own. A named person carries their name and
/// photo count on a scrim across the foot of their tile; an unnamed one is just
/// the face, with no caption, no "Unknown" and no index. Most clusters are
/// unnamed, so the bare tile is the common case and has to look deliberate
/// rather than unfinished.
///
/// The name sits **inside** the tile rather than under it, which is a layout
/// decision as much as a visual one: a horizontal `ListView` gives its children
/// a tight height, so a caption line underneath makes the row's height depend on
/// font metrics and text scale. Reserving that band arithmetically overflowed by
/// a fraction of a pixel on a device whose font ran fractionally taller. A tile
/// of fixed size with the label overlaid cannot have that problem at all.
class PeopleStrip extends StatelessWidget {
  const PeopleStrip({super.key, required this.people});

  final List<PersonSummary> people;

  static const double _tileSize = 88;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          const SizedBox(height: 8),
          SizedBox(
            height: _tileSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, i) =>
                  _PersonTile(person: people[i], size: _tileSize),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.size});

  final PersonSummary person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final name = person.displayName;

    return GestureDetector(
      onTap: () => context.push('/person/${person.id}'),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FaceAvatar(
              personId: person.id,
              size: size,
              borderRadius: AppRadius.br12,
            ),
            if (name != null)
              // Positioned without `top`, so the label lays out at its natural
              // height and grows *upward* over the face as text scales. The
              // tile's own height never changes, so the row can't overflow.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.r12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppOverMedia.scrimHeavy],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.caption.copyWith(
                            color: AppOverMedia.glyph,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          photoCountLabel(person.faceCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.caption.copyWith(
                            color: AppOverMedia.glyphSoft,
                            fontSize: 9,
                          ),
                        ),
                      ],
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
