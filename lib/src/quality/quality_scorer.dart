/// Quality scoring system for Flutter KeyCheck reports
/// 
/// Provides comprehensive quality assessment with 0-100 scoring based on
/// coverage, organization, consistency, and other metrics.
library;

import 'dart:math' as math;

/// Quality score breakdown for detailed analysis
class QualityBreakdown {
  final double coverage;
  final double organization;
  final double consistency;
  final double efficiency;
  final double maintainability;
  final double overall;
  final List<String> recommendations;
  final Map<String, dynamic> metrics;

  const QualityBreakdown({
    required this.coverage,
    required this.organization,
    required this.consistency,
    required this.efficiency,
    required this.maintainability,
    required this.overall,
    required this.recommendations,
    required this.metrics,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'coverage': coverage,
        'organization': organization,
        'consistency': consistency,
        'efficiency': efficiency,
        'maintainability': maintainability,
        'overall': overall,
        'recommendations': recommendations,
        'metrics': metrics,
      };
}

/// Comprehensive quality scoring engine
class QualityScorer {
  static const double _coverageWeight = 0.35;
  static const double _organizationWeight = 0.20;
  static const double _consistencyWeight = 0.20;
  static const double _efficiencyWeight = 0.15;
  static const double _maintainabilityWeight = 0.10;

  /// Calculate comprehensive quality score (0-100)
  static QualityBreakdown calculateQuality({
    required Set<String> expectedKeys,
    required Set<String> foundKeys,
    required Set<String> missingKeys,
    required Set<String> extraKeys,
    Map<String, int>? keyUsageCounts,
    Map<String, List<dynamic>>? keyLocations,
    List<String>? scannedFiles,
    Duration? scanDuration,
  }) {
    // Calculate individual quality scores
    final coverage = _calculateCoverageScore(expectedKeys, missingKeys);
    final organization = _calculateOrganizationScore(
      expectedKeys, foundKeys, keyLocations, scannedFiles);
    final consistency = _calculateConsistencyScore(
      expectedKeys, foundKeys, keyUsageCounts, keyLocations);
    final efficiency = _calculateEfficiencyScore(
      expectedKeys, foundKeys, extraKeys, keyUsageCounts);
    final maintainability = _calculateMaintainabilityScore(
      expectedKeys, foundKeys, keyLocations, scannedFiles);

    // Calculate weighted overall score
    final overall = (coverage * _coverageWeight) +
        (organization * _organizationWeight) +
        (consistency * _consistencyWeight) +
        (efficiency * _efficiencyWeight) +
        (maintainability * _maintainabilityWeight);

    // Generate recommendations
    final recommendations = _generateRecommendations(
      coverage, organization, consistency, efficiency, maintainability,
      expectedKeys, foundKeys, missingKeys, extraKeys, keyUsageCounts);

    // Calculate detailed metrics
    final metrics = _calculateDetailedMetrics(
      expectedKeys, foundKeys, missingKeys, extraKeys,
      keyUsageCounts, keyLocations, scannedFiles, scanDuration);

    return QualityBreakdown(
      coverage: coverage,
      organization: organization,
      consistency: consistency,
      efficiency: efficiency,
      maintainability: maintainability,
      overall: overall,
      recommendations: recommendations,
      metrics: metrics,
    );
  }

  /// Calculate coverage quality score (0-100)
  static double _calculateCoverageScore(
      Set<String> expectedKeys, Set<String> missingKeys) {
    if (expectedKeys.isEmpty) return 100.0;
    
    final covered = expectedKeys.length - missingKeys.length;
    final baseScore = (covered / expectedKeys.length) * 100;
    
    // Apply penalty for missing critical keys
    final missingCount = missingKeys.length;
    if (missingCount == 0) return 100.0;
    if (missingCount <= 2) return math.max(baseScore, 85.0);
    if (missingCount <= 5) return math.max(baseScore, 70.0);
    if (missingCount <= 10) return math.max(baseScore, 50.0);
    
    return baseScore;
  }

