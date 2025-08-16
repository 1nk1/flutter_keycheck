import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Cache for dependency scanning results
class DependencyCache {
  static const String cacheDir = '.dart_tool/flutter_keycheck/cache';

  /// Get cache key for a package
  static String getCacheKey({
    required String packageName,
    required String packageVersion,
    required String detectorHash,
    required String sdkVersion,
  }) {
    return '$packageName@$packageVersion|$detectorHash|$sdkVersion';
  }

  /// Get cache file path
  static File getCacheFile(String projectPath, String cacheKey) {
    final hash = sha256.convert(utf8.encode(cacheKey)).toString();
    final cachePath = path.join(projectPath, cacheDir, '$hash.json');
    return File(cachePath);
  }

  /// Load cached scan result
  static Future<Map<String, dynamic>?> loadCache(
    String projectPath,
    String cacheKey,
  ) async {
    final cacheFile = getCacheFile(projectPath, cacheKey);

    if (!await cacheFile.exists()) {
      return null;
    }

    try {
      final content = await cacheFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      // Check if cache is still valid (24 hours)
      final cachedAt = DateTime.parse(data['cached_at'] as String);
      final age = DateTime.now().difference(cachedAt);

      if (age.inHours > 24) {
        // Cache is too old
        await cacheFile.delete();
        return null;
      }

      return data['result'] as Map<String, dynamic>;
    } catch (e) {
      // Invalid cache, delete it
      try {
        await cacheFile.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Save scan result to cache
  static Future<void> saveCache(
    String projectPath,
    String cacheKey,
    Map<String, dynamic> result,
  ) async {
    final cacheFile = getCacheFile(projectPath, cacheKey);

    // Ensure cache directory exists
    await cacheFile.parent.create(recursive: true);

    final cacheData = {
      'cache_key': cacheKey,
      'cached_at': DateTime.now().toIso8601String(),
      'result': result,
    };

    await cacheFile.writeAsString(json.encode(cacheData));
  }

  /// Clear all cache
  static Future<void> clearCache(String projectPath) async {
    final dir = Directory(path.join(projectPath, cacheDir));

    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Get current detector hash (for cache invalidation)
  static String getDetectorHash() {
    // This would hash the detector implementations to detect changes
    // For now, use a version string
    return 'v3.0.0';
  }

  /// Get current SDK version
  static String getSdkVersion() {
    return Platform.version.split(' ').first;
  }
}
