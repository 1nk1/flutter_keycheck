/// Comprehensive metrics collection and analytics for Flutter KeyCheck
library;

import 'dart:io';
import 'dart:convert';

/// System metrics captured during scan operations
class SystemMetrics {
  final double cpuUsagePercent;
  final double memoryUsageMB;
  final double diskUsageMB;
  final int processId;
  final DateTime timestamp;
  final String platform;
  final Map<String, dynamic> environmentInfo;

  const SystemMetrics({
    required this.cpuUsagePercent,
    required this.memoryUsageMB,
    required this.diskUsageMB,
    required this.processId,
    required this.timestamp,
    required this.platform,
    required this.environmentInfo,
  });

  Map<String, dynamic> toJson() => {
    'cpuUsagePercent': cpuUsagePercent,
    'memoryUsageMB': memoryUsageMB,
    'diskUsageMB': diskUsageMB,
    'processId': processId,
    'timestamp': timestamp.toIso8601String(),
    'platform': platform,
    'environmentInfo': environmentInfo,
  };
}

/// Scan operation metrics
class ScanMetrics {
  final Duration totalDuration;
  final int filesScanned;
  final int keysFound;
  final int duplicateKeys;
  final int missingKeys;
  final int extraKeys;
  final double coveragePercent;
  final Map<String, int> fileTypeDistribution;
  final Map<String, Duration> operationTimings;
  final List<String> errorsEncountered;

  const ScanMetrics({
    required this.totalDuration,
    required this.filesScanned,
    required this.keysFound,
    required this.duplicateKeys,
    required this.missingKeys,
    required this.extraKeys,
    required this.coveragePercent,
    required this.fileTypeDistribution,
    required this.operationTimings,
    required this.errorsEncountered,
  });

  Map<String, dynamic> toJson() => {
    'totalDurationMs': totalDuration.inMilliseconds,
    'filesScanned': filesScanned,
    'keysFound': keysFound,
    'duplicateKeys': duplicateKeys,
    'missingKeys': missingKeys,
    'extraKeys': extraKeys,
    'coveragePercent': coveragePercent,
    'fileTypeDistribution': fileTypeDistribution,
    'operationTimings': operationTimings.map((k, v) => MapEntry(k, v.inMilliseconds)),
    'errorsEncountered': errorsEncountered,
  };
}

/// Quality metrics from analysis
class QualityMetrics {
  final double overallScore;
  final double coverageScore;
  final double organizationScore;
  final double consistencyScore;
  final double efficiencyScore;
  final double maintainabilityScore;
  final int issuesFound;
  final List<String> recommendations;
  final Map<String, int> severityDistribution;

  const QualityMetrics({
    required this.overallScore,
    required this.coverageScore,
    required this.organizationScore,
    required this.consistencyScore,
    required this.efficiencyScore,
    required this.maintainabilityScore,
    required this.issuesFound,
    required this.recommendations,
    required this.severityDistribution,
  });

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'coverageScore': coverageScore,
    'organizationScore': organizationScore,
    'consistencyScore': consistencyScore,
    'efficiencyScore': efficiencyScore,
    'maintainabilityScore': maintainabilityScore,
    'issuesFound': issuesFound,
    'recommendations': recommendations,
    'severityDistribution': severityDistribution,
  };
}

/// Cache performance metrics
class CacheMetrics {
  final int hitCount;
  final int missCount;
  final double hitRate;
  final int totalEntries;
  final double sizeMB;
  final Duration averageAccessTime;
  final Map<String, int> operationCounts;

  const CacheMetrics({
    required this.hitCount,
    required this.missCount,
    required this.hitRate,
    required this.totalEntries,
    required this.sizeMB,
    required this.averageAccessTime,
    required this.operationCounts,
  });

  Map<String, dynamic> toJson() => {
    'hitCount': hitCount,
    'missCount': missCount,
    'hitRate': hitRate,
    'totalEntries': totalEntries,
    'sizeMB': sizeMB,
    'averageAccessTimeMs': averageAccessTime.inMilliseconds,
    'operationCounts': operationCounts,
  };
}