  /// Calculate organization quality score (0-100)
  static double _calculateOrganizationScore(
      Set<String> expectedKeys, Set<String> foundKeys,
      Map<String, List<dynamic>>? keyLocations, List<String>? scannedFiles) {
    if (foundKeys.isEmpty) return 0.0;
    
    double score = 70.0; // Base score for having organized keys
    
    // Check key distribution across files
    if (keyLocations != null && scannedFiles != null) {
      final filesWithKeys = keyLocations.values
          .expand((locations) => locations)
          .where((loc) => loc is Map && loc['file'] != null)
          .map((loc) => loc['file'] as String)
          .toSet()
          .length;
      
      final totalFiles = scannedFiles.length;
      if (totalFiles > 0) {
        final distributionRatio = filesWithKeys / totalFiles;
        if (distributionRatio > 0.8) score += 15.0; // Well distributed
        else if (distributionRatio > 0.5) score += 10.0;
        else if (distributionRatio > 0.3) score += 5.0;
      }
    }
    
    // Check for naming conventions
    final hasConsistentNaming = _checkNamingConsistency(foundKeys);
    if (hasConsistentNaming) score += 15.0;
    
    return math.min(score, 100.0);
  }

  /// Calculate consistency quality score (0-100)
  static double _calculateConsistencyScore(
      Set<String> expectedKeys, Set<String> foundKeys,
      Map<String, int>? keyUsageCounts, Map<String, List<dynamic>>? keyLocations) {
    if (foundKeys.isEmpty) return 0.0;
    
    double score = 60.0; // Base score
    
    // Check for duplicate usage patterns
    if (keyUsageCounts != null) {
      final multiUseKeys = keyUsageCounts.entries
          .where((entry) => entry.value > 1)
          .length;
      
      final singleUseKeys = keyUsageCounts.entries
          .where((entry) => entry.value == 1)
          .length;
      
      if (multiUseKeys == 0) {
        score += 20.0; // No duplicates, good consistency
      } else {
        final duplicateRatio = multiUseKeys / keyUsageCounts.length;
        if (duplicateRatio < 0.1) score += 15.0;
        else if (duplicateRatio < 0.2) score += 10.0;
        else if (duplicateRatio < 0.3) score += 5.0;
      }
    }
    
    // Check naming pattern consistency
    final namingScore = _calculateNamingPatternScore(foundKeys);
    score += namingScore * 0.2; // Up to 20 points
    
    return math.min(score, 100.0);
  }

  /// Calculate efficiency quality score (0-100)
  static double _calculateEfficiencyScore(
      Set<String> expectedKeys, Set<String> foundKeys, Set<String> extraKeys,
      Map<String, int>? keyUsageCounts) {
    double score = 70.0; // Base score
    
    // Penalty for extra keys (noise)
    if (extraKeys.isNotEmpty) {
      final extraRatio = extraKeys.length / (foundKeys.length + extraKeys.length);
      if (extraRatio > 0.3) score -= 30.0;
      else if (extraRatio > 0.2) score -= 20.0;
      else if (extraRatio > 0.1) score -= 10.0;
      else score -= 5.0;
    } else {
      score += 10.0; // Bonus for no extra keys
    }
    
    // Check for unused expected keys efficiency
    if (keyUsageCounts != null && expectedKeys.isNotEmpty) {
      final expectedFound = expectedKeys.intersection(foundKeys);
      final averageUsage = expectedFound.isEmpty ? 0.0 :
          expectedFound.map((key) => keyUsageCounts[key] ?? 0)
              .reduce((a, b) => a + b) / expectedFound.length;
      
      if (averageUsage > 2.0) score += 15.0; // Keys are well used
      else if (averageUsage > 1.5) score += 10.0;
      else if (averageUsage > 1.0) score += 5.0;
    }
    
    return math.max(score, 0.0);
  }

