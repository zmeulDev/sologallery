import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';

/// A static, layout-faithful placeholder for the Library while its first data
/// arrives. Mirrors the real timeline's shape so the transition from loading to
/// loaded is a content swap rather than a layout jump.
///
/// Built from existing tokens only: `surface2` blocks, `br12` corners, `s4`
/// grid gutter, and `s20` section rhythm. No shimmer, no animation — decorative
/// motion is forbidden in this app, and a static skeleton already reads as
/// "content is on its way" more honestly than a pulsing bar.
class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSpace.s4,
        bottom: AppSpace.s24 + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MemoriesSkeleton(),
          const SizedBox(height: AppSpace.s20),
          _MonthSectionSkeleton(colors: colors),
          const SizedBox(height: AppSpace.s20),
          _MonthSectionSkeleton(colors: colors),
        ],
      ),
    );
  }
}

class _MemoriesSkeleton extends StatelessWidget {
  const _MemoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(width: 72, colors: colors),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => _SkeletonCard(colors: colors),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSectionSkeleton extends StatelessWidget {
  const _MonthSectionSkeleton({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s8,
        0,
        AppSpace.s8,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            child: _SkeletonBar(width: 96, colors: colors),
          ),
          const SizedBox(height: 10),
          const _PreviewGridSkeleton(),
        ],
      ),
    );
  }
}

class _PreviewGridSkeleton extends StatelessWidget {
  const _PreviewGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : AppSpace.s4),
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: col == 0 ? 0 : AppSpace.s4,
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.br12,
                          child: ColoredBox(color: colors.surface2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(
        color: colors.surface2,
        child: const SizedBox(width: 150, height: 120),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.colors});

  final double width;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(
        color: colors.surface2,
        child: SizedBox(width: width, height: 12),
      ),
    );
  }
}
