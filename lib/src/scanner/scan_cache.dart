import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Cache system for scan results
class ScanCache {
  final String projectPath;
  final String cacheDir;
  final Duration maxAge;
  final bool enabled;

  late final File _indexFile;
  late final Directory _cacheDirectory;
  final Map<String, CacheEntry> _memoryCache = {};

  ScanCache({
    required this.projectPath,
    String? cacheDir,
    this.maxAge = const Duration(hours: 24),
    this.enabled = true,
  }) : cacheDir =
            cacheDir ?? path.join(projectPath, '.flutter_keycheck', 'cache') {
    _cacheDirectory = Directory(this.cacheDir);
    _indexFile = File(path.join(this.cacheDir, 'cache_index.json'));

    if (enabled) {
      _initializeCache();
    }
  }

  /// Initialize cache directory and load index
  void _initializeCache() {
    if (!_cacheDirectory.existsSync()) {
      _cacheDirectory.createSync(recursive: true);
    }

    if (_indexFile.existsSync()) {
      _loadIndex();
    }
  }

  /// Load cache index from disk
  void _loadIndex() {
    try {
      final content = _indexFile.readAsStringSync();
      final index = jsonDecode(content) as Map<String, dynamic>;

      for (final entry in index.entries) {
        final cacheEntry =
            CacheEntry.fromJson(entry.value as Map<String, dynamic>);

        // Check if entry is still valid
        if (!_isExpired(cacheEntry)) {
          _memoryCache[entry.key] = cacheEntry;
        }
      }
    } catch (e) {
      // Invalid cache index, start fresh
      _memoryCache.clear();
    }
  }

  /// Save cache index to disk
  void _saveIndex() {
    if (!enabled) return;

    final index = <String, dynamic>{};
    for (final entry in _memoryCache.entries) {
      index[entry.key] = entry.value.toJson();
    }

    _indexFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(index),
    );
  }

  /// Get cached file analysis
  FileAnalysisCache? getFileAnalysis(String filePath) {
    if (!enabled) return null;

    final key = _getFileKey(filePath);
    final entry = _memoryCache[key];

    if (entry == null || _isExpired(entry)) {
      return null;
    }

    // Check if file has been modified
    final file = File(filePath);
    if (!file.existsSync()) {
      _memoryCache.remove(key);
      return null;
    }

    final currentHash = _getFileHash(file);
    if (currentHash != entry.fileHash) {
      _memoryCache.remove(key);
      return null;
    }

    // Load cached data
    final cacheFile = File(path.join(cacheDir, entry.cacheFile));
    if (!cacheFile.existsSync()) {
      _memoryCache.remove(key);
      return null;
    }

    try {
      final content = cacheFile.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Update hit count
      entry.hits++;
      entry.lastAccessed = DateTime.now();
      _saveIndex();

      return FileAnalysisCache.fromJson(data);
    } catch (e) {
      _memoryCache.remove(key);
      return null;
    }
  }

  /// Cache file analysis
  void cacheFileAnalysis(String filePath, FileAnalysisCache analysis) {
    if (!enabled) return;

    final key = _getFileKey(filePath);
    final file = File(filePath);

    if (!file.existsSync()) return;

    final fileHash = _getFileHash(file);
    final cacheFileName = '${_sanitizeFileName(filePath)}_$fileHash.json';
    final cacheFile = File(path.join(cacheDir, cacheFileName));

    // Save analysis data
    cacheFile.writeAsStringSync(
      jsonEncode(analysis.toJson()),
    );

    // Update index
    _memoryCache[key] = CacheEntry(
      filePath: filePath,
      fileHash: fileHash,
      cacheFile: cacheFileName,
      created: DateTime.now(),
      lastAccessed: DateTime.now(),
      size: file.lengthSync(),
      hits: 0,
    );

    _saveIndex();
  }

  /// Get cache statistics
  CacheStats getStats() {
    final stats = CacheStats();

    if (!enabled) {
      stats.enabled = false;
      return stats;
    }

    stats.enabled = true;
    stats.entries = _memoryCache.length;

    // Calculate size
    for (final entry in _memoryCache.values) {
      final cacheFile = File(path.join(cacheDir, entry.cacheFile));
      if (cacheFile.existsSync()) {
        stats.totalSize += cacheFile.lengthSync();
      }
      stats.totalHits += entry.hits;
    }

    // Find hot entries
    final sortedByHits = _memoryCache.values.toList()
      ..sort((a, b) => b.hits.compareTo(a.hits));

    stats.hotEntries = sortedByHits
        .take(10)
        .map((e) => HotEntry(
              file: e.filePath,
              hits: e.hits,
              lastAccessed: e.lastAccessed,
            ))
        .toList();

    // Calculate hit rate
    if (stats.totalHits > 0 || _memoryCache.isNotEmpty) {
      stats.hitRate =
          stats.totalHits / (stats.totalHits + _memoryCache.length).toDouble();
    }

    return stats;
  }

  /// Clear expired entries
  void cleanExpired() {
    if (!enabled) return;

    final expired = <String>[];

    for (final entry in _memoryCache.entries) {
      if (_isExpired(entry.value)) {
        expired.add(entry.key);

        // Delete cache file
        final cacheFile = File(path.join(cacheDir, entry.value.cacheFile));
        if (cacheFile.existsSync()) {
          cacheFile.deleteSync();
        }
      }
    }

    for (final key in expired) {
      _memoryCache.remove(key);
    }

    if (expired.isNotEmpty) {
      _saveIndex();
    }
  }

  /// Clear all cache
  void clear() {
    if (!enabled) return;

    _memoryCache.clear();

    // Delete all cache files
    if (_cacheDirectory.existsSync()) {
      _cacheDirectory.deleteSync(recursive: true);
      _cacheDirectory.createSync(recursive: true);
    }

    _saveIndex();
  }

  /// Warm cache by pre-scanning files
  Future<void> warmCache(List<String> files) async {
    if (!enabled) return;

    for (final filePath in files) {
      // Check if already cached
      if (getFileAnalysis(filePath) != null) {
        continue;
      }

      // TODO: Trigger background scan of file
      // This would require integration with AST scanner
    }
  }

  /// Get cache key for file
  String _getFileKey(String filePath) {
    return path.relative(filePath, from: projectPath);
  }

  /// Get file content hash
  String _getFileHash(File file) {
    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Sanitize file name for cache storage
  String _sanitizeFileName(String filePath) {
    return path
        .relative(filePath, from: projectPath)
        .replaceAll(path.separator, '_')
        .replaceAll('.', '_');
  }

  /// Check if cache entry is expired
  bool _isExpired(CacheEntry entry) {
    final age = DateTime.now().difference(entry.created);
    return age > maxAge;
  }
}