/// Comprehensive metrics report
class MetricsReport {
  final SystemMetrics system;
  final ScanMetrics scan;
  final QualityMetrics quality;
  final CacheMetrics cache;
  final DateTime generatedAt;
  final String version;
  final Map<String, dynamic> customMetrics;

  const MetricsReport({
    required this.system,
    required this.scan,
    required this.quality,
    required this.cache,
    required this.generatedAt,
    required this.version,
    required this.customMetrics,
  });

  Map<String, dynamic> toJson() => {
    'system': system.toJson(),
    'scan': scan.toJson(),
    'quality': quality.toJson(),
    'cache': cache.toJson(),
    'generatedAt': generatedAt.toIso8601String(),
    'version': version,
    'customMetrics': customMetrics,
  };
}

/// Configuration for metrics collection
class MetricsConfig {
  final bool enableSystemMetrics;
  final bool enablePerformanceMetrics;
  final bool enableQualityMetrics;
  final bool enableCacheMetrics;
  final bool enableTelemetry;
  final Duration samplingInterval;
  final String outputPath;
  final bool anonymizeData;

  const MetricsConfig({
    this.enableSystemMetrics = true,
    this.enablePerformanceMetrics = true,
    this.enableQualityMetrics = true,
    this.enableCacheMetrics = true,
    this.enableTelemetry = false,
    this.samplingInterval = const Duration(seconds: 1),
    this.outputPath = '.flutter_keycheck_metrics',
    this.anonymizeData = true,
  });
}

/// Comprehensive metrics collector
class MetricsCollector {
  final MetricsConfig config;
  final bool verbose;
  final String projectPath;

  final List<SystemMetrics> _systemSamples = [];
  final Map<String, Duration> _operationTimings = {};
  final Map<String, Stopwatch> _activeTimers = {};
  final List<String> _errors = [];
  final Map<String, dynamic> _customMetrics = {};
  
  int _filesScanned = 0;
  int _keysFound = 0;
  int _duplicateKeys = 0;
  int _missingKeys = 0;
  int _extraKeys = 0;
  double _coveragePercent = 0.0;
  
  MetricsCollector({
    required this.projectPath,
    this.config = const MetricsConfig(),
    this.verbose = false,
  });

  /// Start collecting metrics
  Future<void> startCollection() async {
    if (verbose) {
      print('📊 Starting metrics collection');
    }

    if (config.enableSystemMetrics) {
      await _startSystemMetricsCollection();
    }
  }

  /// Stop collecting metrics and generate report
  Future<MetricsReport> stopCollectionAndGenerateReport({
    QualityMetrics? qualityMetrics,
    CacheMetrics? cacheMetrics,
  }) async {
    if (verbose) {
      print('📊 Stopping metrics collection and generating report');
    }

    final systemMetrics = await _generateSystemMetrics();
    final scanMetrics = _generateScanMetrics();
    final finalQualityMetrics = qualityMetrics ?? _generateDefaultQualityMetrics();
    final finalCacheMetrics = cacheMetrics ?? _generateDefaultCacheMetrics();

    final report = MetricsReport(
      system: systemMetrics,
      scan: scanMetrics,
      quality: finalQualityMetrics,
      cache: finalCacheMetrics,
      generatedAt: DateTime.now(),
      version: '3.1.10', // TODO: Get from pubspec
      customMetrics: Map.from(_customMetrics),
    );

    if (config.outputPath.isNotEmpty) {
      await _saveReport(report);
    }

    return report;
  }

  /// Start timing an operation
  void startOperation(String operationName) {
    _activeTimers[operationName] = Stopwatch()..start();
    
    if (verbose) {
      print('⏱️  Started timing: $operationName');
    }
  }

  /// Stop timing an operation
  void stopOperation(String operationName) {
    final timer = _activeTimers.remove(operationName);
    if (timer != null) {
      timer.stop();
      _operationTimings[operationName] = 
          (_operationTimings[operationName] ?? Duration.zero) + timer.elapsed;
      
      if (verbose) {
        print('⏱️  Stopped timing: $operationName (${timer.elapsedMilliseconds}ms)');
      }
    }
  }

