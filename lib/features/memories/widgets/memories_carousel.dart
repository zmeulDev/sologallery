import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/app_dialog.dart';
import '../../../widgets/section_header.dart';
import '../memories_providers.dart';
import 'memory_card.dart';

/// The Library's memories strip: a horizontal row of memory cards above the
/// month grid.
///
/// Renders nothing at all when there are no memories — a new or small library
/// has none, and that is the correct state, not an empty message. Its own
/// `ConsumerWidget` so the query only runs when the row is actually built.
class MemoriesCarousel extends ConsumerWidget {
  const MemoriesCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Loading and error both mean "nothing to show here yet"; the Library's
    // own month grid owns the screen-level states.
    final memories = ref.watch(memoriesProvider).value ?? const [];
    if (memories.isEmpty) return const SizedBox.shrink();

    const cardHeight = MemoryCard.width / MemoryCard.aspectRatio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SectionHeader(label: 'Memories'),
          ),
          // A horizontal ListView constrains children tightly on the cross
          // axis, so the row needs an explicit height.
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: memories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final memory = memories[i];
                return MemoryCard(
                  memory: memory,
                  onTap: () => context.push('/memory/${memory.id}'),
                  onLongPress: () => _confirmHide(context, ref, memory.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmHide(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final hide = await showAppConfirmDialog(
      context,
      title: 'Remove this memory?',
      message: 'It leaves the carousel for good. Your photos are untouched.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep',
    );
    if (hide) {
      await ref.read(memoryActionsProvider).hide(id);
    }
  }
}
