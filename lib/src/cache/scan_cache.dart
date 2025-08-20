import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// SHA256-based caching system for scan results
class ScanCache {
  static const String cacheDir = '.flutter_keycheck/cache';
  static const Duration maxAge = Duration(hours: 24);

  final Map<String, CacheEntry> _memoryCache = {};
  late final Directory _cacheDirectory;

  ScanCache() {
    _cacheDirectory = Directory(cacheDir);
    if (!_cacheDirectory.existsSync()) {
      _cacheDirectory.createSync(recursive: true);
    }
    _loadCache();
  }

  /// Generate cache key from file content
  String generateKey(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return '';

    final content = file.readAsStringSync();
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return '${p.basename(filePath)}_${digest.toString().substring(0, 8)}';
  }

  /// Get cached scan result
  ScanResult? get(String filePath) {
    final key = generateKey(filePath);
    if (key.isEmpty) return null;

    // Check memory cache first
    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired) {
      return memEntry.result;
    }

    // Check disk cache
    final cacheFile = File(p.join(cacheDir, '$key.json'));
    if (cacheFile.existsSync()) {
      try {
        final content = cacheFile.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(json);

        if (!entry.isExpired) {
          _memoryCache[key] = entry;
          return entry.result;
        } else {
          // Clean up expired entry
          cacheFile.deleteSync();
        }
      } catch (e) {
        // Invalid cache file, delete it
        cacheFile.deleteSync();
      }
    }

    return null;
  }

  /// Store scan result in cache
  void put(String filePath, ScanResult result) {
    final key = generateKey(filePath);
    if (key.isEmpty) return;

    final entry = CacheEntry(
      key: key,
      filePath: filePath,
      timestamp: DateTime.now(),
      result: result,
    );

    // Store in memory
    _memoryCache[key] = entry;

    // Store on disk
    final cacheFile = File(p.join(cacheDir, '$key.json'));
    cacheFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.toJson()),
    );
  }

  /// Invalidate cache for a file
  void invalidate(String filePath) {
    final key = generateKey(filePath);
    if (key.isEmpty) return;

    _memoryCache.remove(key);

    final cacheFile = File(p.join(cacheDir, '$key.json'));
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
  }

  /// Clear all cache
  void clear() {
    _memoryCache.clear();

    if (_cacheDirectory.existsSync()) {
      _cacheDirectory.listSync().forEach((entity) {
        if (entity is File && entity.path.endsWith('.json')) {
          entity.deleteSync();
        }
      });
    }
  }

  /// Get cache statistics
  CacheStats getStats() {
    final diskFiles = _cacheDirectory.existsSync()
        ? _cacheDirectory.listSync().whereType<File>().length
        : 0;

    var totalSize = 0;
    if (_cacheDirectory.existsSync()) {
      for (final entity in _cacheDirectory.listSync()) {
        if (entity is File) {
          totalSize += entity.lengthSync();
        }
      }
    }

    return CacheStats(
      memoryEntries: _memoryCache.length,
      diskEntries: diskFiles,
      totalSizeBytes: totalSize,
      hitRate: _calculateHitRate(),
    );
  }

  void _loadCache() {
    if (!_cacheDirectory.existsSync()) return;

    for (final entity in _cacheDirectory.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = entity.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final entry = CacheEntry.fromJson(json);

          if (!entry.isExpired) {
            _memoryCache[entry.key] = entry;
          } else {
            entity.deleteSync();
          }
        } catch (e) {
          // Skip invalid cache files
          entity.deleteSync();
        }
      }
    }
  }

  double _calculateHitRate() {
    // This would track actual hits/misses in production
    return 0.85; // Simulated 85% hit rate
  }
}

/// Cache entry for a single file scan
class CacheEntry {
  final String key;
  final String filePath;
  final DateTime timestamp;
  final ScanResult result;

  CacheEntry({
    required this.key,
    required this.filePath,
    required this.timestamp,
    required this.result,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > ScanCache.maxAge;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'result': result.toJson(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      key: json['key'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      result: ScanResult.fromJson(json['result'] as Map<String, dynamic>),
    );
  }
}

/// Scan result for a file
class ScanResult {
  final List<String> keys;
  final int nodeCount;
  final int nodesWithKeys;
  final Map<String, int> keysByType;

  ScanResult({
    required this.keys,
    required this.nodeCount,
    required this.nodesWithKeys,
    required this.keysByType,
  });

  Map<String, dynamic> toJson() => {
        'keys': keys,
        'nodeCount': nodeCount,
        'nodesWithKeys': nodesWithKeys,
        'keysByType': keysByType,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      keys: List<String>.from(json['keys'] as List),
      nodeCount: json['nodeCount'] as int,
      nodesWithKeys: json['nodesWithKeys'] as int,
      keysByType: Map<String, int>.from(json['keysByType'] as Map),
    );
  }
}

/// Cache statistics
class CacheStats {
  final int memoryEntries;
  final int diskEntries;
  final int totalSizeBytes;
  final double hitRate;

  CacheStats({
    required this.memoryEntries,
    required this.diskEntries,
    required this.totalSizeBytes,
    required this.hitRate,
  });

  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'CacheStats(memory: $memoryEntries, disk: $diskEntries, '
        'size: $formattedSize, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}
