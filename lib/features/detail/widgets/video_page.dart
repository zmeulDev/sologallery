import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../detail_providers.dart';

/// One swipeable page in the detail viewer for a **video** asset: the clip on
/// the black stage, tap to play/pause, a scrubbable progress bar, a centered
/// play glyph while paused. The file is local ([videoFileProvider]) — nothing
/// is streamed. Starts paused on the first frame; pauses when swiped away and
/// disposes its controller so no off-screen video keeps playing.
class VideoPage extends ConsumerWidget {
  const VideoPage({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(videoFileProvider(assetId));
    return file.when(
      data: (f) => f == null ? const _Unavailable() : _Player(file: f),
      loading: () => const _Loading(),
      error: (_, _) => const _Unavailable(),
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({required this.file});

  final File file;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void deactivate() {
    // Swiped to another page (or the viewer closed) — never keep playing
    // off-screen.
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Loading();
    return GestureDetector(
      onTap: _toggle,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, _) => AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: const _PlayGlyph(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
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

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0x66000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white24),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 44),
    );
  }
}