  /// Record file scanning activity
  void recordFileScanned(String filePath) {
    _filesScanned++;
    
    // Track file type distribution
    final extension = filePath.split('.').last.toLowerCase();
    final currentCount = _customMetrics['fileTypes'] as Map<String, int>? ?? {};
    currentCount[extension] = (currentCount[extension] ?? 0) + 1;
    _customMetrics['fileTypes'] = currentCount;
  }

  /// Record key discovery
  void recordKeyFound(String keyName) {
    _keysFound++;
    
    // Track key patterns
    final patterns = _customMetrics['keyPatterns'] as Map<String, int>? ?? {};
    final pattern = _extractKeyPattern(keyName);
    patterns[pattern] = (patterns[pattern] ?? 0) + 1;
    _customMetrics['keyPatterns'] = patterns;
  }

  /// Record scan results
  void recordScanResults({
    required int duplicateKeys,
    required int missingKeys,
    required int extraKeys,
    required double coveragePercent,
  }) {
    _duplicateKeys = duplicateKeys;
    _missingKeys = missingKeys;
    _extraKeys = extraKeys;
    _coveragePercent = coveragePercent;
  }

  /// Record an error
  void recordError(String error) {
    _errors.add(error);
    
    if (verbose) {
      print('❌ Error recorded: $error');
    }
  }

  /// Add custom metric
  void addCustomMetric(String key, dynamic value) {
    _customMetrics[key] = value;
  }

  /// Increment custom counter
  void incrementCustomCounter(String key, [int amount = 1]) {
    _customMetrics[key] = (_customMetrics[key] as int? ?? 0) + amount;
  }

  /// Start system metrics collection
  Future<void> _startSystemMetricsCollection() async {
    // Collect initial system metrics
    try {
      final systemMetrics = await _collectCurrentSystemMetrics();
      _systemSamples.add(systemMetrics);
    } catch (e) {
      if (verbose) {
        print('⚠️ Failed to collect system metrics: $e');
      }
    }
  }

