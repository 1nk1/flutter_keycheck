/// Performance profiling and optimization for Flutter KeyCheck scans
library;

import 'dart:io';

/// Performance metrics collected during scan operations
class PerformanceMetrics {
  final Duration totalScanTime;
  final Duration astParsingTime;
  final Duration fileReadTime;
  final Duration analysisTime;
  final Duration reportGenerationTime;
  final int filesScanned;
  final int keysFound;
  final int astNodesProcessed;
  final double memoryUsageMB;
  final double cpuUsagePercent;
  final Map<String, Duration> operationTimes;
  final Map<String, int> operationCounts;
  final List<PerformanceBottleneck> bottlenecks;

  const PerformanceMetrics({
    required this.totalScanTime,
    required this.astParsingTime,
    required this.fileReadTime,
    required this.analysisTime,
    required this.reportGenerationTime,
    required this.filesScanned,
    required this.keysFound,
    required this.astNodesProcessed,
    required this.memoryUsageMB,
    required this.cpuUsagePercent,
    required this.operationTimes,
    required this.operationCounts,
    required this.bottlenecks,
  });

  /// Calculate keys found per second
  double get keysPerSecond => totalScanTime.inMilliseconds > 0
      ? (keysFound * 1000.0) / totalScanTime.inMilliseconds
      : 0.0;

  /// Calculate files processed per second
  double get filesPerSecond => totalScanTime.inMilliseconds > 0
      ? (filesScanned * 1000.0) / totalScanTime.inMilliseconds
      : 0.0;

  /// Calculate AST nodes processed per second
  double get astNodesPerSecond => astParsingTime.inMilliseconds > 0
      ? (astNodesProcessed * 1000.0) / astParsingTime.inMilliseconds
      : 0.0;

  /// Get performance score (0-100)
  double get performanceScore {
    final timeScore = _calculateTimeScore();
    final throughputScore = _calculateThroughputScore();
    final resourceScore = _calculateResourceScore();
    
    return (timeScore + throughputScore + resourceScore) / 3.0;
  }

  /// Calculate time-based performance score
  double _calculateTimeScore() {
    final totalMs = totalScanTime.inMilliseconds;
    if (totalMs <= 100) return 100.0;
    if (totalMs <= 500) return 85.0;
    if (totalMs <= 1000) return 70.0;
    if (totalMs <= 2000) return 55.0;
    if (totalMs <= 5000) return 40.0;
    return 25.0;
  }

  /// Calculate throughput-based performance score
  double _calculateThroughputScore() {
    if (keysPerSecond >= 1000) return 100.0;
    if (keysPerSecond >= 500) return 85.0;
    if (keysPerSecond >= 200) return 70.0;
    if (keysPerSecond >= 100) return 55.0;
    if (keysPerSecond >= 50) return 40.0;
    return 25.0;
  }

  /// Calculate resource-based performance score
  double _calculateResourceScore() {
    if (memoryUsageMB <= 50) return 100.0;
    if (memoryUsageMB <= 100) return 85.0;
    if (memoryUsageMB <= 200) return 70.0;
    if (memoryUsageMB <= 500) return 55.0;
    if (memoryUsageMB <= 1000) return 40.0;
    return 25.0;
  }

  /// Convert to JSON for reporting
  Map<String, dynamic> toJson() => {
    'totalScanTimeMs': totalScanTime.inMilliseconds,
    'astParsingTimeMs': astParsingTime.inMilliseconds,
    'fileReadTimeMs': fileReadTime.inMilliseconds,
    'analysisTimeMs': analysisTime.inMilliseconds,
    'reportGenerationTimeMs': reportGenerationTime.inMilliseconds,
    'filesScanned': filesScanned,
    'keysFound': keysFound,
    'astNodesProcessed': astNodesProcessed,
    'memoryUsageMB': memoryUsageMB,
    'cpuUsagePercent': cpuUsagePercent,
    'keysPerSecond': keysPerSecond,
    'filesPerSecond': filesPerSecond,
    'astNodesPerSecond': astNodesPerSecond,
    'performanceScore': performanceScore,
    'operationTimes': operationTimes.map((k, v) => MapEntry(k, v.inMilliseconds)),
    'operationCounts': operationCounts,
    'bottlenecks': bottlenecks.map((b) => b.toJson()).toList(),
  };
}

/// Performance bottleneck identification
class PerformanceBottleneck {
  final String operation;
  final Duration time;
  final double impactPercent;
  final String description;
  final List<String> recommendations;

  const PerformanceBottleneck({
    required this.operation,
    required this.time,
    required this.impactPercent,
    required this.description,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'timeMs': time.inMilliseconds,
    'impactPercent': impactPercent,
    'description': description,
    'recommendations': recommendations,
  };
}

/// Performance profiling configuration
class ProfilingConfig {
  final bool enableDetailedProfiling;
  final bool enableMemoryProfiling;
  final bool enableCpuProfiling;
  final bool trackOperationCounts;
  final double bottleneckThresholdPercent;
  final Duration slowOperationThreshold;

