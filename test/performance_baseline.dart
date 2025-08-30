#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;

/// Performance baseline profiler for flutter_keycheck
/// Measures runtime, memory usage, and output size
class PerformanceProfiler {
  static const int runCount = 5;
  static const double regressionThreshold = 0.20; // 20% regression threshold
  
  final String projectRoot;
  final String targetProject;
  final String baselineFile;
  
  PerformanceProfiler({
    required this.projectRoot,
    required this.targetProject,
    required this.baselineFile,
  });
  
  /// Run performance profiling and generate baseline
  Future<Map<String, dynamic>> profile() async {
    print('🎯 Starting performance profiling of flutter_keycheck');
    print('   Target: $targetProject');
    print('   Runs: $runCount');
    print('');
    
    final runs = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= runCount; i++) {
      print('📊 Run $i/$runCount...');
      final metrics = await _runSingleProfile();
      runs.add(metrics);
      
      print('   Runtime: ${metrics['runtime_ms']}ms');
      print('   Peak RSS: ${metrics['peak_rss_mb']}MB');
      print('   JSON size: ${metrics['json_size_kb']}KB');
      print('');
      
      // Brief pause between runs
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    // Calculate averages and statistics
    final baseline = _calculateBaseline(runs);
    
    // Add metadata
    baseline['metadata'] = {
      'timestamp': DateTime.now().toIso8601String(),
      'dart_version': Platform.version,
      'platform': Platform.operatingSystem,
      'target_project': targetProject,
      'run_count': runCount,
    };
    
    return baseline;
  }
  
  /// Run a single profiling iteration
  Future<Map<String, dynamic>> _runSingleProfile() async {
    final stopwatch = Stopwatch()..start();
    final tempOutDir = path.join(Directory.systemTemp.path, 
        'keycheck_perf_${DateTime.now().millisecondsSinceEpoch}');
    
    try {
      // Start the process with v3 command structure
      // Note: output goes to out-dir/key-snapshot.json by default
      await Directory(tempOutDir).create(recursive: true);
      
      final process = await Process.start(
        'dart',
        [
          'run',
          path.join(projectRoot, 'bin', 'flutter_keycheck.dart'),
          'scan',  // Use scan subcommand
          '--project-root', targetProject,
          '--report', 'json',
          '--out-dir', tempOutDir,
        ],
        workingDirectory: projectRoot,
      );
      
      // Monitor memory usage
      final memoryMonitor = _MonitorMemory(process.pid);
      final memoryFuture = memoryMonitor.start();
      
      // Capture output
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      
      process.stdout.transform(utf8.decoder).listen(stdout.write);
      process.stderr.transform(utf8.decoder).listen(stderr.write);
      
      // Wait for completion
      final exitCode = await process.exitCode;
      stopwatch.stop();
      
      // Stop memory monitoring
      memoryMonitor.stop();
      final peakMemory = await memoryFuture;
      
      if (exitCode != 0) {
        throw Exception('Scanner failed with exit code $exitCode\n'
            'stdout: $stdout\n'
            'stderr: $stderr');
      }
      
      // Parse JSON output (scanner creates key-snapshot.json in out-dir)
      final jsonFile = File(path.join(tempOutDir, 'key-snapshot.json'));
      if (!jsonFile.existsSync()) {
        throw Exception('JSON output file not created at ${jsonFile.path}');
      }
      
      final jsonContent = jsonFile.readAsStringSync();
      final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;
      final jsonSizeKb = (jsonFile.lengthSync() / 1024).toStringAsFixed(2);
      
      // Extract metrics from JSON
      // The scanResult field contains a JSON string that needs to be parsed
      int fileCount = 0;
      int keyCount = 0;
      
      if (jsonData['scanResult'] != null && jsonData['scanResult'] is String) {
        final scanResult = jsonDecode(jsonData['scanResult'] as String) as Map<String, dynamic>;
        fileCount = scanResult['metrics']?['total_files'] ?? 0;
        keyCount = (scanResult['keys'] as List?)?.length ?? 0;
      }
      
      return {
        'runtime_ms': stopwatch.elapsedMilliseconds,
        'peak_rss_mb': peakMemory,
        'json_size_kb': double.parse(jsonSizeKb),
        'files_scanned': fileCount,
        'keys_found': keyCount,
      };
    } finally {
      // Cleanup
      try {
        if (await Directory(tempOutDir).exists()) {
          await Directory(tempOutDir).delete(recursive: true);
        }
      } catch (_) {}
    }
  }
  
