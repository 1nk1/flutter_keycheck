/// Intelligent caching system for Flutter KeyCheck scan results
library;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Cached scan result data
class CachedScanResult {
  final Set<String> foundKeys;
  final Map<String, int> keyUsageCounts;
  final Map<String, List<CachedKeyLocation>> keyLocations;
  final DateTime timestamp;
  final String fileHash;
  final Duration scanDuration;
  final Map<String, dynamic> metadata;

  const CachedScanResult({
    required this.foundKeys,
    required this.keyUsageCounts,
    required this.keyLocations,
    required this.timestamp,
    required this.fileHash,
    required this.scanDuration,
    required this.metadata,
  });

  factory CachedScanResult.fromJson(Map<String, dynamic> json) {
    return CachedScanResult(
      foundKeys: Set<String>.from(json['foundKeys'] ?? []),
      keyUsageCounts: Map<String, int>.from(json['keyUsageCounts'] ?? {}),
      keyLocations: (json['keyLocations'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as List)
              .map((loc) => CachedKeyLocation.fromJson(loc))
              .toList())),
      timestamp: DateTime.parse(json['timestamp']),
      fileHash: json['fileHash'] ?? '',
      scanDuration: Duration(milliseconds: json['scanDurationMs'] ?? 0),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'foundKeys': foundKeys.toList(),
    'keyUsageCounts': keyUsageCounts,
    'keyLocations': keyLocations.map((k, v) => 
        MapEntry(k, v.map((loc) => loc.toJson()).toList())),
    'timestamp': timestamp.toIso8601String(),
    'fileHash': fileHash,
    'scanDurationMs': scanDuration.inMilliseconds,
    'metadata': metadata,
  };

  /// Check if cache entry is still valid
  bool isValid(String currentFileHash, Duration maxAge) {
    final age = DateTime.now().difference(timestamp);
    return fileHash == currentFileHash && age < maxAge;
  }
}

/// Cached key location information
class CachedKeyLocation {
  final String filePath;
  final int line;
  final int column;
  final String context;

  const CachedKeyLocation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.context,
  });

  factory CachedKeyLocation.fromJson(Map<String, dynamic> json) {
    return CachedKeyLocation(
      filePath: json['filePath'] ?? '',
      line: json['line'] ?? 0,
      column: json['column'] ?? 0,
      context: json['context'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'line': line,
    'column': column,
    'context': context,
  };
}

/// Cache statistics and metadata
class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  final double hitRate;
  final double sizeMB;
  final DateTime lastCleanup;
  final Map<String, int> typeDistribution;

  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
    required this.hitRate,
    required this.sizeMB,
    required this.lastCleanup,
    required this.typeDistribution,
  });

  Map<String, dynamic> toJson() => {
    'totalEntries': totalEntries,
    'validEntries': validEntries,
    'expiredEntries': expiredEntries,
    'hitRate': hitRate,
    'sizeMB': sizeMB,
    'lastCleanup': lastCleanup.toIso8601String(),
    'typeDistribution': typeDistribution,
  };
}

/// Configuration for cache behavior
class CacheConfig {
  final Duration maxAge;
  final int maxEntries;
  final double maxSizeMB;
  final bool enableCompression;
  final bool enableValidation;
  final Duration cleanupInterval;
  final bool persistAcrossSessions;

  const CacheConfig({
    this.maxAge = const Duration(hours: 24),
    this.maxEntries = 1000,
    this.maxSizeMB = 100.0,
    this.enableCompression = true,
    this.enableValidation = true,
    this.cleanupInterval = const Duration(hours: 6),
    this.persistAcrossSessions = true,
  });
}

/// Intelligent cache manager for scan results
class CacheManager {
  final String cacheDir;
  final CacheConfig config;
  final bool verbose;

  late final Directory _cacheDirectory;
  late final File _indexFile;
  late final File _statsFile;
  
  Map<String, CachedScanResult> _memoryCache = {};
  Map<String, String> _fileIndex = {}; // filePath -> cacheKey mapping
  DateTime _lastCleanup = DateTime.now();
  int _cacheHits = 0;
  int _cacheMisses = 0;

  CacheManager({
    required this.cacheDir,
    this.config = const CacheConfig(),
    this.verbose = false,
  });

  /// Initialize cache manager
  Future<void> initialize() async {
    _cacheDirectory = Directory(cacheDir);
    _indexFile = File(path.join(cacheDir, 'cache_index.json'));
    _statsFile = File(path.join(cacheDir, 'cache_stats.json'));

    if (!_cacheDirectory.existsSync()) {
      _cacheDirectory.createSync(recursive: true);
      if (verbose) {
        print('📁 Created cache directory: $cacheDir');
      }
    }

    await _loadIndex();
    await _loadMemoryCache();
    
    if (verbose) {
      print('🗂️ Cache initialized with ${_memoryCache.length} entries');
    }
  }

