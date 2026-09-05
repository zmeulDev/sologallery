import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/asset_grid.dart' show kPhotoGridCacheExtent;
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import '../settings/consent_provider.dart';
import 'people_providers.dart';
import 'widgets/face_avatar.dart';

/// People (`/people`): the clustered persons found on-device, reached from the
/// Search screen's People strip. Grows as indexing/clustering progresses.
///
/// Selecting two or more entries merges them into one person. Clustering cannot
/// reunite someone across a strong appearance change — glasses, a beard —
/// without also fusing genuinely different people, so the user gets the final
/// say (see `docs/plans/people-merge-action.md`).
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  /// Non-null only in selection mode, so "selecting nothing" and "not
  /// selecting" stay distinguishable.
  Set<int>? _selected;

  /// The merge confirmation lands on the root messenger (it sits above the
  /// Navigator), so it outlives this route unless we take it down ourselves.
  /// Resolved here because `dispose()` is too late to look up an ancestor.
  ScaffoldMessengerState? _messenger;

  bool get _selecting => _selected != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    // An Undo for a merge made on this screen has no meaning once the screen
    // is gone — it must not follow the user into the rest of the app.
    _messenger?.hideCurrentSnackBar();
    super.dispose();
  }

  /// Opens a person. The route is *pushed*, so this screen is not disposed and
  /// `dispose`'s cleanup never runs — the merge confirmation has to be taken
  /// down here too, or an Undo for a merge made behind the detail screen rides
  /// along on top of it.
  void _open(int id) {
    _messenger?.hideCurrentSnackBar();
    context.push('/person/$id');
  }

  void _toggle(int id) {
    setState(() {
      final next = {..._selected!};
      next.contains(id) ? next.remove(id) : next.add(id);
      _selected = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(personSummariesProvider);
    // A deep link can land here with the feature off. Say so plainly and point
    // at the fix, rather than the "still indexing" note — nothing is coming,
    // and implying otherwise would be a lie.
    if (!(ref.watch(facesEnabledProvider).value ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('People')),
        body: const EmptyState.note(
          'Face detection is off. Turn it on in Settings to group photos by '
          'who\'s in them.',
        ),
      );
    }

    final chosen = _selected ?? const <int>{};
    final persons = people.value ?? const <PersonSummary>[];
    // Resolved once for every person currently on the grid, instead of each
    // avatar cell hitting the DB on its own as it scrolls into view (B2).
    final covers =
        ref.watch(personCoversProvider).value ?? const <int, CoverFace>{};
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '${chosen.length} selected' : 'People'),
        actions: [
          // Merging needs two entries to choose between, so the affordance only
          // exists once there are two.
          if (persons.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s8),
              child: AppButton.quiet(
                label: _selecting ? 'Cancel' : 'Select',
                onPressed: () =>
                    setState(() => _selected = _selecting ? null : <int>{}),
              ),
            ),
        ],
      ),
      body: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load people.'),
        data: (persons) => persons.isEmpty
            ? const EmptyState.note(
                'No people yet. Faces are grouped as your library is indexed.',
              )
            : GridView.builder(
                scrollCacheExtent: kPhotoGridCacheExtent,
                padding: const EdgeInsets.all(AppSpace.s16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpace.s16,
                  crossAxisSpacing: AppSpace.s16,
                  childAspectRatio: 0.78,
                ),
                itemCount: persons.length,
                itemBuilder: (context, i) => _PersonCard(
                  person: persons[i],
                  cover: covers[persons[i].id],
                  selecting: _selecting,
                  selected: chosen.contains(persons[i].id),
                  onToggle: () => _toggle(persons[i].id),
                  onOpen: () => _open(persons[i].id),
                ),
              ),
      ),
      bottomNavigationBar: _selecting
          ? _MergeBar(
              count: chosen.length,
              onMerge: () => _merge(persons, chosen),
            )
          : null,
    );
  }

  Future<void> _merge(List<PersonSummary> persons, Set<int> chosen) async {
    // The most-photographed of the selection keeps its row, so its name and
    // cover survive — the same rule the automatic re-cluster uses.
    final picked = [for (final p in persons) if (chosen.contains(p.id)) p]
      ..sort((a, b) => b.faceCount.compareTo(a.faceCount));
    if (picked.length < 2) return;
    final survivor = picked.first;
    final name = survivor.displayName;
    final others = picked.skip(1).toList();

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Merge people?',
      message: others.length == 1
          ? '${_label(others.single)} and ${_label(survivor)} become one '
              'person${name == null ? '' : ', named $name'}.'
          : '${picked.length} people become one'
              '${name == null ? '' : ', named $name'}.',
      confirmLabel: 'Merge',
    );
    if (!confirmed || !mounted) return;

    final actions = ref.read(peopleActionsProvider);
    for (final other in others) {
      await actions.merge(into: survivor.id, from: other.id);
    }
    if (!mounted) return;
    setState(() => _selected = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Merged'),
        // `SnackBar.persist` defaults to `action != null`, and the messenger
        // skips its timeout entirely when it is set — an Undo snackbar would
        // otherwise never dismiss, on any screen. Long enough to reach for
        // Undo, short enough to leave on its own.
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final other in others) {
              actions.separate(other.id, from: survivor.id);
            }
          },
        ),
      ),
    );
  }

  static String _label(PersonSummary p) => p.displayName ?? 'Unnamed';
}

/// The one action available in selection mode, on a surface bar that keeps it
/// clear of the grid and the gesture inset.
class _MergeBar extends StatelessWidget {
  const _MergeBar({required this.count, required this.onMerge});

  final int count;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: AppButton.primary(
            label: count < 2 ? 'Merge people' : 'Merge $count people',
            expand: true,
            onPressed: count < 2 ? null : onMerge,
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    this.cover,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  final PersonSummary person;

  /// This person's cover face, resolved up front by [personCoversProvider] —
  /// see [FaceAvatar.cover].
  final CoverFace? cover;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final name = person.displayName ?? 'Unnamed';
    return GestureDetector(
      onTap: selecting ? onToggle : onOpen,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // The avatar takes the space left after the two text lines and sizes
          // to the smaller of that height / the width, so the card never
          // overflows its aspect-ratio-fixed cell (even at large font scales).
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final edge = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
                return Center(
                  child: SizedBox(
                    width: edge,
                    height: edge,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FaceAvatar(
                            personId: person.id,
                            size: edge,
                            cover: cover,
                          ),
                        ),
                        // Always built, never conditional, so the tree shape is
                        // stable across selection changes.
                        Positioned.fill(
                          child: Opacity(
                            opacity: selected ? 1 : 0,
                            child: _SelectedRing(edge: edge),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.body.copyWith(
              color: scheme.onSurface,
              fontWeight: person.displayName == null
                  ? FontWeight.w400
                  : FontWeight.w700,
            ),
          ),
          Text(
            photoCountLabel(person.faceCount),
            style: styles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The selected state drawn over an avatar: an ink ring plus a check disc.
class _SelectedRing extends StatelessWidget {
  const _SelectedRing({required this.edge});

  final double edge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final disc = edge * 0.32;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.pillActiveBg, width: 3),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.pillActiveBg,
              border: Border.all(color: colors.pillActiveText, width: 2),
            ),
            child: Icon(
              Icons.check_rounded,
              size: disc * 0.6,
              color: colors.pillActiveText,
            ),
          ),
        ),
      ],
    );
  }
}
