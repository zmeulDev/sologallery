import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_thumbnail.dart';
import '../detail/widgets/photo_page.dart';
import 'memories_providers.dart';

/// Plays one memory as a full-screen story: a title card, then each photo in
/// turn, advancing on a timer.
///
/// Structurally the detail viewer minus its chrome plus a clock — it reuses
/// `PhotoPage`, so image bytes stay screen-capped and originals are never
/// decoded. Hold anywhere to pause, swipe to move by hand, tap the close
/// button to leave.
class MemoryPlayerScreen extends ConsumerStatefulWidget {
  const MemoryPlayerScreen({super.key, required this.memoryId});

  final int memoryId;

  /// How long each photo holds the screen.
  static const pageDuration = Duration(seconds: 3);

  @override
  ConsumerState<MemoryPlayerScreen> createState() => _MemoryPlayerScreenState();
}

class _MemoryPlayerScreenState extends ConsumerState<MemoryPlayerScreen> {
  final _controller = PageController();

  Timer? _timer;
  int _index = 0;
  bool _held = false;

  /// Page count including the title card; 0 until the assets load.
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    // Opening is what "seen" means — do it once, not per page.
    unawaited(ref.read(memoryActionsProvider).markSeen(widget.memoryId));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_held || _pages == 0) return;
    _timer = Timer(MemoryPlayerScreen.pageDuration, _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index >= _pages - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    // 320ms is deliberate story pacing (no motion token matches); the
    // reduced-motion gate still applies — a zero duration jump-cuts the
    // auto-advance, which is exactly what "remove animations" asks for.
    // PageController.nextPage asserts a non-zero duration, so jump instead.
    final d = AppMotion.of(context, const Duration(milliseconds: 320));
    if (d == Duration.zero) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: d, curve: Curves.easeOut);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _restartTimer();
  }

  void _setHeld(bool held) {
    if (_held == held) return;
    setState(() => _held = held);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(memoryAssetsProvider(widget.memoryId));
    final summary = ref
        .watch(memoriesProvider)
        .value
        ?.where((m) => m.id == widget.memoryId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: assets.when(
        loading: () => const _Stage(child: _Spinner()),
        error: (_, _) => _Stage(child: _Message('This memory is unavailable.')),
        data: (list) {
          if (list.isEmpty) {
            return _Stage(child: _Message('This memory has no photos left.'));
          }
          // Title card + one page per photo.
          final pages = list.length + 1;
          if (_pages != pages) {
            _pages = pages;
            // The first timer can only start once we know how many pages there
            // are; scheduling it during build would fight the frame.
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _restartTimer());
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressDown: (_) => _setHeld(true),
                  onLongPressUp: () => _setHeld(false),
                  onLongPressCancel: () => _setHeld(false),
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: _onPageChanged,
                    itemCount: pages,
                    itemBuilder: (context, i) => i == 0
                        ? _TitleCard(
                            title: summary?.title ?? 'Memory',
                            subtitle: summary?.subtitle,
                            count: list.length,
                            // Falls back to the opening photo, so the title
                            // card is never a bare black frame.
                            coverAssetId:
                                summary?.coverAssetId ?? list.first.id,
                          )
                        : PhotoPage(assetId: list[i - 1].id),
                  ),
                ),
              ),
              _Progress(pages: pages, index: _index, paused: _held),
              const _CloseButton(),
            ],
          );
        },
      ),
    );
  }
}

/// The story's spine: one segment per page, filled up to the current one. The
/// same motif the memory card previews.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.pages,
    required this.index,
    required this.paused,
  });

  final int pages;
  final int index;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: AppSpace.s16,
      right: AppSpace.s16,
      child: AnimatedOpacity(
        // Dimming the whole bar is the only "paused" signal — no icon, no
        // overlay covering the photo you paused to look at.
        opacity: paused ? 0.35 : 1,
        duration: AppMotion.of(context, AppMotion.medium),
        child: Row(
          children: [
            for (var i = 0; i < pages; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i <= index
                        ? AppOverMedia.glyph
                        : AppOverMedia.segmentOff,
                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                  ),
                  child: const SizedBox(height: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The opening frame: the cover photo, dimmed, with the title over it.
///
/// The cover carries the frame — a text-only card on black reads as a blank
/// screen, not as an opening title. Scrim and bottom-left type block mirror
/// `MemoryCard`, so tapping a card feels like it expanded into the story.
class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.coverAssetId,
  });

  final String title;
  final String? subtitle;
  final int count;
  final String coverAssetId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Stack(
      fit: StackFit.expand,
      children: [
        AssetThumbnail(assetId: coverAssetId, size: 1000),
        // Heavier than the card's scrim: the title is larger here and has to
        // hold against a full-bleed photo rather than a 150px thumbnail.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x59000000),
                Color(0x26000000),
                AppOverMedia.scrimDeep,
              ],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle case final sub?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    sub.toUpperCase(),
                    style: text.sectionLabel
                        .copyWith(color: AppOverMedia.glyphSoft),
                  ),
                ),
              Text(
                title,
                style: text.pageTitle
                    .copyWith(color: AppOverMedia.glyph, height: 1.15),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                photoCountLabel(count),
                style: text.caption.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      right: 8,
      child: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppOverMedia.glyph),
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: Center(child: child)),
          const _CloseButton(),
        ],
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppOverMedia.glyphDim),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Text(
      text,
      style: styles.body.copyWith(color: AppOverMedia.glyphFaint),
    );
  }
}