  /// Calculate maintainability quality score (0-100)
  static double _calculateMaintainabilityScore(
      Set<String> expectedKeys, Set<String> foundKeys,
      Map<String, List<dynamic>>? keyLocations, List<String>? scannedFiles) {
    double score = 60.0; // Base score
    
    // Check for key organization patterns
    if (keyLocations != null) {
      final keysByFile = <String, int>{};
      for (final locations in keyLocations.values) {
        for (final location in locations) {
          if (location is Map && location['file'] != null) {
            final file = location['file'] as String;
            keysByFile[file] = (keysByFile[file] ?? 0) + 1;
          }
        }
      }
      
      // Check for concentrated vs scattered keys
      if (keysByFile.isNotEmpty) {
        final maxKeysPerFile = keysByFile.values.reduce(math.max);
        final avgKeysPerFile = keysByFile.values.reduce((a, b) => a + b) / keysByFile.length;
        
        if (maxKeysPerFile / avgKeysPerFile < 3.0) {
          score += 20.0; // Well distributed
        } else if (maxKeysPerFile / avgKeysPerFile < 5.0) {
          score += 10.0;
        }
      }
    }
    
    // Check for clear naming patterns that aid maintenance
    final clearNames = foundKeys.where((key) => 
        key.length > 3 && key.contains(RegExp(r'[A-Z]|_')))
        .length;
    
    if (foundKeys.isNotEmpty) {
      final clarityRatio = clearNames / foundKeys.length;
      if (clarityRatio > 0.8) score += 20.0;
      else if (clarityRatio > 0.6) score += 15.0;
      else if (clarityRatio > 0.4) score += 10.0;
    }
    
    return math.min(score, 100.0);
  }

  /// Generate actionable recommendations based on scores
  static List<String> _generateRecommendations(
      double coverage, double organization, double consistency,
      double efficiency, double maintainability,
      Set<String> expectedKeys, Set<String> foundKeys,
      Set<String> missingKeys, Set<String> extraKeys,
      Map<String, int>? keyUsageCounts) {
    
    final recommendations = <String>[];
    
    // Coverage recommendations
    if (coverage < 80.0) {
      recommendations.add('🎯 Add missing keys to improve test coverage (${missingKeys.length} missing)');
    }
    if (missingKeys.length > 5) {
      recommendations.add('⚡ Focus on critical missing keys first for immediate impact');
    }
    
    // Organization recommendations
    if (organization < 70.0) {
      recommendations.add('📁 Improve key organization by grouping related keys together');
      recommendations.add('🏗️ Consider using KeyConstants class for better organization');
    }
    
    // Consistency recommendations
    if (consistency < 70.0) {
      recommendations.add('🔄 Establish consistent naming patterns for all keys');
      if (keyUsageCounts != null) {
        final duplicates = keyUsageCounts.entries
            .where((e) => e.value > 1)
            .length;
        if (duplicates > 0) {
          recommendations.add('🔍 Review ${duplicates} duplicate keys for potential consolidation');
        }
      }
    }
    
    // Efficiency recommendations
    if (efficiency < 70.0) {
      if (extraKeys.isNotEmpty) {
        recommendations.add('🧹 Remove ${extraKeys.length} unused/extra keys to reduce noise');
      }
      recommendations.add('⚡ Optimize key usage patterns for better automation efficiency');
    }
    
    // Maintainability recommendations
    if (maintainability < 70.0) {
      recommendations.add('📚 Improve key naming for better maintainability');
      recommendations.add('🏷️ Add documentation for key usage patterns');
    }
    
    // Overall recommendations
    if (recommendations.isEmpty) {
      recommendations.add('✨ Excellent key organization! Continue monitoring for consistency');
    }
    
    return recommendations;
  }

  /// Calculate detailed metrics for analysis
  static Map<String, dynamic> _calculateDetailedMetrics(
      Set<String> expectedKeys, Set<String> foundKeys,
      Set<String> missingKeys, Set<String> extraKeys,
      Map<String, int>? keyUsageCounts, Map<String, List<dynamic>>? keyLocations,
      List<String>? scannedFiles, Duration? scanDuration) {
    
    final metrics = <String, dynamic>{};
    
    // Basic metrics
    metrics['expectedCount'] = expectedKeys.length;
    metrics['foundCount'] = foundKeys.length;
    metrics['missingCount'] = missingKeys.length;
    metrics['extraCount'] = extraKeys.length;
    metrics['coveragePercentage'] = expectedKeys.isEmpty ? 100.0 :
        ((expectedKeys.length - missingKeys.length) / expectedKeys.length) * 100;
    
    // Usage metrics
    if (keyUsageCounts != null) {
      final usageCounts = keyUsageCounts.values.toList();
      if (usageCounts.isNotEmpty) {
        metrics['averageUsage'] = usageCounts.reduce((a, b) => a + b) / usageCounts.length;
        metrics['maxUsage'] = usageCounts.reduce(math.max);
        metrics['duplicateKeys'] = usageCounts.where((count) => count > 1).length;
      }
    }
    
    // File distribution metrics
    if (keyLocations != null && scannedFiles != null) {
      final filesWithKeys = keyLocations.values
          .expand((locations) => locations)
          .where((loc) => loc is Map && loc['file'] != null)
          .map((loc) => loc['file'] as String)
          .toSet();
      
      metrics['filesWithKeys'] = filesWithKeys.length;
      metrics['totalFiles'] = scannedFiles.length;
      metrics['keyDistribution'] = scannedFiles.isEmpty ? 0.0 :
          filesWithKeys.length / scannedFiles.length;
    }
    
    // Performance metrics
    if (scanDuration != null) {
      metrics['scanTimeMs'] = scanDuration.inMilliseconds;
      metrics['keysPerSecond'] = scanDuration.inMilliseconds > 0 ?
          (foundKeys.length * 1000) / scanDuration.inMilliseconds : 0.0;
    }
    
    // Naming pattern metrics
    final namingMetrics = _analyzeNamingPatterns(foundKeys);
    metrics.addAll(namingMetrics);
    
    return metrics;
  }

