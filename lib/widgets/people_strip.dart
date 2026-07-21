import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/database/daos/faces_dao.dart' show PersonSummary;
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/people/widgets/face_avatar.dart';
import 'app_button.dart';
import 'section_header.dart';

/// A horizontal row of person avatars under a "People" header, linking into the
/// People screens. Shared by the Search idle view and the Albums tab so both
/// read as the same browse affordance.
///
/// Names come from [PersonSummary.displayName], which is **nullable** —
/// clustering names nobody on its own. An unnamed person shows its avatar and
/// nothing else: no "Unknown", no index. Until naming exists most clusters are
/// unnamed, so the caption-less row is the common case and has to look
/// deliberate — which is why the strip only reserves caption height when at
/// least one person in it actually has a name.
class PeopleStrip extends StatelessWidget {
  const PeopleStrip({super.key, required this.people});

  final List<PersonSummary> people;

  static const double _avatarSize = 72;
  static const double _captionGap = 6;

  /// Mirrors `AppTextStyles.caption`'s size. The strip needs the number to
  /// compute its own height, which a horizontal list cannot infer from its
  /// children.
  static const double _captionFontSize = 11;

  /// Flutter's default line height for a [TextStyle] that sets none.
  static const double _captionLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;

    final hasAnyName = people.any((p) => p.displayName != null);
    // Scales with the user's text size, so a large-text setting grows the strip
    // instead of clipping the names inside it.
    final captionExtent = hasAnyName
        ? _captionGap +
              MediaQuery.textScalerOf(context).scale(_captionFontSize) *
                  _captionLineHeight
        : 0.0;

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
            // A horizontal ListView gives children a *tight* cross-axis
            // (height) constraint, so this is what the avatar and its caption
            // actually get. Leaving it at the avatar diameter would squash the
            // avatar into an oval to fit a caption, not overflow.
            height: _avatarSize + captionExtent,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final person = people[i];
                return GestureDetector(
                  onTap: () => context.push('/person/${person.id}'),
                  child: SizedBox(
                    width: _avatarSize,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaceAvatar(personId: person.id, size: _avatarSize),
                        if (person.displayName case final name?) ...[
                          const SizedBox(height: _captionGap),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: styles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