  /// Get cached scan result for a file
  Future<CachedScanResult?> get(String filePath) async {
    final fileHash = await _calculateFileHash(filePath);
    final cacheKey = _generateCacheKey(filePath, fileHash);

    // Check memory cache first
    final memoryResult = _memoryCache[cacheKey];
    if (memoryResult != null && memoryResult.isValid(fileHash, config.maxAge)) {
      _cacheHits++;
      if (verbose) {
        print('🎯 Cache hit (memory): $filePath');
      }
      return memoryResult;
    }

    // Check disk cache
    final diskResult = await _loadFromDisk(cacheKey);
    if (diskResult != null && diskResult.isValid(fileHash, config.maxAge)) {
      _memoryCache[cacheKey] = diskResult; // Load into memory
      _cacheHits++;
      if (verbose) {
        print('🎯 Cache hit (disk): $filePath');
      }
      return diskResult;
    }

    _cacheMisses++;
    if (verbose) {
      print('❌ Cache miss: $filePath');
    }
    return null;
  }

  /// Store scan result in cache
  Future<void> put(
    String filePath,
    Set<String> foundKeys,
    Map<String, int> keyUsageCounts,
    Map<String, List<CachedKeyLocation>> keyLocations,
    Duration scanDuration, {
    Map<String, dynamic>? metadata,
  }) async {
    final fileHash = await _calculateFileHash(filePath);
    final cacheKey = _generateCacheKey(filePath, fileHash);

    final result = CachedScanResult(
      foundKeys: foundKeys,
      keyUsageCounts: keyUsageCounts,
      keyLocations: keyLocations,
      timestamp: DateTime.now(),
      fileHash: fileHash,
      scanDuration: scanDuration,
      metadata: metadata ?? {},
    );

    // Store in memory cache
    _memoryCache[cacheKey] = result;
    _fileIndex[filePath] = cacheKey;

    // Store to disk if persistence is enabled
    if (config.persistAcrossSessions) {
      await _saveToDisk(cacheKey, result);
      await _saveIndex();
    }

    if (verbose) {
      print('💾 Cached scan result: $filePath');
    }

    // Cleanup if needed
    await _cleanupIfNeeded();
  }

  /// Check if file is cached and valid
  Future<bool> isCached(String filePath) async {
    final fileHash = await _calculateFileHash(filePath);
    final cacheKey = _generateCacheKey(filePath, fileHash);
    
    final result = _memoryCache[cacheKey] ?? await _loadFromDisk(cacheKey);
    return result?.isValid(fileHash, config.maxAge) ?? false;
  }

  /// Invalidate cache for specific file
  Future<void> invalidate(String filePath) async {
    final oldCacheKey = _fileIndex[filePath];
    if (oldCacheKey != null) {
      _memoryCache.remove(oldCacheKey);
      _fileIndex.remove(filePath);
      await _removeFromDisk(oldCacheKey);
      
      if (verbose) {
        print('🗑️  Invalidated cache: $filePath');
      }
    }

    // Also remove any cache entries with different hashes
    final currentHash = await _calculateFileHash(filePath);
    final keysToRemove = <String>[];
    
    for (final entry in _memoryCache.entries) {
      if (entry.value.metadata['filePath'] == filePath && 
          entry.value.fileHash != currentHash) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      await _removeFromDisk(key);
    }
  }

  /// Clear entire cache
  Future<void> clear() async {
    _memoryCache.clear();
    _fileIndex.clear();
    
    if (_cacheDirectory.existsSync()) {
      await _cacheDirectory.delete(recursive: true);
      await _cacheDirectory.create(recursive: true);
    }
    
    if (verbose) {
      print('🧹 Cache cleared');
    }
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    final now = DateTime.now();
    final validEntries = <String>[];
    final expiredEntries = <String>[];
    final typeDistribution = <String, int>{};

    for (final entry in _memoryCache.entries) {
      final result = entry.value;
      final age = now.difference(result.timestamp);
      
      if (age < config.maxAge) {
        validEntries.add(entry.key);
      } else {
        expiredEntries.add(entry.key);
      }
      
      // Track by file type
      final filePath = result.metadata['filePath'] as String? ?? '';
      final extension = path.extension(filePath);
      typeDistribution[extension] = (typeDistribution[extension] ?? 0) + 1;
    }

    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? (_cacheHits / totalRequests) : 0.0;
    
    final sizeMB = await _calculateCacheSize();

    return CacheStats(
      totalEntries: _memoryCache.length,
      validEntries: validEntries.length,
      expiredEntries: expiredEntries.length,
      hitRate: hitRate,
      sizeMB: sizeMB,
      lastCleanup: _lastCleanup,
      typeDistribution: typeDistribution,
    );
  }

  /// Cleanup expired entries
  Future<void> cleanup() async {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _memoryCache.entries) {
      final age = now.difference(entry.value.timestamp);
      if (age > config.maxAge) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      await _removeFromDisk(key);
    }

