@Tags(['nonblocking'])
library;

import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/cache/dependency_cache.dart';
import 'package:path/path.dart' as path;
void main() {
  group('Dependency Cache Smoke Tests', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() async {
      Directory.current = Directory(originalDir);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('cache directory is created when saving cache', () async {
      final cacheKey = DependencyCache.getCacheKey(
        packageName: 'test_package',
        packageVersion: '1.0.0',
        detectorHash: 'v3.0.0',
        sdkVersion: '3.0.0',
      );

      final testData = {
        'test_file.dart': {
          'widgetCount': 5,
          'widgetsWithKeys': 3,
          'keysFound': ['key1', 'key2'],
        },
      };

      await DependencyCache.saveCache(tempDir.path, cacheKey, testData);

      // Verify cache directory was created
      final cacheDir = Directory(
          path.join(tempDir.path, '.dart_tool/flutter_keycheck/cache'));
      expect(await cacheDir.exists(), isTrue,
          reason: 'Cache directory should be created at ${cacheDir.path}');

      // Verify cache file was created
      final cacheFile = DependencyCache.getCacheFile(tempDir.path, cacheKey);
      expect(await cacheFile.exists(), isTrue,
          reason: 'Cache file should exist at ${cacheFile.path}');
    });

    test('cache can be loaded after saving', () async {
      final cacheKey = DependencyCache.getCacheKey(
        packageName: 'test_package',
        packageVersion: '1.0.0',
        detectorHash: 'v3.0.0',
        sdkVersion: '3.0.0',
      );

      final testData = {
        'test_file.dart': {
          'widgetCount': 5,
          'widgetsWithKeys': 3,
          'keysFound': ['key1', 'key2'],
        },
      };

      // Save cache
      await DependencyCache.saveCache(tempDir.path, cacheKey, testData);

      // Load cache
      final loaded = await DependencyCache.loadCache(tempDir.path, cacheKey);

      expect(loaded, isNotNull);
      expect(loaded!['test_file.dart'], isNotNull);
      expect(loaded['test_file.dart']['widgetCount'], equals(5));
      expect(loaded['test_file.dart']['keysFound'], contains('key1'));
      expect(loaded['test_file.dart']['keysFound'], contains('key2'));
    });

    test('cache expires after 24 hours', () async {
      final cacheKey = DependencyCache.getCacheKey(
        packageName: 'test_package',
        packageVersion: '1.0.0',
        detectorHash: 'v3.0.0',
        sdkVersion: '3.0.0',
      );

      final testData = {'test': 'data'};

      // Create cache file manually with old timestamp
      final cacheFile = DependencyCache.getCacheFile(tempDir.path, cacheKey);
      await cacheFile.parent.create(recursive: true);

      final oldTimestamp = DateTime.now().subtract(const Duration(hours: 25));
      final cacheContent = {
        'cache_key': cacheKey,
        'cached_at': oldTimestamp.toIso8601String(),
        'result': testData,
      };

      await cacheFile.writeAsString(json.encode(cacheContent));

      // Try to load expired cache
      final loaded = await DependencyCache.loadCache(tempDir.path, cacheKey);

      expect(loaded, isNull, reason: 'Expired cache should return null');
      expect(await cacheFile.exists(), isFalse,
          reason: 'Expired cache file should be deleted');
    });

    test('cache handles invalid JSON gracefully', () async {
      final cacheKey = DependencyCache.getCacheKey(
        packageName: 'test_package',
        packageVersion: '1.0.0',
        detectorHash: 'v3.0.0',
        sdkVersion: '3.0.0',
      );

      // Create cache file with invalid JSON
      final cacheFile = DependencyCache.getCacheFile(tempDir.path, cacheKey);
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsString('invalid json content');

      // Try to load invalid cache
      final loaded = await DependencyCache.loadCache(tempDir.path, cacheKey);

      expect(loaded, isNull, reason: 'Invalid cache should return null');
    });

    test('cache key generation is consistent', () {
      final key1 = DependencyCache.getCacheKey(
        packageName: 'package',
        packageVersion: '1.0.0',
        detectorHash: 'hash',
        sdkVersion: 'sdk',
      );

      final key2 = DependencyCache.getCacheKey(
        packageName: 'package',
        packageVersion: '1.0.0',
        detectorHash: 'hash',
        sdkVersion: 'sdk',
      );

      expect(key1, equals(key2));
      expect(key1, equals('package@1.0.0|hash|sdk'));
    });

    test('clear cache removes all cached files', () async {
      // Create multiple cache entries
      for (int i = 0; i < 3; i++) {
        final cacheKey = DependencyCache.getCacheKey(
          packageName: 'package_$i',
          packageVersion: '1.0.0',
          detectorHash: 'v3.0.0',
          sdkVersion: '3.0.0',
        );

        await DependencyCache.saveCache(tempDir.path, cacheKey, {'test': i});
      }

      // Verify cache directory exists
      final cacheDir = Directory(
          path.join(tempDir.path, '.dart_tool/flutter_keycheck/cache'));
      expect(await cacheDir.exists(), isTrue);

      // Clear cache
      await DependencyCache.clearCache(tempDir.path);

      // Verify cache directory is removed
      expect(await cacheDir.exists(), isFalse,
          reason: 'Cache directory should be removed after clearing');
    });

    test('cache directory structure is correct', () async {
      final cacheKey = DependencyCache.getCacheKey(
        packageName: 'test_package',
        packageVersion: '1.0.0',
        detectorHash: 'v3.0.0',
        sdkVersion: '3.0.0',
      );

      await DependencyCache.saveCache(tempDir.path, cacheKey, {'test': 'data'});

      // Check directory structure
      final dartToolDir = Directory(path.join(tempDir.path, '.dart_tool'));
      final keyCheckDir =
          Directory(path.join(dartToolDir.path, 'flutter_keycheck'));
      final cacheDir = Directory(path.join(keyCheckDir.path, 'cache'));

      expect(await dartToolDir.exists(), isTrue,
          reason: '.dart_tool directory should exist');
      expect(await keyCheckDir.exists(), isTrue,
          reason: 'flutter_keycheck directory should exist');
      expect(await cacheDir.exists(), isTrue,
          reason: 'cache directory should exist');
    });
  });
}