  /// Collect current system metrics
  Future<SystemMetrics> _collectCurrentSystemMetrics() async {
    final timestamp = DateTime.now();
    final processId = pid;
    final platform = Platform.operatingSystem;
    
    double memoryUsageMB = 0.0;
    double cpuUsagePercent = 0.0;
    double diskUsageMB = 0.0;
    
    // Try to get memory usage (platform-specific)
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('ps', ['-o', 'rss,pcpu', '-p', '$processId']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.length > 1) {
            final parts = lines[1].trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              memoryUsageMB = (int.tryParse(parts[0]) ?? 0) / 1024.0; // Convert KB to MB
              cpuUsagePercent = double.tryParse(parts[1]) ?? 0.0;
            }
          }
        }
      }
    } catch (e) {
      // System metrics not available
    }

    // Get disk usage for project path
    try {
      if (Directory(projectPath).existsSync()) {
        final result = await Process.run('du', ['-sm', projectPath]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          final sizeMB = int.tryParse(output.split('\t')[0]) ?? 0;
          diskUsageMB = sizeMB.toDouble();
        }
      }
    } catch (e) {
      // Disk usage calculation failed
    }

    final environmentInfo = {
      'dart_version': Platform.version,
      'os_version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'is_debug': bool.fromEnvironment('dart.vm.debug', defaultValue: false),
      'executable': Platform.executable,
    };

    return SystemMetrics(
      cpuUsagePercent: cpuUsagePercent,
      memoryUsageMB: memoryUsageMB,
      diskUsageMB: diskUsageMB,
      processId: processId,
      timestamp: timestamp,
      platform: platform,
      environmentInfo: environmentInfo,
    );
  }

  /// Generate system metrics summary
  Future<SystemMetrics> _generateSystemMetrics() async {
    if (_systemSamples.isEmpty) {
      return await _collectCurrentSystemMetrics();
    }

    // Calculate averages from samples
    final avgCpu = _systemSamples.map((s) => s.cpuUsagePercent)
        .reduce((a, b) => a + b) / _systemSamples.length;
    final avgMemory = _systemSamples.map((s) => s.memoryUsageMB)
        .reduce((a, b) => a + b) / _systemSamples.length;
    final avgDisk = _systemSamples.map((s) => s.diskUsageMB)
        .reduce((a, b) => a + b) / _systemSamples.length;

    final latest = _systemSamples.last;
    
    return SystemMetrics(
      cpuUsagePercent: avgCpu,
      memoryUsageMB: avgMemory,
      diskUsageMB: avgDisk,
      processId: latest.processId,
      timestamp: latest.timestamp,
      platform: latest.platform,
      environmentInfo: latest.environmentInfo,
    );
  }

  /// Generate scan metrics summary
  ScanMetrics _generateScanMetrics() {
    final totalDuration = _operationTimings.values.fold(
        Duration.zero, (sum, duration) => sum + duration);

    final fileTypes = _customMetrics['fileTypes'] as Map<String, int>? ?? {};

    return ScanMetrics(
      totalDuration: totalDuration,
      filesScanned: _filesScanned,
      keysFound: _keysFound,
      duplicateKeys: _duplicateKeys,
      missingKeys: _missingKeys,
      extraKeys: _extraKeys,
      coveragePercent: _coveragePercent,
      fileTypeDistribution: Map.from(fileTypes),
      operationTimings: Map.from(_operationTimings),
      errorsEncountered: List.from(_errors),
    );
  }

  /// Generate default quality metrics when not provided
  QualityMetrics _generateDefaultQualityMetrics() {
    final issuesFound = _missingKeys + _duplicateKeys + _errors.length;
    final overallScore = _coveragePercent; // Simplified calculation
    
    return QualityMetrics(
      overallScore: overallScore,
      coverageScore: _coveragePercent,
      organizationScore: _duplicateKeys == 0 ? 100.0 : 50.0,
      consistencyScore: _errors.isEmpty ? 100.0 : 70.0,
      efficiencyScore: 85.0, // Default efficiency score
      maintainabilityScore: 80.0, // Default maintainability score
      issuesFound: issuesFound,
      recommendations: _generateBasicRecommendations(),
      severityDistribution: {
        'high': _missingKeys,
        'medium': _duplicateKeys,
        'low': _errors.length,
      },
    );
  }

  /// Generate default cache metrics when not provided
  CacheMetrics _generateDefaultCacheMetrics() {
    return const CacheMetrics(
      hitCount: 0,
      missCount: 0,
      hitRate: 0.0,
      totalEntries: 0,
      sizeMB: 0.0,
      averageAccessTime: Duration.zero,
      operationCounts: {},
    );
  }

  /// Generate basic recommendations
  List<String> _generateBasicRecommendations() {
    final recommendations = <String>[];
    
    if (_missingKeys > 0) {
      recommendations.add('Add ${_missingKeys} missing keys to improve coverage');
    }
    
    if (_duplicateKeys > 0) {
      recommendations.add('Review ${_duplicateKeys} duplicate keys for optimization');
    }
    
    if (_errors.isNotEmpty) {
      recommendations.add('Fix ${_errors.length} errors encountered during scan');
    }
    
    if (_coveragePercent < 80) {
      recommendations.add('Improve key coverage to meet quality standards');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('All metrics look good - maintain current quality standards');
    }
    
    return recommendations;
  }

  /// Extract key pattern for analysis
  String _extractKeyPattern(String keyName) {
    if (keyName.contains('button') || keyName.contains('btn')) return 'button';
    if (keyName.contains('text') || keyName.contains('label')) return 'text';
    if (keyName.contains('field') || keyName.contains('input')) return 'input';
    if (keyName.contains('screen') || keyName.contains('page')) return 'screen';
    if (keyName.contains('dialog') || keyName.contains('modal')) return 'dialog';
    if (keyName.contains('menu') || keyName.contains('nav')) return 'navigation';
    return 'other';
  }

  /// Save metrics report to file
  Future<void> _saveReport(MetricsReport report) async {
    try {
      final outputDir = Directory(config.outputPath);
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final filename = 'metrics_$timestamp.json';
      final file = File('${config.outputPath}/$filename');

      final jsonData = jsonEncode(report.toJson());
      await file.writeAsString(jsonData);

      if (verbose) {
        print('📊 Metrics report saved to: ${file.path}');
      }
    } catch (e) {
      if (verbose) {
        print('⚠️ Failed to save metrics report: $e');
      }
    }
  }
}