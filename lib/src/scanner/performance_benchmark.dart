import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:path/path.dart' as path;

/// Performance benchmark suite for AST scanner optimization
class PerformanceBenchmark {
  final String projectPath;
  final ConfigV3 config;
  
  PerformanceBenchmark({
    required this.projectPath,
    required this.config,
  });

  /// Run comprehensive performance benchmarks
  Future<BenchmarkResult> runBenchmark() async {
    print('🚀 Starting Performance Benchmark Suite...\n');
    
    final results = <String, BenchmarkMetrics>{};
    
    // Benchmark 1: Sequential vs Parallel processing
    results['sequential'] = await _benchmarkSequential();
    results['parallel'] = await _benchmarkParallel();
    
    // Benchmark 2: Cache performance
    results['cache_cold'] = await _benchmarkCacheCold();
    results['cache_warm'] = await _benchmarkCacheWarm();
    
    // Benchmark 3: File size impact
    results['small_files'] = await _benchmarkSmallFiles();
    results['large_files'] = await _benchmarkLargeFiles();
    
    // Benchmark 4: Memory usage patterns
    results['memory_optimized'] = await _benchmarkMemoryOptimized();
    results['memory_standard'] = await _benchmarkMemoryStandard();
    
    return BenchmarkResult(results);
  }

  /// Benchmark sequential processing
  Future<BenchmarkMetrics> _benchmarkSequential() async {
    print('📊 Benchmarking sequential processing...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: false,
      enableIncrementalScanning: false,
      enableLazyLoading: false,
      enableAggressiveCaching: false,
    );
    
    return await _runScanBenchmark(scanner, 'Sequential');
  }

  /// Benchmark parallel processing
  Future<BenchmarkMetrics> _benchmarkParallel() async {
    print('📊 Benchmarking parallel processing...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: false,
      enableLazyLoading: false,
      enableAggressiveCaching: false,
      maxWorkerIsolates: Platform.numberOfProcessors,
    );
    
    return await _runScanBenchmark(scanner, 'Parallel');
  }

  /// Benchmark cold cache performance
  Future<BenchmarkMetrics> _benchmarkCacheCold() async {
    print('📊 Benchmarking cold cache performance...');
    
    // Clear cache first
    await _clearCache();
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: true,
      enableLazyLoading: true,
      enableAggressiveCaching: true,
    );
    
