/// Advanced duplicate key detection and similarity analysis
library;

/// Result of duplicate key analysis
class DuplicateAnalysis {
  final Map<String, List<String>> exactDuplicates;
  final Map<String, List<SimilarKey>> similarKeys;
  final Map<String, List<KeyLocation>> duplicateLocations;
  final int totalDuplicates;
  final int potentialDuplicates;
  final double duplicateRatio;
  final List<DuplicateRecommendation> recommendations;

  const DuplicateAnalysis({
    required this.exactDuplicates,
    required this.similarKeys,
    required this.duplicateLocations,
    required this.totalDuplicates,
    required this.potentialDuplicates,
    required this.duplicateRatio,
    required this.recommendations,
  });

  /// Total number of issues (exact + potential duplicates)
  int get totalIssues => totalDuplicates + potentialDuplicates;

  /// Whether duplicates were found
  bool get hasDuplicates => totalDuplicates > 0;

  /// Whether similar keys were found
  bool get hasSimilarKeys => potentialDuplicates > 0;
}

/// Similar key with similarity score
class SimilarKey {
  final String key;
  final double similarity;
  final SimilarityType type;
  final String reason;

  const SimilarKey({
    required this.key,
    required this.similarity,
    required this.type,
    required this.reason,
  });
}

/// Type of similarity detected
enum SimilarityType {
  levenshtein,
  prefix,
  suffix,
  pattern,
  semantic,
}

/// Key location information
class KeyLocation {
  final String filePath;
  final int line;
  final int column;
  final String context;

  const KeyLocation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.context,
  });

  Map<String, dynamic> toJson() => {
    'file': filePath,
    'line': line,
    'column': column,
    'context': context,
  };
}

/// Recommendation for handling duplicates
class DuplicateRecommendation {
  final String type;
  final String description;
  final List<String> affectedKeys;
  final String priority;
  final String action;

  const DuplicateRecommendation({
    required this.type,
    required this.description,
    required this.affectedKeys,
    required this.priority,
    required this.action,
  });
}

/// Advanced duplicate key detector with similarity analysis
class DuplicateDetector {
  final double similarityThreshold;
  final bool enableSemanticAnalysis;
  final bool enablePatternAnalysis;
  final List<String> ignoredPatterns;
  final bool verbose;

  const DuplicateDetector({
    this.similarityThreshold = 0.8,
    this.enableSemanticAnalysis = true,
    this.enablePatternAnalysis = true,
    this.ignoredPatterns = const [],
    this.verbose = false,
  });

  /// Analyze keys for duplicates and similarities
  DuplicateAnalysis analyze({
    required Set<String> foundKeys,
    required Map<String, List<KeyLocation>> keyLocations,
    required Map<String, int> keyUsageCounts,
  }) {
    final stopwatch = Stopwatch()..start();

    // Find exact duplicates
    final exactDuplicates = _findExactDuplicates(keyUsageCounts);
    
    // Find similar keys
    final similarKeys = _findSimilarKeys(foundKeys.toList());
    
    // Extract duplicate locations
    final duplicateLocations = _extractDuplicateLocations(
      exactDuplicates, keyLocations);
    
    // Calculate metrics
    final totalDuplicates = exactDuplicates.values
        .fold(0, (sum, keys) => sum + keys.length);
    final potentialDuplicates = similarKeys.values
        .fold(0, (sum, similar) => sum + similar.length);
    final duplicateRatio = foundKeys.isEmpty ? 0.0 :
        (totalDuplicates / foundKeys.length) * 100;

    // Generate recommendations
    final recommendations = _generateRecommendations(
      exactDuplicates, similarKeys, duplicateRatio);

    stopwatch.stop();
    if (verbose) {
      print('Duplicate analysis completed in ${stopwatch.elapsedMilliseconds}ms');
    }

    return DuplicateAnalysis(
      exactDuplicates: exactDuplicates,
      similarKeys: similarKeys,
      duplicateLocations: duplicateLocations,
      totalDuplicates: totalDuplicates,
      potentialDuplicates: potentialDuplicates,
      duplicateRatio: duplicateRatio,
      recommendations: recommendations,
    );
  }

  /// Find keys with identical usage patterns
  Map<String, List<String>> _findExactDuplicates(Map<String, int> keyUsageCounts) {
    final duplicates = <String, List<String>>{};
    final processed = <String>{};

    for (final entry in keyUsageCounts.entries) {
      final key = entry.key;
      final count = entry.value;

      if (processed.contains(key) || count == 1) continue;

      final duplicatesForKey = keyUsageCounts.entries
          .where((e) => e.value == count && e.key != key && !processed.contains(e.key))
          .map((e) => e.key)
          .toList();

      if (duplicatesForKey.isNotEmpty) {
        duplicates[key] = duplicatesForKey;
        processed.add(key);
        processed.addAll(duplicatesForKey);
      }
    }

    return duplicates;
  }