  /// Calculate baseline metrics from multiple runs
  Map<String, dynamic> _calculateBaseline(List<Map<String, dynamic>> runs) {
    final runtimes = runs.map((r) => r['runtime_ms'] as int).toList();
    final memories = runs.map((r) => r['peak_rss_mb'] as double).toList();
    final sizes = runs.map((r) => r['json_size_kb'] as double).toList();
    final files = runs.map((r) => r['files_scanned'] as int).toList();
    final keys = runs.map((r) => r['keys_found'] as int).toList();
    
    return {
      'metrics': {
        'runtime_ms': {
          'mean': _mean(runtimes),
          'median': _median(runtimes),
          'stddev': _stddev(runtimes),
          'min': runtimes.reduce(min),
          'max': runtimes.reduce(max),
        },
        'peak_rss_mb': {
          'mean': _mean(memories),
          'median': _median(memories),
          'stddev': _stddev(memories),
          'min': memories.reduce(min),
          'max': memories.reduce(max),
        },
        'json_size_kb': {
          'mean': _mean(sizes),
          'median': _median(sizes),
          'stddev': _stddev(sizes),
          'min': sizes.reduce(min),
          'max': sizes.reduce(max),
        },
        'files_scanned': files.first, // Should be constant
        'keys_found': keys.first, // Should be constant
      },
      'raw_runs': runs,
    };
  }
  
  /// Save baseline to file
  Future<void> saveBaseline(Map<String, dynamic> baseline) async {
    final file = File(baselineFile);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(baseline),
    );
    print('✅ Baseline saved to: $baselineFile');
  }
  
  /// Load existing baseline
  Future<Map<String, dynamic>?> loadBaseline() async {
    final file = File(baselineFile);
    if (!file.existsSync()) {
      return null;
    }
    
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }
  
  /// Compare current metrics against baseline
  Future<bool> checkRegression(Map<String, dynamic> current) async {
    final baseline = await loadBaseline();
    if (baseline == null) {
      print('⚠️  No baseline found. This run will establish the baseline.');
      return true;
    }
    
    print('📊 Regression Analysis');
    print('═════════════════════\n');
    
    bool hasRegression = false;
    final currentMetrics = current['metrics'] as Map<String, dynamic>;
    final baselineMetrics = baseline['metrics'] as Map<String, dynamic>;
    
    // Check runtime regression
    final runtimeRegression = _checkMetricRegression(
      'Runtime',
      baselineMetrics['runtime_ms']['mean'],
      currentMetrics['runtime_ms']['mean'],
      'ms',
    );
    hasRegression = hasRegression || runtimeRegression;
    
    // Check memory regression
    final memoryRegression = _checkMetricRegression(
      'Peak RSS Memory',
      baselineMetrics['peak_rss_mb']['mean'],
      currentMetrics['peak_rss_mb']['mean'],
      'MB',
    );
    hasRegression = hasRegression || memoryRegression;
    
    // Check JSON size regression
    final sizeRegression = _checkMetricRegression(
      'JSON Output Size',
      baselineMetrics['json_size_kb']['mean'],
      currentMetrics['json_size_kb']['mean'],
      'KB',
    );
    hasRegression = hasRegression || sizeRegression;
    
    print('');
    if (hasRegression) {
      print('❌ REGRESSION DETECTED: Performance degraded >20%');
      return false;
    } else {
      print('✅ PASS: Performance within acceptable bounds');
      return true;
    }
  }
  
  /// Check individual metric regression
  bool _checkMetricRegression(
    String name,
    dynamic baselineValue,
    dynamic currentValue,
    String unit,
  ) {
    final baseline = baselineValue is int ? baselineValue.toDouble() : baselineValue as double;
    final current = currentValue is int ? currentValue.toDouble() : currentValue as double;
    final difference = current - baseline;
    final percentChange = (difference / baseline) * 100;
    
    final symbol = percentChange > 0 ? '↑' : '↓';
    final status = percentChange > regressionThreshold * 100 ? '❌' : '✅';
    
    print('$status $name:');
    print('   Baseline: ${baseline.toStringAsFixed(2)} $unit');
    print('   Current:  ${current.toStringAsFixed(2)} $unit');
    print('   Change:   ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(2)} $unit '
          '($symbol ${percentChange.abs().toStringAsFixed(1)}%)');
    
    return percentChange > regressionThreshold * 100;
  }
  
  // Statistical helper functions
  double _mean(List<num> values) {
    if (values.isEmpty) return 0.0;
    num sum = 0;
    for (final value in values) {
      sum += value;
    }
    return sum / values.length;
  }
  
  double _median(List<num> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
    return sorted[middle].toDouble();
  }
  
  double _stddev(List<num> values) {
    if (values.isEmpty) return 0.0;
    final mean = _mean(values);
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    num variance = 0;
    for (final diff in squaredDiffs) {
      variance += diff;
    }
    variance = variance / values.length;
    return sqrt(variance);
  }
}