    return await _runScanBenchmark(scanner, 'Cold Cache');
  }

  /// Benchmark warm cache performance
  Future<BenchmarkMetrics> _benchmarkCacheWarm() async {
    print('📊 Benchmarking warm cache performance...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: true,
      enableLazyLoading: true,
      enableAggressiveCaching: true,
    );
    
    return await _runScanBenchmark(scanner, 'Warm Cache');
  }

  /// Benchmark small files performance
  Future<BenchmarkMetrics> _benchmarkSmallFiles() async {
    print('📊 Benchmarking small files (<100KB)...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: true,
      enableLazyLoading: false, // Disable lazy loading for small files
      enableAggressiveCaching: true,
      maxFileSizeForMemory: 100 * 1024, // 100KB threshold
    );
    
    return await _runScanBenchmark(scanner, 'Small Files');
  }

  /// Benchmark large files performance
  Future<BenchmarkMetrics> _benchmarkLargeFiles() async {
    print('📊 Benchmarking large files (>100KB)...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: true,
      enableLazyLoading: true, // Enable lazy loading for large files
      enableAggressiveCaching: true,
      maxFileSizeForMemory: 50 * 1024, // Lower threshold to force lazy loading
    );
    
    return await _runScanBenchmark(scanner, 'Large Files');
  }

  /// Benchmark memory-optimized configuration
  Future<BenchmarkMetrics> _benchmarkMemoryOptimized() async {
    print('📊 Benchmarking memory-optimized configuration...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: true,
      enableLazyLoading: true,
      enableAggressiveCaching: true,
      maxWorkerIsolates: Platform.numberOfProcessors ~/ 2, // Use fewer workers
      maxFileSizeForMemory: 1024 * 1024, // 1MB threshold
    );
    
    return await _runScanBenchmark(scanner, 'Memory Optimized');
  }

  /// Benchmark standard configuration
  Future<BenchmarkMetrics> _benchmarkMemoryStandard() async {
    print('📊 Benchmarking standard configuration...');
    
    final scanner = AstScannerV3(
      projectPath: projectPath,
      config: config,
      enableParallelProcessing: true,
      enableIncrementalScanning: false,
      enableLazyLoading: false,
      enableAggressiveCaching: false,
    );
    
    return await _runScanBenchmark(scanner, 'Standard');
  }

  /// Run a scan benchmark and collect metrics
  Future<BenchmarkMetrics> _runScanBenchmark(AstScannerV3 scanner, String name) async {
    final memoryBefore = ProcessInfo.currentRss;
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await scanner.scan();
      stopwatch.stop();
      
      final memoryAfter = ProcessInfo.currentRss;
      final memoryUsed = memoryAfter - memoryBefore;
      
      final performance = result.metrics.dependencyTree?['performance'] as Map<String, dynamic>? ?? {};
      
      final metrics = BenchmarkMetrics(
        name: name,
        totalTimeMs: stopwatch.elapsedMilliseconds,
        filesScanned: result.metrics.scannedFiles,
        keysFound: result.keyUsages.length,
        memoryUsedMB: memoryUsed / (1024 * 1024),
        filesPerSecond: double.tryParse(performance['files_per_second']?.toString() ?? '0') ?? 0,
        keysPerSecond: double.tryParse(performance['keys_per_second']?.toString() ?? '0') ?? 0,
        cacheHitRate: double.tryParse(
          performance['cache_hit_rate']?.toString().replaceAll('%', '') ?? '0'
        ) ?? 0,
        parallelFilesProcessed: performance['files_processed_parallel'] ?? 0,
        errors: result.metrics.errors.length,
      );
      
      print('  ✅ $name: ${metrics.totalTimeMs}ms, ${metrics.filesPerSecond.toStringAsFixed(1)} files/sec');
      return metrics;
      
    } catch (e) {
      stopwatch.stop();
      print('  ❌ $name failed: $e');
      
      return BenchmarkMetrics(
        name: name,
        totalTimeMs: stopwatch.elapsedMilliseconds,
        filesScanned: 0,
        keysFound: 0,
        memoryUsedMB: 0,
        filesPerSecond: 0,
        keysPerSecond: 0,
        cacheHitRate: 0,
        parallelFilesProcessed: 0,
        errors: 1,
      );
    }
  }

  /// Clear all caches
  Future<void> _clearCache() async {
    try {
      final cacheDir = Directory(path.join(projectPath, '.dart_tool', 'flutter_keycheck'));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cache clear errors
    }
  }

  /// Generate test files for benchmarking
  Future<void> generateTestFiles(int count, {int avgSizeKB = 10}) async {
    final testDir = Directory(path.join(projectPath, 'benchmark_test'));
    await testDir.create(recursive: true);
    
    print('🔧 Generating $count test files (avg ${avgSizeKB}KB each)...');
    
    for (int i = 0; i < count; i++) {
      final file = File(path.join(testDir.path, 'test_file_$i.dart'));
      final content = _generateDartContent(avgSizeKB * 1024);
      await file.writeAsString(content);
    }
    
    print('✅ Generated $count test files in ${testDir.path}');
  }

  /// Generate dart content with specified size
  String _generateDartContent(int targetBytes) {
    final buffer = StringBuffer();
    final random = Random();
    
    buffer.writeln('import \'package:flutter/material.dart\';');
    buffer.writeln();
    buffer.writeln('class TestWidget extends StatelessWidget {');
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return Column(');
    buffer.writeln('      children: [');
    
    int currentBytes = buffer.toString().length;
    int keyCount = 0;
    
    while (currentBytes < targetBytes) {
      final hasKey = random.nextBool() && keyCount < 50;
      final keyPart = hasKey ? 'key: ValueKey(\'test_key_${keyCount++}\'), ' : '';
      
      final widgets = [
        '        Container($keyPart child: Text(\'Hello World\')),',
        '        ElevatedButton($keyPart onPressed: () {}, child: Text(\'Button\')),',
        '        TextField($keyPart decoration: InputDecoration(hintText: \'Input\')),',
        '        ListTile($keyPart title: Text(\'List Item\')),',
        '        Card($keyPart child: Padding(padding: EdgeInsets.all(8), child: Text(\'Card Content\'))),',
      ];
      
      final widget = widgets[random.nextInt(widgets.length)];
      buffer.writeln(widget);
      currentBytes = buffer.toString().length;
    }
    
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');
    
    return buffer.toString();
  }
}

/// Benchmark metrics for a single test
class BenchmarkMetrics {
  final String name;
  final int totalTimeMs;
  final int filesScanned;
  final int keysFound;
  final double memoryUsedMB;
  final double filesPerSecond;
  final double keysPerSecond;
  final double cacheHitRate;
  final int parallelFilesProcessed;
  final int errors;

  BenchmarkMetrics({
    required this.name,
    required this.totalTimeMs,
    required this.filesScanned,
    required this.keysFound,
    required this.memoryUsedMB,
    required this.filesPerSecond,
    required this.keysPerSecond,
    required this.cacheHitRate,
    required this.parallelFilesProcessed,
    required this.errors,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'total_time_ms': totalTimeMs,
      'files_scanned': filesScanned,
      'keys_found': keysFound,
      'memory_used_mb': memoryUsedMB.toStringAsFixed(2),
      'files_per_second': filesPerSecond.toStringAsFixed(1),
      'keys_per_second': keysPerSecond.toStringAsFixed(1),
      'cache_hit_rate': cacheHitRate.toStringAsFixed(1) + '%',
      'parallel_files_processed': parallelFilesProcessed,
      'errors': errors,
    };
  }
}