  /// Find similar keys using multiple algorithms
  Map<String, List<SimilarKey>> _findSimilarKeys(List<String> keys) {
    final similar = <String, List<SimilarKey>>{};

    for (int i = 0; i < keys.length; i++) {
      final key1 = keys[i];
      if (_shouldIgnoreKey(key1)) continue;

      final similarForKey = <SimilarKey>[];

      for (int j = i + 1; j < keys.length; j++) {
        final key2 = keys[j];
        if (_shouldIgnoreKey(key2)) continue;

        final similarities = _calculateSimilarities(key1, key2);
        
        for (final similarity in similarities) {
          if (similarity.similarity >= similarityThreshold) {
            similarForKey.add(similarity);
          }
        }
      }

      if (similarForKey.isNotEmpty) {
        // Sort by similarity score (highest first)
        similarForKey.sort((a, b) => b.similarity.compareTo(a.similarity));
        similar[key1] = similarForKey;
      }
    }

    return similar;
  }

  /// Calculate multiple similarity metrics between two keys
  List<SimilarKey> _calculateSimilarities(String key1, String key2) {
    final similarities = <SimilarKey>[];

    // Levenshtein distance similarity
    final levenshteinSim = _levenshteinSimilarity(key1, key2);
    if (levenshteinSim >= similarityThreshold) {
      similarities.add(SimilarKey(
        key: key2,
        similarity: levenshteinSim,
        type: SimilarityType.levenshtein,
        reason: 'Similar character sequence',
      ));
    }

    // Prefix similarity
    final prefixSim = _prefixSimilarity(key1, key2);
    if (prefixSim >= similarityThreshold) {
      similarities.add(SimilarKey(
        key: key2,
        similarity: prefixSim,
        type: SimilarityType.prefix,
        reason: 'Similar prefix pattern',
      ));
    }

    // Suffix similarity
    final suffixSim = _suffixSimilarity(key1, key2);
    if (suffixSim >= similarityThreshold) {
      similarities.add(SimilarKey(
        key: key2,
        similarity: suffixSim,
        type: SimilarityType.suffix,
        reason: 'Similar suffix pattern',
      ));
    }

    // Pattern similarity (if enabled)
    if (enablePatternAnalysis) {
      final patternSim = _patternSimilarity(key1, key2);
      if (patternSim >= similarityThreshold) {
        similarities.add(SimilarKey(
          key: key2,
          similarity: patternSim,
          type: SimilarityType.pattern,
          reason: 'Similar naming pattern',
        ));
      }
    }

    // Semantic similarity (if enabled)
    if (enableSemanticAnalysis) {
      final semanticSim = _semanticSimilarity(key1, key2);
      if (semanticSim >= similarityThreshold) {
        similarities.add(SimilarKey(
          key: key2,
          similarity: semanticSim,
          type: SimilarityType.semantic,
          reason: 'Similar semantic meaning',
        ));
      }
    }

    return similarities;
  }

  /// Calculate Levenshtein distance similarity
  double _levenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Calculate prefix similarity
  double _prefixSimilarity(String s1, String s2) {
    final minLength = s1.length < s2.length ? s1.length : s2.length;
    if (minLength == 0) return 0.0;

    int commonPrefix = 0;
    for (int i = 0; i < minLength; i++) {
      if (s1[i] == s2[i]) {
        commonPrefix++;
      } else {
        break;
      }
    }

    return commonPrefix / minLength;
  }

  /// Calculate suffix similarity
  double _suffixSimilarity(String s1, String s2) {
    final minLength = s1.length < s2.length ? s1.length : s2.length;
    if (minLength == 0) return 0.0;

    int commonSuffix = 0;
    for (int i = 1; i <= minLength; i++) {
      if (s1[s1.length - i] == s2[s2.length - i]) {
        commonSuffix++;
      } else {
        break;
      }
    }

    return commonSuffix / minLength;
  }

  /// Calculate pattern similarity based on naming conventions
  double _patternSimilarity(String s1, String s2) {
    // Convert to comparable patterns
    final pattern1 = _extractPattern(s1);
    final pattern2 = _extractPattern(s2);
    
    if (pattern1 == pattern2) return 1.0;
    
    // Check for common UI patterns
    final uiPatterns = {
      'button', 'text', 'field', 'container', 'widget',
      'screen', 'page', 'dialog', 'modal', 'form'
    };
    
    final hasCommonPattern = uiPatterns.any((pattern) =>
        s1.toLowerCase().contains(pattern) && s2.toLowerCase().contains(pattern));
    
    return hasCommonPattern ? 0.7 : 0.0;
  }

