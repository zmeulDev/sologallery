import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../library/month_grid_screen.dart' show CenteredNote;
import 'people_providers.dart';
import 'widgets/face_avatar.dart';

/// People (`/people`): the clustered persons found on-device, reached from the
/// Search screen's People strip. Grows as indexing/clustering progresses.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(personSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const CenteredNote('Couldn\'t load people.'),
        data: (persons) => persons.isEmpty
            ? const CenteredNote(
                'No people yet. Faces are grouped as your library is indexed.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: persons.length,
                itemBuilder: (context, i) => _PersonCard(person: persons[i]),
              ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final name = person.displayName ?? 'Unnamed';
    return GestureDetector(
      onTap: () => context.push('/person/${person.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, c) =>
                FaceAvatar(personId: person.id, size: c.maxWidth),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.body.copyWith(
              color: scheme.onSurface,
              fontWeight: person.displayName == null
                  ? FontWeight.w400
                  : FontWeight.w600,
            ),
          ),
          Text(
            person.faceCount == 1 ? '1 photo' : '${person.faceCount} photos',
            style: styles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
