/// Statistics calculation engine for Flutter KeyCheck
/// 
/// Provides comprehensive statistical analysis including file coverage,
/// key distribution, performance trends, and efficiency scoring.
library;

import 'dart:math' as math;

/// Comprehensive statistics for key analysis
class KeyStatistics {
  final Map<String, dynamic> coverage;
  final Map<String, dynamic> distribution;
  final Map<String, dynamic> usage;
  final Map<String, dynamic> performance;
  final Map<String, dynamic> quality;
  final Map<String, dynamic> trends;

  const KeyStatistics({
    required this.coverage,
    required this.distribution,
    required this.usage,
    required this.performance,
    required this.quality,
    required this.trends,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'coverage': coverage,
        'distribution': distribution,
        'usage': usage,
        'performance': performance,
        'quality': quality,
        'trends': trends,
      };

  /// Get summary metrics for dashboards
  Map<String, dynamic> get summary => {
        'coveragePercentage': coverage['percentage'],
        'totalKeys': distribution['totalKeys'],
        'filesScanned': coverage['filesScanned'],
        'avgKeysPerFile': distribution['avgKeysPerFile'],
        'performanceScore': performance['score'],
        'qualityScore': quality['score'],
      };
}

/// File coverage analysis result
class FileCoverageResult {
  final String filePath;
  final int keyCount;
  final List<String> keys;
  final double coverageScore;
  final bool isTestFile;
  final bool hasKeyConstants;

  const FileCoverageResult({
    required this.filePath,
    required this.keyCount,
    required this.keys,
    required this.coverageScore,
    required this.isTestFile,
    required this.hasKeyConstants,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'keyCount': keyCount,
        'keys': keys,
        'coverageScore': coverageScore,
        'isTestFile': isTestFile,
        'hasKeyConstants': hasKeyConstants,
      };
}

/// Key distribution analysis
class KeyDistribution {
  final Map<String, int> byFile;
  final Map<String, int> byCategory;
  final Map<String, double> categoryPercentages;
  final List<String> hotspots;
  final List<String> coldSpots;

  const KeyDistribution({
    required this.byFile,
    required this.byCategory,
    required this.categoryPercentages,
    required this.hotspots,
    required this.coldSpots,
  });

  Map<String, dynamic> toJson() => {
        'byFile': byFile,
        'byCategory': byCategory,
        'categoryPercentages': categoryPercentages,
        'hotspots': hotspots,
        'coldSpots': coldSpots,
      };
}

/// Performance metrics and trends
class PerformanceMetrics {
  final Duration scanTime;
  final int keysPerSecond;
  final double memoryUsage;
  final Map<String, int> operationCounts;
  final List<String> bottlenecks;

  const PerformanceMetrics({
    required this.scanTime,
    required this.keysPerSecond,
    required this.memoryUsage,
    required this.operationCounts,
    required this.bottlenecks,
  });

  Map<String, dynamic> toJson() => {
        'scanTimeMs': scanTime.inMilliseconds,
        'keysPerSecond': keysPerSecond,
        'memoryUsageMB': memoryUsage,
        'operationCounts': operationCounts,
        'bottlenecks': bottlenecks,
      };
}

/// Main statistics calculation engine
class StatsCalculator {
  /// Calculate comprehensive statistics
  static KeyStatistics calculateStatistics({
    required Set<String> expectedKeys,
    required Set<String> foundKeys,
    required Set<String> missingKeys,
    required Set<String> extraKeys,
    Map<String, int>? keyUsageCounts,
    Map<String, List<dynamic>>? keyLocations,
    List<String>? scannedFiles,
    Duration? scanDuration,
    Map<String, dynamic>? additionalMetrics,
  }) {
    // Calculate coverage statistics
    final coverage = _calculateCoverageStats(
      expectedKeys, foundKeys, missingKeys, scannedFiles, keyLocations);

    // Calculate distribution statistics  
    final distribution = _calculateDistributionStats(
      foundKeys, extraKeys, keyLocations, scannedFiles);

    // Calculate usage statistics
    final usage = _calculateUsageStats(
      foundKeys, keyUsageCounts, keyLocations);

    // Calculate performance statistics
    final performance = _calculatePerformanceStats(
      foundKeys, scannedFiles, scanDuration, additionalMetrics);

    // Calculate quality statistics
    final quality = _calculateQualityStats(
      expectedKeys, foundKeys, missingKeys, extraKeys, keyUsageCounts);

    // Calculate trend analysis
    final trends = _calculateTrendStats(
      expectedKeys, foundKeys, keyUsageCounts, additionalMetrics);

    return KeyStatistics(
      coverage: coverage,
      distribution: distribution,
      usage: usage,
      performance: performance,
      quality: quality,
      trends: trends,
    );
  }