    // Remove orphaned file index entries
    final validFilePaths = <String>{};
    for (final result in _memoryCache.values) {
      final filePath = result.metadata['filePath'] as String?;
      if (filePath != null) {
        validFilePaths.add(filePath);
      }
    }

    _fileIndex.removeWhere((filePath, _) => !validFilePaths.contains(filePath));

    _lastCleanup = now;
    await _saveIndex();

    if (verbose && keysToRemove.isNotEmpty) {
      print('🧹 Cleaned up ${keysToRemove.length} expired cache entries');
    }
  }

  /// Calculate file hash for cache validation
  Future<String> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '';
      
      final stat = file.statSync();
      final content = '${stat.modified.millisecondsSinceEpoch}_${stat.size}';
      return sha256.convert(utf8.encode(content)).toString();
    } catch (e) {
      if (verbose) {
        print('⚠️ Error calculating hash for $filePath: $e');
      }
      return '';
    }
  }

  /// Generate cache key from file path and hash
  String _generateCacheKey(String filePath, String fileHash) {
    final pathHash = sha256.convert(utf8.encode(filePath)).toString();
    return '${pathHash}_$fileHash';
  }

  /// Load cache index from disk
  Future<void> _loadIndex() async {
    if (!_indexFile.existsSync()) return;

    try {
      final content = _indexFile.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _fileIndex = Map<String, String>.from(data['fileIndex'] ?? {});
      
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      _cacheHits = stats['cacheHits'] ?? 0;
      _cacheMisses = stats['cacheMisses'] ?? 0;
      
      if (stats['lastCleanup'] != null) {
        _lastCleanup = DateTime.parse(stats['lastCleanup']);
      }
    } catch (e) {
      if (verbose) {
        print('⚠️ Error loading cache index: $e');
      }
      _fileIndex.clear();
    }
  }

  /// Save cache index to disk
  Future<void> _saveIndex() async {
    if (!config.persistAcrossSessions) return;

    try {
      final data = {
        'fileIndex': _fileIndex,
        'stats': {
          'cacheHits': _cacheHits,
          'cacheMisses': _cacheMisses,
          'lastCleanup': _lastCleanup.toIso8601String(),
        },
      };
      
      _indexFile.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      if (verbose) {
        print('⚠️ Error saving cache index: $e');
      }
    }
  }

  /// Load memory cache from disk
  Future<void> _loadMemoryCache() async {
    if (!config.persistAcrossSessions) return;

    final cacheFiles = _cacheDirectory.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.cache'))
        .toList();

    for (final file in cacheFiles) {
      try {
        final cacheKey = path.basenameWithoutExtension(file.path);
        final result = await _loadFromDisk(cacheKey);
        if (result != null) {
          _memoryCache[cacheKey] = result;
        }
      } catch (e) {
        if (verbose) {
          print('⚠️ Error loading cache file ${file.path}: $e');
        }
      }
    }
  }

  /// Load cached result from disk
  Future<CachedScanResult?> _loadFromDisk(String cacheKey) async {
    final file = File(path.join(cacheDir, '$cacheKey.cache'));
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return CachedScanResult.fromJson(data);
    } catch (e) {
      if (verbose) {
        print('⚠️ Error loading cache from disk: $e');
      }
      return null;
    }
  }

  /// Save cached result to disk
  Future<void> _saveToDisk(String cacheKey, CachedScanResult result) async {
    final file = File(path.join(cacheDir, '$cacheKey.cache'));
    
    try {
      final data = result.toJson();
      file.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      if (verbose) {
        print('⚠️ Error saving cache to disk: $e');
      }
    }
  }

  /// Remove cached result from disk
  Future<void> _removeFromDisk(String cacheKey) async {
    final file = File(path.join(cacheDir, '$cacheKey.cache'));
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (e) {
        if (verbose) {
          print('⚠️ Error removing cache file: $e');
        }
      }
    }
  }

  /// Calculate total cache size in MB
  Future<double> _calculateCacheSize() async {
    if (!_cacheDirectory.existsSync()) return 0.0;

    int totalBytes = 0;
    try {
      final files = _cacheDirectory.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        totalBytes += file.lengthSync();
      }
    } catch (e) {
      if (verbose) {
        print('⚠️ Error calculating cache size: $e');
      }
    }

    return totalBytes / (1024 * 1024); // Convert to MB
  }

  /// Check if cleanup is needed and perform it
  Future<void> _cleanupIfNeeded() async {
    final now = DateTime.now();
    final timeSinceCleanup = now.difference(_lastCleanup);

    final needsCleanup = timeSinceCleanup > config.cleanupInterval ||
        _memoryCache.length > config.maxEntries ||
        await _calculateCacheSize() > config.maxSizeMB;

    if (needsCleanup) {
      await cleanup();
    }
  }
}