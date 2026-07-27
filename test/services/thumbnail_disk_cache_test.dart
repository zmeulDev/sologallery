import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sologallery/services/thumbnail_disk_cache.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('thumb_cache_test');
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  ThumbnailDiskCache cacheIn(
    Directory dir, {
    int maxBytes = 200 * 1024 * 1024,
    int sweepEvery = 64,
  }) =>
      ThumbnailDiskCache(
        resolveDirectory: () async => dir,
        maxBytes: maxBytes,
        sweepEvery: sweepEvery,
      );

  Uint8List bytes(int n, [int fill = 7]) =>
      Uint8List.fromList(List.filled(n, fill));

  group('ThumbnailDiskCache', () {
    test('put then get round-trips the bytes and creates the dir', () async {
      final dir = Directory(p.join(tempRoot.path, 'nested', 'cache'));
      final cache = cacheIn(dir);
      expect(await dir.exists(), isFalse);

      final data = bytes(128, 3);
      await cache.put('asset-1', 400, 111, data);

      expect(await dir.exists(), isTrue, reason: 'created lazily on first put');
      expect(await cache.get('asset-1', 400, 111), data);
    });

    test('get misses when nothing was written', () async {
      final cache = cacheIn(tempRoot);
      expect(await cache.get('missing', 400, 0), isNull);
    });

    test('a changed signature (edited asset) misses the stale entry', () async {
      final cache = cacheIn(tempRoot);
      await cache.put('asset-1', 400, 100, bytes(64));
      expect(await cache.get('asset-1', 400, 100), isNotNull);
      // modifiedDateSecond advanced → different key → miss, not stale bytes.
      expect(await cache.get('asset-1', 400, 200), isNull);
    });

    test('a different size is a distinct entry', () async {
      final cache = cacheIn(tempRoot);
      await cache.put('asset-1', 400, 0, bytes(64, 1));
      await cache.put('asset-1', 512, 0, bytes(64, 2));
      expect((await cache.get('asset-1', 400, 0))!.first, 1);
      expect((await cache.get('asset-1', 512, 0))!.first, 2);
    });

    test('an id containing filesystem-unsafe chars round-trips (iOS ids)', () async {
      final cache = cacheIn(tempRoot);
      const iosId = 'ABCD-1234/L0/001';
      await cache.put(iosId, 400, 0, bytes(32));
      expect(await cache.get(iosId, 400, 0), isNotNull);
    });

    test('clear empties the cache', () async {
      final cache = cacheIn(tempRoot);
      await cache.put('a', 400, 0, bytes(64));
      await cache.clear();
      expect(await cache.get('a', 400, 0), isNull);
      // Still usable after a clear.
      await cache.put('b', 400, 0, bytes(64));
      expect(await cache.get('b', 400, 0), isNotNull);
    });

    test('evicts oldest-first once over budget', () async {
      // Budget fits ~2 of the 100-byte entries; sweep on every write.
      final cache = cacheIn(tempRoot, maxBytes: 250, sweepEvery: 1);

      await cache.put('oldest', 400, 0, bytes(100, 1));
      // Space out mtimes so ordering is deterministic on coarse filesystems.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cache.put('middle', 400, 0, bytes(100, 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cache.put('newest', 400, 0, bytes(100, 3));

      // Three 100-byte writes exceed 250 → the oldest is evicted, newest kept.
      expect(await cache.get('oldest', 400, 0), isNull);
      expect(await cache.get('newest', 400, 0), isNotNull);

      final remaining = tempRoot
          .listSync()
          .whereType<File>()
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(remaining, lessThanOrEqualTo(250));
    });

    test('a failure to resolve the directory disables the cache silently', () async {
      final cache = ThumbnailDiskCache(
        resolveDirectory: () async => throw const FileSystemException('nope'),
      );
      // No throw; just misses.
      await cache.put('a', 400, 0, bytes(16));
      expect(await cache.get('a', 400, 0), isNull);
    });
  });
}