  /// Check naming consistency across keys
  static bool _checkNamingConsistency(Set<String> keys) {
    if (keys.length < 3) return true;
    
    // Check for consistent patterns
    final camelCase = keys.where((k) => k.contains(RegExp(r'[a-z][A-Z]'))).length;
    final snakeCase = keys.where((k) => k.contains('_')).length;
    final kebabCase = keys.where((k) => k.contains('-')).length;
    
    final total = keys.length;
    final dominantPattern = math.max(math.max(camelCase, snakeCase), kebabCase);
    
    return dominantPattern / total > 0.7; // 70% consistency threshold
  }

  /// Calculate naming pattern score
  static double _calculateNamingPatternScore(Set<String> keys) {
    if (keys.isEmpty) return 0.0;
    
    double score = 0.0;
    
    // Check for descriptive names
    final descriptive = keys.where((k) => k.length > 3).length;
    score += (descriptive / keys.length) * 30.0;
    
    // Check for consistent casing
    final camelCase = keys.where((k) => k.contains(RegExp(r'[a-z][A-Z]'))).length;
    final snakeCase = keys.where((k) => k.contains('_')).length;
    
    final consistency = math.max(camelCase, snakeCase) / keys.length;
    score += consistency * 40.0;
    
    // Check for semantic naming
    final semantic = keys.where((k) => 
        k.toLowerCase().contains(RegExp(r'button|field|text|icon|screen|form|menu|item')))
        .length;
    score += (semantic / keys.length) * 30.0;
    
    return math.min(score, 100.0);
  }

  /// Analyze naming patterns in detail
  static Map<String, dynamic> _analyzeNamingPatterns(Set<String> keys) {
    if (keys.isEmpty) {
      return {
        'camelCaseCount': 0,
        'snakeCaseCount': 0,
        'kebabCaseCount': 0,
        'avgLength': 0.0,
        'semanticCount': 0,
      };
    }
    
    final camelCase = keys.where((k) => k.contains(RegExp(r'[a-z][A-Z]'))).length;
    final snakeCase = keys.where((k) => k.contains('_')).length;
    final kebabCase = keys.where((k) => k.contains('-')).length;
    
    final totalLength = keys.map((k) => k.length).reduce((a, b) => a + b);
    final avgLength = totalLength / keys.length;
    
    final semantic = keys.where((k) => 
        k.toLowerCase().contains(RegExp(r'button|field|text|icon|screen|form|menu|item|widget|dialog')))
        .length;
    
    return {
      'camelCaseCount': camelCase,
      'snakeCaseCount': snakeCase,
      'kebabCaseCount': kebabCase,
      'avgLength': avgLength,
      'semanticCount': semantic,
      'consistencyPattern': _getDominantPattern(camelCase, snakeCase, kebabCase),
    };
  }

  /// Get the dominant naming pattern
  static String _getDominantPattern(int camelCase, int snakeCase, int kebabCase) {
    if (camelCase >= snakeCase && camelCase >= kebabCase) return 'camelCase';
    if (snakeCase >= kebabCase) return 'snake_case';
    return 'kebab-case';
  }
}