/// Cache entry metadata
class CacheEntry {
  final String filePath;
  final String fileHash;
  final String cacheFile;
  final DateTime created;
  DateTime lastAccessed;
  final int size;
  int hits;

  CacheEntry({
    required this.filePath,
    required this.fileHash,
    required this.cacheFile,
    required this.created,
    required this.lastAccessed,
    required this.size,
    this.hits = 0,
  });

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      filePath: json['file_path'] as String,
      fileHash: json['file_hash'] as String,
      cacheFile: json['cache_file'] as String,
      created: DateTime.parse(json['created'] as String),
      lastAccessed: DateTime.parse(json['last_accessed'] as String),
      size: json['size'] as int,
      hits: json['hits'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'file_hash': fileHash,
        'cache_file': cacheFile,
        'created': created.toIso8601String(),
        'last_accessed': lastAccessed.toIso8601String(),
        'size': size,
        'hits': hits,
      };
}

/// Cached file analysis data
class FileAnalysisCache {
  final String path;
  final List<String> keys;
  final List<String> widgets;
  final Map<String, int> detectorHits;
  final int nodeCount;
  final int widgetCount;
  final int widgetsWithKeys;

  FileAnalysisCache({
    required this.path,
    required this.keys,
    required this.widgets,
    required this.detectorHits,
    required this.nodeCount,
    required this.widgetCount,
    required this.widgetsWithKeys,
  });

  factory FileAnalysisCache.fromJson(Map<String, dynamic> json) {
    return FileAnalysisCache(
      path: json['path'] as String,
      keys: (json['keys'] as List).cast<String>(),
      widgets: (json['widgets'] as List).cast<String>(),
      detectorHits: (json['detector_hits'] as Map).cast<String, int>(),
      nodeCount: json['node_count'] as int,
      widgetCount: json['widget_count'] as int,
      widgetsWithKeys: json['widgets_with_keys'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'keys': keys,
        'widgets': widgets,
        'detector_hits': detectorHits,
        'node_count': nodeCount,
        'widget_count': widgetCount,
        'widgets_with_keys': widgetsWithKeys,
      };
}

/// Cache statistics
class CacheStats {
  bool enabled = true;
  int entries = 0;
  int totalSize = 0;
  int totalHits = 0;
  double hitRate = 0;
  List<HotEntry> hotEntries = [];

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'entries': entries,
        'total_size': totalSize,
        'total_size_mb': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'total_hits': totalHits,
        'hit_rate': hitRate,
        'hot_entries': hotEntries.map((e) => e.toJson()).toList(),
      };
}

/// Hot cache entry
class HotEntry {
  final String file;
  final int hits;
  final DateTime lastAccessed;

  HotEntry({
    required this.file,
    required this.hits,
    required this.lastAccessed,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'hits': hits,
        'last_accessed': lastAccessed.toIso8601String(),
      };
}