  const ProfilingConfig({
    this.enableDetailedProfiling = true,
    this.enableMemoryProfiling = true,
    this.enableCpuProfiling = false, // CPU profiling can be expensive
    this.trackOperationCounts = true,
    this.bottleneckThresholdPercent = 20.0,
    this.slowOperationThreshold = const Duration(milliseconds: 100),
  });
}

/// Performance profiler for Flutter KeyCheck operations
class PerformanceProfiler {
  final ProfilingConfig config;
  final bool verbose;
  
  final Map<String, Stopwatch> _operationTimers = {};
  final Map<String, Duration> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  final List<PerformanceBottleneck> _bottlenecks = [];
  
  int _filesScanned = 0;
  int _keysFound = 0;
  int _astNodesProcessed = 0;
  double _memoryUsageMB = 0.0;
  double _cpuUsagePercent = 0.0;

  PerformanceProfiler({
    this.config = const ProfilingConfig(),
    this.verbose = false,
  });

  /// Start profiling a specific operation
  void startOperation(String operationName) {
    if (!config.enableDetailedProfiling) return;

    _operationTimers[operationName] = Stopwatch()..start();
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;

    if (verbose) {
      print('📊 Starting operation: $operationName');
    }
  }

  /// Stop profiling a specific operation
  void stopOperation(String operationName) {
    if (!config.enableDetailedProfiling) return;

    final timer = _operationTimers[operationName];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsed;
      _operationTimes[operationName] = 
          (_operationTimes[operationName] ?? Duration.zero) + duration;
      
      if (verbose && duration > config.slowOperationThreshold) {
        print('⚠️ Slow operation: $operationName took ${duration.inMilliseconds}ms');
      }
    }
  }

  /// Record file scanning metrics
  void recordFileScanned() {
    _filesScanned++;
  }

  /// Record key discovery metrics
  void recordKeyFound() {
    _keysFound++;
  }

  /// Record AST node processing metrics
  void recordAstNodeProcessed(int count) {
    _astNodesProcessed += count;
  }

  /// Update memory usage
  void updateMemoryUsage() {
    if (!config.enableMemoryProfiling) return;

    try {
      // Get current process memory usage
      final result = Process.runSync('ps', ['-o', 'rss=', '-p', '${pid}']);
      if (result.exitCode == 0) {
        final rssKB = int.tryParse(result.stdout.toString().trim()) ?? 0;
        _memoryUsageMB = rssKB / 1024.0; // Convert KB to MB
      }
    } catch (e) {
      // Memory profiling not available on this platform
      if (verbose) {
        print('Memory profiling unavailable: $e');
      }
    }
  }

  /// Update CPU usage (placeholder for future implementation)
  void updateCpuUsage() {
    if (!config.enableCpuProfiling) return;
    
    // CPU profiling would require platform-specific implementation
    // For now, we'll leave this as a placeholder
    _cpuUsagePercent = 0.0;
  }

  /// Analyze performance bottlenecks
  void _analyzeBottlenecks(Duration totalTime) {
    _bottlenecks.clear();
    
    final totalMs = totalTime.inMilliseconds.toDouble();
    if (totalMs == 0) return;

    for (final entry in _operationTimes.entries) {
      final operationName = entry.key;
      final operationTime = entry.value;
      final impactPercent = (operationTime.inMilliseconds / totalMs) * 100;

      if (impactPercent >= config.bottleneckThresholdPercent) {
        final recommendations = _getRecommendationsForOperation(
            operationName, operationTime, impactPercent);
        
        _bottlenecks.add(PerformanceBottleneck(
          operation: operationName,
          time: operationTime,
          impactPercent: impactPercent,
          description: 'Operation taking ${impactPercent.toStringAsFixed(1)}% of total time',
          recommendations: recommendations,
        ));
      }
    }

    // Sort bottlenecks by impact
    _bottlenecks.sort((a, b) => b.impactPercent.compareTo(a.impactPercent));
  }