  /// Extract naming pattern from key
  String _extractPattern(String key) {
    // Remove common suffixes/prefixes and extract core pattern
    final cleaned = key
        .replaceAll(RegExp(r'_?(button|btn|text|field|container|widget)_?', caseSensitive: false), '_X_')
        .replaceAll(RegExp(r'_?(screen|page|dialog|modal|form)_?', caseSensitive: false), '_Y_')
        .replaceAll(RegExp(r'\d+'), 'N');
    
    return cleaned;
  }

  /// Calculate semantic similarity based on meaning
  double _semanticSimilarity(String s1, String s2) {
    final semanticGroups = {
      'authentication': {'login', 'signin', 'auth', 'password', 'username'},
      'navigation': {'menu', 'nav', 'back', 'next', 'home', 'profile'},
      'actions': {'submit', 'cancel', 'save', 'delete', 'edit', 'update'},
      'input': {'field', 'input', 'text', 'form', 'search'},
      'display': {'label', 'title', 'header', 'footer', 'content'},
    };

    for (final group in semanticGroups.values) {
      final s1InGroup = group.any((word) => s1.toLowerCase().contains(word));
      final s2InGroup = group.any((word) => s2.toLowerCase().contains(word));
      
      if (s1InGroup && s2InGroup) {
        return 0.8; // High semantic similarity
      }
    }

    return 0.0;
  }

  /// Check if key should be ignored
  bool _shouldIgnoreKey(String key) {
    return ignoredPatterns.any((pattern) => 
        RegExp(pattern, caseSensitive: false).hasMatch(key));
  }

  /// Extract locations for duplicate keys
  Map<String, List<KeyLocation>> _extractDuplicateLocations(
    Map<String, List<String>> exactDuplicates,
    Map<String, List<KeyLocation>> keyLocations,
  ) {
    final duplicateLocations = <String, List<KeyLocation>>{};

    for (final entry in exactDuplicates.entries) {
      final primaryKey = entry.key;
      final duplicateKeys = entry.value;

      final locations = <KeyLocation>[];
      
      // Add primary key locations
      locations.addAll(keyLocations[primaryKey] ?? []);
      
      // Add duplicate key locations
      for (final duplicateKey in duplicateKeys) {
        locations.addAll(keyLocations[duplicateKey] ?? []);
      }

      if (locations.isNotEmpty) {
        duplicateLocations[primaryKey] = locations;
      }
    }

    return duplicateLocations;
  }

  /// Generate recommendations for handling duplicates
  List<DuplicateRecommendation> _generateRecommendations(
    Map<String, List<String>> exactDuplicates,
    Map<String, List<SimilarKey>> similarKeys,
    double duplicateRatio,
  ) {
    final recommendations = <DuplicateRecommendation>[];

    // Exact duplicate recommendations
    if (exactDuplicates.isNotEmpty) {
      recommendations.add(DuplicateRecommendation(
        type: 'exact_duplicates',
        description: 'Found ${exactDuplicates.length} sets of exact duplicate keys',
        affectedKeys: exactDuplicates.keys.toList(),
        priority: 'high',
        action: 'Review and consolidate duplicate keys to improve maintainability',
      ));
    }

    // Similar key recommendations
    if (similarKeys.isNotEmpty) {
      recommendations.add(DuplicateRecommendation(
        type: 'similar_keys',
        description: 'Found ${similarKeys.length} keys with similar patterns',
        affectedKeys: similarKeys.keys.toList(),
        priority: 'medium',
        action: 'Consider standardizing naming conventions for consistency',
      ));
    }

    // High duplicate ratio warning
    if (duplicateRatio > 20.0) {
      recommendations.add(DuplicateRecommendation(
        type: 'high_duplicate_ratio',
        description: 'High duplicate ratio (${duplicateRatio.toStringAsFixed(1)}%)',
        affectedKeys: [],
        priority: 'high',
        action: 'Review key naming strategy and consider refactoring',
      ));
    }

    // No issues found
    if (recommendations.isEmpty) {
      recommendations.add(DuplicateRecommendation(
        type: 'no_issues',
        description: 'No duplicate or similar keys detected',
        affectedKeys: [],
        priority: 'info',
        action: 'Key naming appears well-organized',
      ));
    }

    return recommendations;
  }
}