  /// Analyze file coverage in detail
  static List<FileCoverageResult> analyzeFileCoverage({
    required Map<String, List<dynamic>>? keyLocations,
    required List<String>? scannedFiles,
    required Set<String> foundKeys,
  }) {
    if (keyLocations == null || scannedFiles == null) {
      return [];
    }

    final fileResults = <FileCoverageResult>[];
    final keysByFile = <String, List<String>>{};

    // Group keys by file
    for (final entry in keyLocations.entries) {
      final key = entry.key;
      final locations = entry.value;

      for (final location in locations) {
        if (location is Map && location['file'] != null) {
          final file = location['file'] as String;
          keysByFile.putIfAbsent(file, () => []).add(key);
        }
      }
    }

    // Analyze each file
    for (final file in scannedFiles) {
      final keysInFile = keysByFile[file] ?? [];
      final coverage = _calculateFileCoverageScore(keysInFile, foundKeys);
      
      fileResults.add(FileCoverageResult(
        filePath: file,
        keyCount: keysInFile.length,
        keys: keysInFile,
        coverageScore: coverage,
        isTestFile: _isTestFile(file),
        hasKeyConstants: _hasKeyConstants(file, keysInFile),
      ));
    }

    // Sort by coverage score (descending)
    fileResults.sort((a, b) => b.coverageScore.compareTo(a.coverageScore));
    
    return fileResults;
  }

