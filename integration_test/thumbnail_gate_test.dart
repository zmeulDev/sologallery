import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof of the bounded thumbnail pipeline, against real
/// `photo_manager`. This is the paired counterpart to
/// `test/services/thumbnail_gate_test.dart`, which exercises the gate's
/// bookkeeping with synthetic tasks (CLAUDE.md "fake-pairing rule"). The host
/// test cannot see what actually matters here:
///
///  * that a burst larger than `maxConcurrent` still resolves *every* request
///    — a gate that leaks slots or drops a waiter shows up as permanently
///    blank grid cells, not as an error;
///  * that cancelling some requests does not starve or corrupt the rest;
///  * that the edges [avatarThumbEdge] picks come back as real decodable
///    images, since `thumbnail(id, N, N)` is aspect-*fill* (short edge N, long
///    edge larger — the CLAUDE.md gotcha) and the face-box maths depends on it.
///
/// Requires photo-library access already granted and at least a few photos.
/// Run with:
///   flutter test integration_test/thumbnail_gate_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<PhotoLibraryService> grantedService() async {
    final service = PhotoLibraryService();
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (see CLAUDE.md — pm grant '
          'READ_MEDIA_IMAGES et al. between install and run).',
    );
    return service;
  }

  /// Real asset ids, newest first. Fails loudly rather than letting a
  /// zero-asset device turn every assertion below into a vacuous pass.
  Future<List<String>> assetIds(PhotoLibraryService service, int count) async {
    final folders = await service.deviceFolders();
    expect(folders, isNotEmpty, reason: 'Seed photos on the device.');
    final assets = await service.folderAssets(
      folderId: folders.first.id,
      page: 0,
      pageSize: count,
    );
    expect(
      assets.length,
      greaterThanOrEqualTo(count),
      reason: 'Need at least $count photos in "${folders.first.name}" to '
          'exercise a burst past the concurrency cap; found ${assets.length}.',
    );
    return [for (final a in assets) a.id];
  }

  Future<ui.Size> decodedSize(List<int> bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(bytes),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = ui.Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  test('a burst past the concurrency cap resolves every request', () async {
    final service = await grantedService();
    // 24 > the gate's cap of 6, so most of these queue behind it.
    final ids = await assetIds(service, 24);

    final results = await Future.wait([
      for (final id in ids) service.thumbnail(id, 400, 400),
    ]);

    expect(results.length, ids.length);
    for (var i = 0; i < results.length; i++) {
      expect(
        results[i],
        isNotNull,
        reason: 'Request $i (${ids[i]}) came back null — a queued request was '
            'dropped, which renders as a permanently blank grid cell.',
      );
      expect(results[i]!, isNotEmpty);
    }
  });

  test('cancelled requests are skipped and the rest still resolve', () async {
    final service = await grantedService();
    final ids = await assetIds(service, 24);

    // Cancel every other request the moment it is made, mimicking a fling that
    // recycles half the cells before their decode gets a slot.
    final results = await Future.wait([
      for (var i = 0; i < ids.length; i++)
        service.thumbnail(ids[i], 400, 400, cancelled: () => i.isOdd),
    ]);

    var kept = 0;
    for (var i = 0; i < results.length; i++) {
      if (i.isOdd) {
        expect(
          results[i],
          isNull,
          reason: 'Request $i was cancelled but still produced bytes — the '
              'gate ran a decode nobody was waiting for.',
        );
      } else {
        expect(
          results[i],
          isNotNull,
          reason: 'Live request $i was starved by its cancelled neighbours.',
        );
        kept++;
      }
    }
    expect(kept, ids.length ~/ 2, reason: 'positive control: work was done');
  });

  test('the gate stays usable after a burst', () async {
    // A leaked slot would not fail the burst above — it would fail everything
    // after it, so this asserts the pipeline still works once the dust settles.
    final service = await grantedService();
    final ids = await assetIds(service, 24);

    await Future.wait([
      for (final id in ids)
        service.thumbnail(id, 400, 400, cancelled: () => true),
    ]);

    final after = await service.thumbnail(ids.first, 400, 400);
    expect(
      after,
      isNotNull,
      reason: 'A fully-cancelled burst leaked its slots — the gate is now '
          'permanently blocked and no thumbnail will ever load again.',
    );
  });

  test('every avatar bucket returns a decodable, correctly-sized image', () async {
    final service = await grantedService();
    final ids = await assetIds(service, 1);
    final id = ids.first;

    for (final edge in [256, 384, 512, 768, 1024]) {
      final bytes = await service.thumbnail(id, edge, edge);
      expect(bytes, isNotNull, reason: 'No thumbnail came back at edge $edge.');

      final size = await decodedSize(bytes!);
      // Aspect-fill: the SHORT edge is what was asked for, the long edge is
      // larger. Pinned because the face-box maths reads the decoded dimensions
      // and would silently mis-crop every avatar if this ever changed.
      final shortEdge = size.shortestSide;
      expect(
        shortEdge,
        closeTo(edge, 1),
        reason: 'Asked for $edge, got ${size.width}x${size.height} — the '
            'short edge is not the requested one, so avatar cropping is '
            'working from a false assumption.',
      );
      expect(size.longestSide, greaterThanOrEqualTo(shortEdge));
    }
  });

  test('a small face asks for more pixels than a large one, and gets them',
      () async {
    // End-to-end for the derived avatar edge: the sizes avatarThumbEdge picks
    // must actually carry enough pixels for the face box at 64pt / 3x.
    final service = await grantedService();
    final ids = await assetIds(service, 1);

    final bigFace = avatarThumbEdge(
      avatarSize: 64,
      devicePixelRatio: 3,
      boxFraction: 0.9,
    );
    final smallFace = avatarThumbEdge(
      avatarSize: 64,
      devicePixelRatio: 3,
      boxFraction: 0.2,
    );
    expect(bigFace, lessThan(smallFace));

    final bigBytes = await service.thumbnail(ids.first, bigFace, bigFace);
    final smallBytes = await service.thumbnail(ids.first, smallFace, smallFace);
    expect(bigBytes, isNotNull);
    expect(smallBytes, isNotNull);

    final bigSize = await decodedSize(bigBytes!);
    final smallSize = await decodedSize(smallBytes!);
    expect(
      smallSize.shortestSide,
      greaterThan(bigSize.shortestSide),
      reason: 'The small-face request did not actually yield a larger image, '
          'so group-photo avatars would be upscaled.',
    );
  });
}