/// Complete benchmark result
class BenchmarkResult {
  final Map<String, BenchmarkMetrics> results;
  
  BenchmarkResult(this.results);

  /// Generate a performance report
  void printReport() {
    print('\n📊 Performance Benchmark Report');
    print('=' * 50);
    
    // Performance comparison
    final baseline = results['sequential'];
    if (baseline != null) {
      print('\nPerformance Improvements vs Sequential:');
      for (final entry in results.entries) {
        if (entry.key == 'sequential') continue;
        
        final improvement = _calculateImprovement(baseline, entry.value);
        print('  ${entry.key}: ${improvement}x faster');
      }
    }
    
    // Detailed metrics
    print('\nDetailed Metrics:');
    print('Name'.padRight(20) + 'Time(ms)'.padRight(10) + 'Files/sec'.padRight(12) + 'Cache Hit'.padRight(12) + 'Memory(MB)');
    print('-' * 66);
    
    for (final metrics in results.values) {
      print(
        metrics.name.padRight(20) +
        metrics.totalTimeMs.toString().padRight(10) +
        metrics.filesPerSecond.toStringAsFixed(1).padRight(12) +
        '${metrics.cacheHitRate.toStringAsFixed(1)}%'.padRight(12) +
        metrics.memoryUsedMB.toStringAsFixed(1)
      );
    }
    
    // Performance targets validation
    print('\n🎯 Performance Target Validation:');
    _validateTargets();
  }

  /// Calculate performance improvement ratio
  double _calculateImprovement(BenchmarkMetrics baseline, BenchmarkMetrics comparison) {
    if (comparison.totalTimeMs == 0) return 0;
    return baseline.totalTimeMs / comparison.totalTimeMs;
  }

  /// Validate against performance targets
  void _validateTargets() {
    final targets = {
      'small_project_time': 500, // ms for <100 files
      'medium_project_time': 2000, // ms for 100-1000 files  
      'large_project_time': 10000, // ms for >1000 files
      'memory_limit': 500, // MB
      'files_per_second_min': 500,
      'keys_per_second_min': 10000,
      'cache_hit_rate_min': 80, // %
    };
    
    for (final entry in results.entries) {
      final metrics = entry.value;
      
      print('  ${entry.key}:');
      
      // Time targets (based on file count)
      if (metrics.filesScanned < 100) {
        final target = targets['small_project_time']!;
        final status = metrics.totalTimeMs <= target ? '✅' : '❌';
        print('    Time: $status ${metrics.totalTimeMs}ms (target: ≤${target}ms)');
      } else if (metrics.filesScanned <= 1000) {
        final target = targets['medium_project_time']!;
        final status = metrics.totalTimeMs <= target ? '✅' : '❌';
        print('    Time: $status ${metrics.totalTimeMs}ms (target: ≤${target}ms)');
      } else {
        final target = targets['large_project_time']!;
        final status = metrics.totalTimeMs <= target ? '✅' : '❌';
        print('    Time: $status ${metrics.totalTimeMs}ms (target: ≤${target}ms)');
      }
      
      // Memory target
      final memStatus = metrics.memoryUsedMB <= targets['memory_limit']! ? '✅' : '❌';
      print('    Memory: $memStatus ${metrics.memoryUsedMB.toStringAsFixed(1)}MB (target: ≤${targets['memory_limit']}MB)');
      
      // Performance targets
      final filesPerfStatus = metrics.filesPerSecond >= targets['files_per_second_min']! ? '✅' : '❌';
      print('    Files/sec: $filesPerfStatus ${metrics.filesPerSecond.toStringAsFixed(1)} (target: ≥${targets['files_per_second_min']})');
      
      final keysPerfStatus = metrics.keysPerSecond >= targets['keys_per_second_min']! ? '✅' : '❌';
      print('    Keys/sec: $keysPerfStatus ${metrics.keysPerSecond.toStringAsFixed(1)} (target: ≥${targets['keys_per_second_min']})');
      
      // Cache performance (if applicable)
      if (metrics.cacheHitRate > 0) {
        final cacheStatus = metrics.cacheHitRate >= targets['cache_hit_rate_min']! ? '✅' : '❌';
        print('    Cache hit rate: $cacheStatus ${metrics.cacheHitRate.toStringAsFixed(1)}% (target: ≥${targets['cache_hit_rate_min']}%)');
      }
    }
  }

  /// Export results to JSON
  Future<void> exportToJson(String filePath) async {
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'cpu_cores': Platform.numberOfProcessors,
      'results': results.map((k, v) => MapEntry(k, v.toMap())),
    };
    
    final file = File(filePath);
    await file.writeAsString(json.encode(data));
    print('📄 Benchmark results exported to: $filePath');
  }
}