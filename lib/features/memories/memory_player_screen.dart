import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/photo_library_service.dart' show AssetRef;
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/precache_adjacent.dart';
import '../detail/widgets/photo_page.dart';
import 'memories_providers.dart';

/// Scene-transition motion for the memory player — the one piece of decorative
/// motion the app keeps (see docs/plans/remove-animations-and-performance.md).
/// Inlined here so there is no app-wide motion token to misuse; the reduced
/// motion gate is read locally via [MediaQuery.disableAnimationsOf].
const Duration _kSceneChange = Duration(milliseconds: 320);
const Curve _kSceneCurve = Curves.easeOutCubic;

/// Plays one memory as a full-screen story: a title card, then each photo in
/// turn, advancing on a timer.
///
/// Structurally the detail viewer minus its chrome plus a clock — it reuses
/// `PhotoPage`, so image bytes stay screen-capped and originals are never
/// decoded. Hold anywhere to pause, tap to advance by hand, swipe to move in
/// either direction, tap the close button to leave.
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

  /// Advances one page, or leaves the story if this was the last one.
  ///
  /// Shared by the clock and by tap-to-advance, so a tap lands on exactly the
  /// same end-of-story behaviour as running out of time. There's no separate
  /// timer reset here: moving the page fires [_onPageChanged], which restarts
  /// the clock — so a tap gives the next photo its full turn on screen rather
  /// than inheriting the remainder of this one's.
  void _advance() {
    if (!mounted) return;
    // The photo list isn't in yet, so there is no "last page" to be past —
    // without this a tap on the opening title card would read as the end of
    // the story and close the player.
    if (_pages == 0) return;
    if (_index >= _pages - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    // The reduced-motion gate still applies — under "remove animations" the
    // auto-advance jump-cuts, which is exactly what that setting asks for.
    // PageController.nextPage asserts a non-zero duration, so jump instead.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: _kSceneChange, curve: _kSceneCurve);
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

    final list = assets.value ?? const <AssetRef>[];

    // Title card + one page per photo — but 0 until the photos are actually
    // in, which parks both the clock and tap-to-advance on the title card
    // instead of running a story whose length isn't known yet.
    final pages = assets.hasValue ? list.length + 1 : 0;
    if (_pages != pages) {
      _pages = pages;
      // The first timer can only start once we know how many pages there
      // are; scheduling it during build would fight the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _restartTimer());
    }

    // The cover comes from the summary the carousel already holds, so the
    // title card is on screen from the player's *first* frame — the card's
    // Hero has something to fly into and the route can stay opaque black
    // rather than fading a light shell in around the stage. Only a deep link
    // arrives with no summary, and it falls back to the opening photo.
    final cover = summary?.coverAssetId ?? list.firstOrNull?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch ((assets, cover)) {
        (AsyncError(), _) => const _Stage(
          child: _Message('This memory is unavailable.'),
        ),
        (AsyncData(:final value), _) when value.isEmpty => const _Stage(
          child: _Message('This memory has no photos left.'),
        ),
        // No summary and no photos yet: a deep link, still loading. The one
        // case with nothing to show.
        (_, null) => const _Stage(child: _Spinner()),
        (_, final String cover) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Tap and long-press coexist: the press-down pauses
                // immediately, and a quick release cancels the long press
                // (un-pausing) before the tap advances.
                onTap: _advance,
                onLongPressDown: (_) => _setHeld(true),
                onLongPressUp: () => _setHeld(false),
                onLongPressCancel: () => _setHeld(false),
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  // One page while the photos load — the title card, which is
                  // what the memory opens on anyway.
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) => i == 0
                      ? _TitleCard(
                          memoryId: widget.memoryId,
                          title: summary?.title ?? 'Memory',
                          subtitle: summary?.subtitle,
                          count: summary?.assetCount ?? list.length,
                          coverAssetId: cover,
                        )
                      : PhotoPage(assetId: list[i - 1].id),
                ),
              ),
            ),
            // Page 0 is the title card, so the photo under the cursor is
            // _index - 1 — and on the title card itself that's -1, which
            // warms the opening photos while the title is still up.
            //
            // Weighted forward: a story is played, not browsed, and
            // tap-to-advance outruns a one-page window (the tap lands on the
            // spinner while N+1 is still being fetched). Three ahead keeps
            // the fetches in front of the thumb; one back still covers a
            // swipe to the previous photo.
            //
            // Positioned deliberately: a Stack sizes itself to its largest
            // *non*-positioned child, and every other child here is
            // positioned — so leaving this zero-size warm-up unpositioned
            // collapses the whole stage to 0x0 and clips the story away to
            // a black screen.
            Positioned.fill(
              child: PrecacheAdjacent(
                assetIds: [for (final a in list) a.id],
                index: _index - 1,
                ahead: 3,
              ),
            ),
            // Segments come from the summary's count while the photos load,
            // so the spine opens at its real length instead of growing from
            // one segment to the whole story a frame later.
            _Progress(
              pages: pages == 0 ? (summary?.assetCount ?? 0) + 1 : pages,
              index: _index,
              paused: _held,
            ),
            const _CloseButton(),
          ],
        ),
      },
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
      child: Opacity(
        // Dimming the whole bar is the only "paused" signal — no icon, no
        // overlay covering the photo you paused to look at.
        opacity: paused ? 0.35 : 1,
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
    required this.memoryId,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.coverAssetId,
  });

  final int memoryId;
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
                    style: text.sectionLabel.copyWith(
                      color: AppOverMedia.glyphSoft,
                    ),
                  ),
                ),
              Text(
                title,
                style: text.pageTitle.copyWith(
                  color: AppOverMedia.glyph,
                  height: 1.15,
                ),
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