  /// Get optimization recommendations for specific operations
  List<String> _getRecommendationsForOperation(
      String operation, Duration time, double impactPercent) {
    final recommendations = <String>[];

    switch (operation.toLowerCase()) {
      case 'file_reading':
        recommendations.addAll([
          'Consider using parallel file reading for large projects',
          'Implement file content caching to avoid re-reading unchanged files',
          'Use streaming for very large files',
        ]);
        break;

      case 'ast_parsing':
        recommendations.addAll([
          'Enable AST result caching for unchanged files',
          'Consider limiting AST depth for faster parsing',
          'Use parallel AST parsing for multiple files',
        ]);
        break;

      case 'key_analysis':
        recommendations.addAll([
          'Optimize key pattern matching algorithms',
          'Use more efficient data structures for key storage',
          'Consider early termination for performance-critical paths',
        ]);
        break;

      case 'report_generation':
        recommendations.addAll([
          'Use template caching for report generation',
          'Consider generating reports asynchronously',
          'Optimize HTML/CSS generation for large datasets',
        ]);
        break;

      default:
        recommendations.add('Profile this operation in more detail to identify specific optimizations');
    }

    if (impactPercent > 50) {
      recommendations.insert(0, 'Consider major architectural changes - this operation dominates scan time');
    }

    return recommendations;
  }

  /// Generate comprehensive performance metrics
  PerformanceMetrics generateMetrics() {
    final totalTime = _operationTimes.values.fold(
        Duration.zero, (sum, duration) => sum + duration);
    
    _analyzeBottlenecks(totalTime);
    updateMemoryUsage();
    updateCpuUsage();

    return PerformanceMetrics(
      totalScanTime: totalTime,
      astParsingTime: _operationTimes['ast_parsing'] ?? Duration.zero,
      fileReadTime: _operationTimes['file_reading'] ?? Duration.zero,
      analysisTime: _operationTimes['key_analysis'] ?? Duration.zero,
      reportGenerationTime: _operationTimes['report_generation'] ?? Duration.zero,
      filesScanned: _filesScanned,
      keysFound: _keysFound,
      astNodesProcessed: _astNodesProcessed,
      memoryUsageMB: _memoryUsageMB,
      cpuUsagePercent: _cpuUsagePercent,
      operationTimes: Map.from(_operationTimes),
      operationCounts: Map.from(_operationCounts),
      bottlenecks: List.from(_bottlenecks),
    );
  }

  /// Reset all profiling data
  void reset() {
    _operationTimers.clear();
    _operationTimes.clear();
    _operationCounts.clear();
    _bottlenecks.clear();
    _filesScanned = 0;
    _keysFound = 0;
    _astNodesProcessed = 0;
    _memoryUsageMB = 0.0;
    _cpuUsagePercent = 0.0;
  }

  /// Print performance summary to console
  void printSummary() {
    final metrics = generateMetrics();
    
    print('\n📊 Performance Summary:');
    print('  Total Time: ${metrics.totalScanTime.inMilliseconds}ms');
    print('  Files Scanned: ${metrics.filesScanned}');
    print('  Keys Found: ${metrics.keysFound}');
    print('  Keys/Second: ${metrics.keysPerSecond.toStringAsFixed(1)}');
    print('  Files/Second: ${metrics.filesPerSecond.toStringAsFixed(1)}');
    print('  Performance Score: ${metrics.performanceScore.toStringAsFixed(1)}/100');
    
    if (config.enableMemoryProfiling) {
      print('  Memory Usage: ${metrics.memoryUsageMB.toStringAsFixed(1)} MB');
    }

    if (metrics.bottlenecks.isNotEmpty) {
      print('\n⚠️ Performance Bottlenecks:');
      for (final bottleneck in metrics.bottlenecks.take(3)) {
        print('  • ${bottleneck.operation}: ${bottleneck.impactPercent.toStringAsFixed(1)}% (${bottleneck.time.inMilliseconds}ms)');
      }
    }
  }
}

/// Performance optimization recommendations
class OptimizationEngine {
  /// Generate optimization recommendations based on metrics
  static List<String> generateRecommendations(PerformanceMetrics metrics) {
    final recommendations = <String>[];

    // Time-based recommendations
    if (metrics.totalScanTime.inMilliseconds > 2000) {
      recommendations.add('Consider enabling caching to reduce scan time');
      recommendations.add('Use parallel processing for large projects');
    }

    // Throughput recommendations
    if (metrics.keysPerSecond < 100) {
      recommendations.add('Optimize key detection algorithms');
      recommendations.add('Consider using more efficient data structures');
    }

    // Memory recommendations
    if (metrics.memoryUsageMB > 500) {
      recommendations.add('Implement memory-efficient streaming for large files');
      recommendations.add('Consider processing files in batches');
    }

    // AST processing recommendations
    if (metrics.astNodesPerSecond < 1000) {
      recommendations.add('Optimize AST traversal algorithms');
      recommendations.add('Consider limiting AST depth for performance');
    }

    // Bottleneck-specific recommendations
    for (final bottleneck in metrics.bottlenecks) {
      recommendations.addAll(bottleneck.recommendations);
    }

    // General recommendations
    if (recommendations.isEmpty) {
      recommendations.add('Performance appears optimal - no specific optimizations needed');
    }

    return recommendations.take(5).toList(); // Limit to top 5 recommendations
  }
}