  /// Analyze key distribution patterns
  static KeyDistribution analyzeKeyDistribution({
    required Set<String> foundKeys,
    required Map<String, List<dynamic>>? keyLocations,
  }) {
    final byFile = <String, int>{};
    final byCategory = <String, int>{};

    if (keyLocations != null) {
      // Count keys by file
      for (final locations in keyLocations.values) {
        for (final location in locations) {
          if (location is Map && location['file'] != null) {
            final file = location['file'] as String;
            byFile[file] = (byFile[file] ?? 0) + 1;
          }
        }
      }
    }

    // Categorize keys by type/pattern
    for (final key in foundKeys) {
      final category = _categorizeKey(key);
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    // Calculate percentages
    final total = foundKeys.length;
    final categoryPercentages = byCategory.map((category, count) =>
        MapEntry(category, total > 0 ? (count / total) * 100 : 0.0));

    // Identify hotspots and cold spots
    final sortedFiles = byFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final hotspots = sortedFiles.take(5).map((e) => e.key).toList();
    final coldSpots = sortedFiles.reversed.take(5).map((e) => e.key).toList();

    return KeyDistribution(
      byFile: byFile,
      byCategory: byCategory,
      categoryPercentages: categoryPercentages,
      hotspots: hotspots,
      coldSpots: coldSpots,
    );
  }

  /// Calculate coverage statistics
  static Map<String, dynamic> _calculateCoverageStats(
      Set<String> expectedKeys, Set<String> foundKeys, Set<String> missingKeys,
      List<String>? scannedFiles, Map<String, List<dynamic>>? keyLocations) {
    
    final totalExpected = expectedKeys.length;
    final totalFound = foundKeys.length;
    final totalMissing = missingKeys.length;
    
    final percentage = totalExpected > 0 ? 
        ((totalExpected - totalMissing) / totalExpected) * 100 : 100.0;
    
    // Calculate file coverage
    int filesWithKeys = 0;
    if (keyLocations != null && scannedFiles != null) {
      final filesWithKeysSet = keyLocations.values
          .expand((locations) => locations)
          .where((loc) => loc is Map && loc['file'] != null)
          .map((loc) => loc['file'] as String)
          .toSet();
      filesWithKeys = filesWithKeysSet.length;
    }

    return {
      'percentage': percentage,
      'expectedKeys': totalExpected,
      'foundKeys': totalFound,
      'missingKeys': totalMissing,
      'filesScanned': scannedFiles?.length ?? 0,
      'filesWithKeys': filesWithKeys,
      'fileCoverage': scannedFiles != null && scannedFiles.isNotEmpty ?
          (filesWithKeys / scannedFiles.length) * 100 : 0.0,
    };
  }

  /// Calculate distribution statistics
  static Map<String, dynamic> _calculateDistributionStats(
      Set<String> foundKeys, Set<String> extraKeys,
      Map<String, List<dynamic>>? keyLocations, List<String>? scannedFiles) {
    
    final totalKeys = foundKeys.length + extraKeys.length;
    
    // Calculate keys per file
    final keysByFile = <String, int>{};
    if (keyLocations != null) {
      for (final locations in keyLocations.values) {
        for (final location in locations) {
          if (location is Map && location['file'] != null) {
            final file = location['file'] as String;
            keysByFile[file] = (keysByFile[file] ?? 0) + 1;
          }
        }
      }
    }

    final avgKeysPerFile = keysByFile.isNotEmpty ?
        keysByFile.values.reduce((a, b) => a + b) / keysByFile.length : 0.0;
    
    final maxKeysPerFile = keysByFile.isNotEmpty ?
        keysByFile.values.reduce(math.max) : 0;
    
    final minKeysPerFile = keysByFile.isNotEmpty ?
        keysByFile.values.reduce(math.min) : 0;

    // Calculate distribution variance
    final variance = keysByFile.isNotEmpty ?
        _calculateVariance(keysByFile.values.toList()) : 0.0;

    return {
      'totalKeys': totalKeys,
      'avgKeysPerFile': avgKeysPerFile,
      'maxKeysPerFile': maxKeysPerFile,
      'minKeysPerFile': minKeysPerFile,
      'distributionVariance': variance,
      'extraKeysRatio': totalKeys > 0 ? (extraKeys.length / totalKeys) * 100 : 0.0,
    };
  }

  /// Calculate usage statistics
  static Map<String, dynamic> _calculateUsageStats(
      Set<String> foundKeys, Map<String, int>? keyUsageCounts,
      Map<String, List<dynamic>>? keyLocations) {
    
    if (keyUsageCounts == null || keyUsageCounts.isEmpty) {
      return {
        'averageUsage': 0.0,
        'maxUsage': 0,
        'minUsage': 0,
        'duplicateKeys': 0,
        'uniqueKeys': foundKeys.length,
        'usageVariance': 0.0,
      };
    }

    final usages = keyUsageCounts.values.toList();
    final averageUsage = usages.reduce((a, b) => a + b) / usages.length;
    final maxUsage = usages.reduce(math.max);
    final minUsage = usages.reduce(math.min);
    final duplicateKeys = usages.where((usage) => usage > 1).length;
    final uniqueKeys = usages.where((usage) => usage == 1).length;
    final usageVariance = _calculateVariance(usages);

    return {
      'averageUsage': averageUsage,
      'maxUsage': maxUsage,
      'minUsage': minUsage,
      'duplicateKeys': duplicateKeys,
      'uniqueKeys': uniqueKeys,
      'usageVariance': usageVariance,
      'efficiencyScore': _calculateUsageEfficiency(usages),
    };
  }

  /// Calculate performance statistics
  static Map<String, dynamic> _calculatePerformanceStats(
      Set<String> foundKeys, List<String>? scannedFiles, Duration? scanDuration,
      Map<String, dynamic>? additionalMetrics) {
    
    final keysPerSecond = scanDuration != null && scanDuration.inMilliseconds > 0 ?
        (foundKeys.length * 1000) / scanDuration.inMilliseconds : 0.0;
    
    final filesPerSecond = scanDuration != null && scanDuration.inMilliseconds > 0 && scannedFiles != null ?
        (scannedFiles.length * 1000) / scanDuration.inMilliseconds : 0.0;

    // Performance score based on scanning efficiency
    double performanceScore = 70.0; // Base score
    
    if (keysPerSecond > 1000) performanceScore += 20.0;
    else if (keysPerSecond > 500) performanceScore += 15.0;
    else if (keysPerSecond > 100) performanceScore += 10.0;
    else if (keysPerSecond > 50) performanceScore += 5.0;
    
    if (filesPerSecond > 10) performanceScore += 10.0;
    else if (filesPerSecond > 5) performanceScore += 5.0;

    return {
      'scanTimeMs': scanDuration?.inMilliseconds ?? 0,
      'keysPerSecond': keysPerSecond,
      'filesPerSecond': filesPerSecond,
      'score': math.min(performanceScore, 100.0),
      'memoryEstimateMB': _estimateMemoryUsage(foundKeys, scannedFiles),
    };
  }

  /// Calculate quality statistics
  static Map<String, dynamic> _calculateQualityStats(
      Set<String> expectedKeys, Set<String> foundKeys, Set<String> missingKeys,
      Set<String> extraKeys, Map<String, int>? keyUsageCounts) {
    
    // Base quality score
    double qualityScore = 50.0;
    
    // Coverage component (40%)
    final coverage = expectedKeys.isEmpty ? 100.0 :
        ((expectedKeys.length - missingKeys.length) / expectedKeys.length) * 100;
    qualityScore += (coverage * 0.4);
    
    // Consistency component (30%)
    final consistencyScore = _calculateConsistencyScore(foundKeys, keyUsageCounts);
    qualityScore += (consistencyScore * 0.3);
    
    // Organization component (30%)
    final organizationScore = _calculateOrganizationScore(foundKeys, extraKeys);
    qualityScore += (organizationScore * 0.3);

    return {
      'score': math.min(qualityScore, 100.0),
      'coverage': coverage,
      'consistency': consistencyScore,
      'organization': organizationScore,
      'reliability': _calculateReliabilityScore(expectedKeys, foundKeys, missingKeys),
    };
  }

  /// Calculate trend statistics
  static Map<String, dynamic> _calculateTrendStats(
      Set<String> expectedKeys, Set<String> foundKeys,
      Map<String, int>? keyUsageCounts, Map<String, dynamic>? additionalMetrics) {
    
    // Placeholder for trend analysis - would need historical data
    return {
      'growthRate': 0.0,
      'improvementTrend': 'stable',
      'keyTurnover': 0.0,
      'stabilityScore': 85.0,
      'predictedCoverage': expectedKeys.isEmpty ? 100.0 :
          ((expectedKeys.length - (foundKeys.length - expectedKeys.intersection(foundKeys).length)) / expectedKeys.length) * 100,
    };
  }

  /// Calculate file coverage score for individual file
  static double _calculateFileCoverageScore(List<String> keysInFile, Set<String> allFoundKeys) {
    if (keysInFile.isEmpty) return 0.0;
    if (allFoundKeys.isEmpty) return 0.0;
    
    final validKeys = keysInFile.where((key) => allFoundKeys.contains(key)).length;
    return (validKeys / keysInFile.length) * 100;
  }

  /// Check if file is a test file
  static bool _isTestFile(String filePath) {
    return filePath.contains('/test/') || 
           filePath.contains('_test.dart') ||
           filePath.contains('/integration_test/');
  }

  /// Check if file uses KeyConstants pattern
  static bool _hasKeyConstants(String filePath, List<String> keys) {
    return keys.any((key) => key.contains('KeyConstants')) ||
           filePath.contains('key_constants.dart') ||
           filePath.contains('keys.dart');
  }

  /// Categorize key by naming pattern
  static String _categorizeKey(String key) {
    if (key.toLowerCase().contains('button')) return 'Buttons';
    if (key.toLowerCase().contains('field') || key.toLowerCase().contains('input')) return 'Input Fields';
    if (key.toLowerCase().contains('text') || key.toLowerCase().contains('label')) return 'Text Elements';
    if (key.toLowerCase().contains('screen') || key.toLowerCase().contains('page')) return 'Screens';
    if (key.toLowerCase().contains('dialog') || key.toLowerCase().contains('modal')) return 'Dialogs';
    if (key.toLowerCase().contains('menu') || key.toLowerCase().contains('nav')) return 'Navigation';
    if (key.toLowerCase().contains('icon')) return 'Icons';
    if (key.toLowerCase().contains('form')) return 'Forms';
    if (key.toLowerCase().contains('list') || key.toLowerCase().contains('item')) return 'Lists';
    return 'Other';
  }

  /// Calculate variance for a list of numbers
  static double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => math.pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate usage efficiency score
  static double _calculateUsageEfficiency(List<int> usages) {
    if (usages.isEmpty) return 0.0;
    
    final singleUse = usages.where((u) => u == 1).length;
    final multiUse = usages.where((u) => u > 1).length;
    final total = usages.length;
    
    // Ideal scenario: most keys used once (clean automation)
    final efficiency = total > 0 ? (singleUse / total) * 100 : 0.0;
    
    // Penalize excessive duplication
    if (multiUse > total * 0.3) return efficiency * 0.7;
    if (multiUse > total * 0.2) return efficiency * 0.85;
    
    return efficiency;
  }

  /// Calculate consistency score based on naming patterns
  static double _calculateConsistencyScore(Set<String> foundKeys, Map<String, int>? keyUsageCounts) {
    if (foundKeys.isEmpty) return 0.0;
    
    double score = 50.0; // Base score
    
    // Check naming pattern consistency
    final camelCase = foundKeys.where((k) => k.contains(RegExp(r'[a-z][A-Z]'))).length;
    final snakeCase = foundKeys.where((k) => k.contains('_')).length;
    final total = foundKeys.length;
    
    final dominantPattern = math.max(camelCase, snakeCase);
    final consistency = dominantPattern / total;
    
    score += consistency * 30.0; // Up to 30 points for consistency
    
    // Check usage pattern consistency
    if (keyUsageCounts != null) {
      final duplicates = keyUsageCounts.values.where((v) => v > 1).length;
      final duplicateRatio = duplicates / keyUsageCounts.length;
      
      if (duplicateRatio < 0.1) score += 20.0;
      else if (duplicateRatio < 0.2) score += 10.0;
      else score += 5.0;
    }
    
    return math.min(score, 100.0);
  }

  /// Calculate organization score
  static double _calculateOrganizationScore(Set<String> foundKeys, Set<String> extraKeys) {
    if (foundKeys.isEmpty) return 0.0;
    
    double score = 60.0; // Base score
    
    // Penalize extra keys (noise)
    final total = foundKeys.length + extraKeys.length;
    if (total > 0) {
      final extraRatio = extraKeys.length / total;
      if (extraRatio < 0.05) score += 20.0;
      else if (extraRatio < 0.1) score += 15.0;
      else if (extraRatio < 0.2) score += 10.0;
      else score -= 10.0;
    }
    
    // Check for semantic organization
    final categories = foundKeys.map(_categorizeKey).toSet();
    if (categories.length > 3) score += 20.0; // Good categorization
    else if (categories.length > 1) score += 10.0;
    
    return math.min(score, 100.0);
  }

  /// Calculate reliability score
  static double _calculateReliabilityScore(
      Set<String> expectedKeys, Set<String> foundKeys, Set<String> missingKeys) {
    
    if (expectedKeys.isEmpty) return 100.0;
    
    final coverage = ((expectedKeys.length - missingKeys.length) / expectedKeys.length) * 100;
    
    // High reliability requires high coverage
    if (coverage >= 95.0) return 95.0;
    if (coverage >= 90.0) return 85.0;
    if (coverage >= 80.0) return 75.0;
    if (coverage >= 70.0) return 65.0;
    
    return coverage * 0.6; // Scale down for low coverage
  }

  /// Estimate memory usage
  static double _estimateMemoryUsage(Set<String> foundKeys, List<String>? scannedFiles) {
    // Rough estimation based on key count and file count
    final keyMemory = foundKeys.length * 0.1; // ~0.1KB per key
    final fileMemory = (scannedFiles?.length ?? 0) * 0.5; // ~0.5KB per file processed
    return (keyMemory + fileMemory) / 1024; // Convert to MB
  }
}