/// Memory monitor for Linux systems
class _MonitorMemory {
  final int pid;
  bool _running = true;
  
  _MonitorMemory(this.pid);
  
  void stop() {
    _running = false;
  }
  
  Future<double> start() async {
    double peakRss = 0;
    
    // For Linux, read from /proc/[pid]/status
    if (Platform.isLinux) {
      while (_running) {
        try {
          final statusFile = File('/proc/$pid/status');
          if (!statusFile.existsSync()) break;
          
          final content = await statusFile.readAsString();
          final vmRssMatch = RegExp(r'VmRSS:\s+(\d+)\s+kB').firstMatch(content);
          
          if (vmRssMatch != null) {
            final rssMb = int.parse(vmRssMatch.group(1)!) / 1024;
            peakRss = max(peakRss, rssMb);
          }
        } catch (_) {
          // Process might have ended
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 50));
      }
    } else {
      // For non-Linux, estimate based on heap usage (less accurate)
      // In production, you'd use platform-specific tools
      peakRss = 50.0; // Placeholder estimate
    }
    
    return peakRss;
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  final projectRoot = path.dirname(path.dirname(Platform.script.toFilePath()));
  final targetProject = path.join(projectRoot, 'example', 'flutter_casino_demo');
  final baselineFile = path.join(projectRoot, 'performance_baseline.json');
  
  // Check if we're in comparison mode
  final isCompareMode = args.contains('--compare');
  
  final profiler = PerformanceProfiler(
    projectRoot: projectRoot,
    targetProject: targetProject,
    baselineFile: baselineFile,
  );
  
  if (isCompareMode) {
    // Run comparison against baseline
    print('🔍 Running regression check...\n');
    final current = await profiler.profile();
    
    print('\n' + '═' * 50 + '\n');
    
    final passed = await profiler.checkRegression(current);
    
    if (!passed) {
      exit(1); // Exit with error for CI
    }
  } else {
    // Generate new baseline
    print('🚀 Generating performance baseline...\n');
    
    final baseline = await profiler.profile();
    
    print('\n' + '═' * 50);
    print('📈 Performance Baseline Summary');
    print('═' * 50 + '\n');
    
    final metrics = baseline['metrics'] as Map<String, dynamic>;
    
    print('Runtime Statistics:');
    print('  Mean:   ${metrics['runtime_ms']['mean'].toStringAsFixed(2)}ms');
    print('  Median: ${metrics['runtime_ms']['median'].toStringAsFixed(2)}ms');
    print('  StdDev: ${metrics['runtime_ms']['stddev'].toStringAsFixed(2)}ms');
    print('  Range:  ${metrics['runtime_ms']['min']}-${metrics['runtime_ms']['max']}ms');
    print('');
    
    print('Memory Statistics:');
    print('  Mean:   ${metrics['peak_rss_mb']['mean'].toStringAsFixed(2)}MB');
    print('  Median: ${metrics['peak_rss_mb']['median'].toStringAsFixed(2)}MB');
    print('  StdDev: ${metrics['peak_rss_mb']['stddev'].toStringAsFixed(2)}MB');
    print('  Range:  ${metrics['peak_rss_mb']['min'].toStringAsFixed(2)}-${metrics['peak_rss_mb']['max'].toStringAsFixed(2)}MB');
    print('');
    
    print('Output Statistics:');
    print('  Mean:   ${metrics['json_size_kb']['mean'].toStringAsFixed(2)}KB');
    print('  Median: ${metrics['json_size_kb']['median'].toStringAsFixed(2)}KB');
    print('  StdDev: ${metrics['json_size_kb']['stddev'].toStringAsFixed(2)}KB');
    print('');
    
    print('Scan Statistics:');
    print('  Files scanned: ${metrics['files_scanned']}');
    print('  Keys found:    ${metrics['keys_found']}');
    print('');
    
    await profiler.saveBaseline(baseline);
  }
}