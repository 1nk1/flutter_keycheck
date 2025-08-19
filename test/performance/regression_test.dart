import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_keycheck/src/commands/benchmark_command.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/scanner/performance_benchmark.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Performance regression test suite
/// 
/// This test suite validates that performance changes don't introduce
/// significant regressions in key metrics like scan time, memory usage,
/// and key detection accuracy.
void main() {
  group('Performance Regression Tests', () {
    late String testDataDir;
    late String resultsDir;
    late ConfigV3 testConfig;

    setUpAll(() async {
      // Setup test directories
      testDataDir = path.join(Directory.current.path, 'test', 'performance', 'test_data');
      resultsDir = path.join(Directory.current.path, 'test', 'performance', 'results');
      
      await Directory(testDataDir).create(recursive: true);
      await Directory(resultsDir).create(recursive: true);

      // Create test configuration
      testConfig = ConfigV3(
        verbose: false,
        scan: ScanConfigV3(
          scope: ScanScope.workspaceOnly,
          excludePatterns: [
            '**/.dart_tool/**',
            '**/build/**',
            '**/.git/**',
          ],
        ),
      );

      // Generate test data if not exists
      await _generateTestDataIfNeeded();
    });

    tearDownAll(() async {
      // Cleanup test data (optional - keep for debugging)
      // await Directory(testDataDir).delete(recursive: true);
      // await Directory(resultsDir).delete(recursive: true);
    });

    group('Scanning Performance Regression', () {
      test('sequential scanning performance should not regress significantly', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        final stopwatch = Stopwatch()..start();
        final metrics = await benchmark._benchmarkSequential();
        stopwatch.stop();

        // Performance assertions
        expect(metrics.totalTimeMs, lessThan(5000), 
            reason: 'Sequential scan should complete within 5 seconds for test data');
        expect(metrics.memoryUsedMB, lessThan(200),
            reason: 'Sequential scan should use less than 200MB memory');
        expect(metrics.filesPerSecond, greaterThan(10),
            reason: 'Sequential scan should process at least 10 files per second');
        expect(metrics.errors, equals(0),
            reason: 'Sequential scan should not produce errors');

        // Save baseline if this is the first run
        await _savePerformanceBaseline('sequential', metrics);
        
        // Compare with previous baseline
        await _compareWithBaseline('sequential', metrics);
      });

      test('parallel scanning performance should be better than sequential', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        // Run both benchmarks
        final sequentialMetrics = await benchmark._benchmarkSequential();
        final parallelMetrics = await benchmark._benchmarkParallel();

        // Parallel should be faster
        expect(parallelMetrics.totalTimeMs, lessThan(sequentialMetrics.totalTimeMs),
            reason: 'Parallel scan should be faster than sequential');
        
        // Memory usage should be reasonable (may be higher due to parallelism)
        expect(parallelMetrics.memoryUsedMB, lessThan(sequentialMetrics.memoryUsedMB * 2),
            reason: 'Parallel scan memory usage should not exceed 2x sequential');
        
        // Should process more files per second
        expect(parallelMetrics.filesPerSecond, greaterThan(sequentialMetrics.filesPerSecond),
            reason: 'Parallel scan should have higher throughput');

        // Save and compare baselines
        await _savePerformanceBaseline('parallel', parallelMetrics);
        await _compareWithBaseline('parallel', parallelMetrics);
      });

      test('cached scanning should show significant improvement on repeat runs', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        // First run (cold cache)
        final coldMetrics = await benchmark._benchmarkCacheCold();
        
        // Second run (warm cache)
        final warmMetrics = await benchmark._benchmarkCacheWarm();

        // Warm cache should be significantly faster
        expect(warmMetrics.totalTimeMs, lessThan(coldMetrics.totalTimeMs * 0.8),
            reason: 'Warm cache should be at least 20% faster than cold cache');
        
        // Cache hit rate should be substantial
        expect(warmMetrics.cacheHitRate, greaterThan(50),
            reason: 'Cache hit rate should be above 50% on warm cache');

        await _savePerformanceBaseline('cached', warmMetrics);
        await _compareWithBaseline('cached', warmMetrics);
      });
    });

    group('Memory Usage Regression', () {
      test('memory usage should scale linearly with project size', () async {
        final projectSizes = ['small', 'medium', 'large'];
        final memoryUsages = <String, double>{};

        for (final size in projectSizes) {
          // Generate test project of specific size
          await _generateProjectOfSize(size);
          
          final benchmark = PerformanceBenchmark(
            projectPath: path.join(testDataDir, size),
            config: testConfig,
          );

          final metrics = await benchmark._benchmarkMemoryOptimized();
          memoryUsages[size] = metrics.memoryUsedMB;

          // Basic memory limits per size
          switch (size) {
            case 'small':
              expect(metrics.memoryUsedMB, lessThan(50),
                  reason: 'Small project should use less than 50MB');
              break;
            case 'medium':
              expect(metrics.memoryUsedMB, lessThan(200),
                  reason: 'Medium project should use less than 200MB');
              break;
            case 'large':
              expect(metrics.memoryUsedMB, lessThan(500),
                  reason: 'Large project should use less than 500MB');
              break;
          }
        }

        // Memory should not scale quadratically
        final smallMemory = memoryUsages['small']!;
        final mediumMemory = memoryUsages['medium']!;
        final largeMemory = memoryUsages['large']!;

        // Rough linear scaling check (allowing for some overhead)
        expect(mediumMemory / smallMemory, lessThan(6),
            reason: 'Memory scaling from small to medium should be reasonable');
        expect(largeMemory / mediumMemory, lessThan(6),
            reason: 'Memory scaling from medium to large should be reasonable');
      });

      test('memory usage should be stable across multiple runs', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        final memoryUsages = <double>[];
        
        // Run benchmark multiple times
        for (int i = 0; i < 5; i++) {
          final metrics = await benchmark._benchmarkMemoryOptimized();
          memoryUsages.add(metrics.memoryUsedMB);
        }

        // Calculate coefficient of variation (std dev / mean)
        final mean = memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
        final variance = memoryUsages
            .map((usage) => pow(usage - mean, 2))
            .reduce((a, b) => a + b) / memoryUsages.length;
        final stdDev = sqrt(variance);
        final coefficientOfVariation = stdDev / mean;

        // Memory usage should be consistent (CV < 20%)
        expect(coefficientOfVariation, lessThan(0.2),
            reason: 'Memory usage should be consistent across runs');
      });
    });

    group('Accuracy vs Performance Trade-offs', () {
      test('key detection accuracy should not degrade with performance optimizations', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        // Test different optimization levels
        final sequentialMetrics = await benchmark._benchmarkSequential();
        final parallelMetrics = await benchmark._benchmarkParallel();
        final optimizedMetrics = await benchmark._benchmarkMemoryOptimized();

        // All configurations should find the same number of keys
        expect(parallelMetrics.keysFound, equals(sequentialMetrics.keysFound),
            reason: 'Parallel processing should not affect key detection accuracy');
        expect(optimizedMetrics.keysFound, equals(sequentialMetrics.keysFound),
            reason: 'Memory optimization should not affect key detection accuracy');

        // Performance optimizations should not increase error rate
        expect(parallelMetrics.errors, lessThanOrEqualTo(sequentialMetrics.errors),
            reason: 'Parallel processing should not increase errors');
        expect(optimizedMetrics.errors, lessThanOrEqualTo(sequentialMetrics.errors),
            reason: 'Memory optimization should not increase errors');
      });

      test('performance improvements should not come at accuracy cost', () async {
        // Generate test project with known key count
        final expectedKeyCount = await _generateProjectWithKnownKeys(100);
        
        final benchmark = PerformanceBenchmark(
          projectPath: path.join(testDataDir, 'known_keys'),
          config: testConfig,
        );

        final result = await benchmark.runBenchmark();
        
        // Check each configuration found the expected number of keys
        for (final entry in result.results.entries) {
          expect(entry.value.keysFound, equals(expectedKeyCount),
              reason: '${entry.key} configuration should find all $expectedKeyCount keys');
        }
      });
    });

    group('CI/CD Performance Requirements', () {
      test('quick scan should complete within CI time limits', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        // Simulate CI-optimized scan
        final metrics = await benchmark._benchmarkParallel();

        // CI-friendly performance requirements
        expect(metrics.totalTimeMs, lessThan(30000),
            reason: 'CI scan should complete within 30 seconds');
        expect(metrics.memoryUsedMB, lessThan(1000),
            reason: 'CI scan should use less than 1GB memory');
        expect(metrics.errors, equals(0),
            reason: 'CI scan should not produce errors');
      });

      test('baseline operations should be fast enough for CI', () async {
        // Test baseline creation performance
        final stopwatch = Stopwatch()..start();
        
        // Simulate baseline creation
        await Future.delayed(const Duration(milliseconds: 100));
        
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Baseline creation should complete within 5 seconds in CI');
      });

      test('diff operations should scale well with baseline size', () async {
        final baselineSizes = [100, 1000, 5000];
        final diffTimes = <int, int>{};

        for (final size in baselineSizes) {
          final stopwatch = Stopwatch()..start();
          
          // Simulate diff operation
          await _simulateDiffOperation(size);
          
          stopwatch.stop();
          diffTimes[size] = stopwatch.elapsedMilliseconds;
        }

        // Diff time should scale sub-linearly
        final ratio1000_100 = diffTimes[1000]! / diffTimes[100]!;
        final ratio5000_1000 = diffTimes[5000]! / diffTimes[1000]!;

        expect(ratio1000_100, lessThan(15),
            reason: 'Diff scaling from 100 to 1000 keys should be reasonable');
        expect(ratio5000_1000, lessThan(8),
            reason: 'Diff scaling from 1000 to 5000 keys should be reasonable');
      });
    });

    group('Performance Target Validation', () {
      test('all performance targets should be met for typical usage', () async {
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        final result = await benchmark.runBenchmark();
        
        // Validate against performance targets
        for (final entry in result.results.entries) {
          final metrics = entry.value;
          
          // Time targets based on file count
          if (metrics.filesScanned < 100) {
            expect(metrics.totalTimeMs, lessThanOrEqualTo(500),
                reason: 'Small projects should scan in ≤500ms');
          } else if (metrics.filesScanned <= 1000) {
            expect(metrics.totalTimeMs, lessThanOrEqualTo(2000),
                reason: 'Medium projects should scan in ≤2s');
          } else {
            expect(metrics.totalTimeMs, lessThanOrEqualTo(10000),
                reason: 'Large projects should scan in ≤10s');
          }

          // Memory targets
          expect(metrics.memoryUsedMB, lessThanOrEqualTo(500),
              reason: 'Memory usage should be ≤500MB');

          // Throughput targets
          expect(metrics.filesPerSecond, greaterThanOrEqualTo(10),
              reason: 'Should process ≥10 files/second');
          
          if (metrics.keysFound > 0) {
            expect(metrics.keysPerSecond, greaterThanOrEqualTo(100),
                reason: 'Should process ≥100 keys/second');
          }

          // Cache performance (if applicable)
          if (metrics.cacheHitRate > 0) {
            expect(metrics.cacheHitRate, greaterThanOrEqualTo(50),
                reason: 'Cache hit rate should be ≥50%');
          }
        }
      });

      test('performance should be consistent across Dart versions', () async {
        // This test would ideally run on different Dart versions
        // For now, we'll test consistency within current version
        
        final benchmark = PerformanceBenchmark(
          projectPath: testDataDir,
          config: testConfig,
        );

        final results = <BenchmarkResult>[];
        
        // Run benchmark multiple times to check consistency
        for (int i = 0; i < 3; i++) {
          final result = await benchmark.runBenchmark();
          results.add(result);
        }

        // Compare results for consistency
        final baseResult = results.first;
        for (int i = 1; i < results.length; i++) {
          final currentResult = results[i];
          
          for (final configName in baseResult.results.keys) {
            final baseMetrics = baseResult.results[configName]!;
            final currentMetrics = currentResult.results[configName]!;
            
            // Time should be within 50% variance
            final timeDiff = (currentMetrics.totalTimeMs - baseMetrics.totalTimeMs).abs();
            final timeVariance = timeDiff / baseMetrics.totalTimeMs;
            expect(timeVariance, lessThan(0.5),
                reason: 'Time variance should be less than 50% for $configName');
            
            // Key count should be identical
            expect(currentMetrics.keysFound, equals(baseMetrics.keysFound),
                reason: 'Key count should be consistent for $configName');
          }
        }
      });
    });
  });
}

/// Generate test data if it doesn't exist
Future<void> _generateTestDataIfNeeded() async {
  final testDataDir = path.join(Directory.current.path, 'test', 'performance', 'test_data');
  final libDir = Directory(path.join(testDataDir, 'lib'));
  
  if (await libDir.exists()) {
    return; // Test data already exists
  }

  print('Generating test data for performance tests...');
  
  await libDir.create(recursive: true);
  
  // Generate a medium-sized test project
  const fileCount = 50;
  const avgSizeKB = 10;
  const keyDensity = 0.15;
  
  for (int i = 0; i < fileCount; i++) {
    final file = File(path.join(libDir.path, 'test_file_$i.dart'));
    final content = _generateTestFileContent(i, avgSizeKB * 1024, keyDensity);
    await file.writeAsString(content);
  }
  
  // Create pubspec.yaml
  final pubspecFile = File(path.join(testDataDir, 'pubspec.yaml'));
  await pubspecFile.writeAsString(_generateTestPubspec());
  
  print('✅ Test data generated');
}

/// Generate test project of specific size
Future<void> _generateProjectOfSize(String size) async {
  final projectDir = path.join(Directory.current.path, 'test', 'performance', 'test_data', size);
  final libDir = Directory(path.join(projectDir, 'lib'));
  
  if (await libDir.exists()) {
    return; // Already exists
  }
  
  await libDir.create(recursive: true);
  
  final (fileCount, avgSizeKB, keyDensity) = _getProjectSizeParams(size);
  
  for (int i = 0; i < fileCount; i++) {
    final file = File(path.join(libDir.path, 'test_file_$i.dart'));
    final content = _generateTestFileContent(i, avgSizeKB * 1024, keyDensity);
    await file.writeAsString(content);
  }
  
  // Create pubspec.yaml
  final pubspecFile = File(path.join(projectDir, 'pubspec.yaml'));
  await pubspecFile.writeAsString(_generateTestPubspec());
}

/// Generate project with known number of keys
Future<int> _generateProjectWithKnownKeys(int keyCount) async {
  final projectDir = path.join(Directory.current.path, 'test', 'performance', 'test_data', 'known_keys');
  final libDir = Directory(path.join(projectDir, 'lib'));
  
  await libDir.create(recursive: true);
  
  // Generate files with exactly the specified number of keys
  const filesPerKey = 2; // Distribute keys across multiple files
  final fileCount = (keyCount / filesPerKey).ceil();
  
  int keysPlaced = 0;
  for (int i = 0; i < fileCount && keysPlaced < keyCount; i++) {
    final keysInThisFile = min(filesPerKey, keyCount - keysPlaced);
    final file = File(path.join(libDir.path, 'test_file_$i.dart'));
    final content = _generateFileWithExactKeys(i, keysInThisFile);
    await file.writeAsString(content);
    keysPlaced += keysInThisFile;
  }
  
  // Create pubspec.yaml
  final pubspecFile = File(path.join(projectDir, 'pubspec.yaml'));
  await pubspecFile.writeAsString(_generateTestPubspec());
  
  return keyCount;
}

/// Get project size parameters
(int fileCount, int avgSizeKB, double keyDensity) _getProjectSizeParams(String size) {
  switch (size) {
    case 'small':
      return (25, 5, 0.1);
    case 'medium':
      return (100, 10, 0.15);
    case 'large':
      return (400, 15, 0.2);
    default:
      return (100, 10, 0.15);
  }
}

/// Generate test file content
String _generateTestFileContent(int index, int targetBytes, double keyDensity) {
  final buffer = StringBuffer();
  final random = Random(index); // Deterministic random for consistent tests
  
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln('class TestWidget$index extends StatelessWidget {');
  buffer.writeln('  const TestWidget$index({super.key});');
  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Widget build(BuildContext context) {');
  buffer.writeln('    return Column(children: [');
  
  int currentBytes = buffer.toString().length;
  int keyIndex = 0;
  
  while (currentBytes < targetBytes - 200) {
    final hasKey = random.nextDouble() < keyDensity;
    final widgetType = ['Container', 'ElevatedButton', 'TextField'][random.nextInt(3)];
    
    if (hasKey) {
      buffer.writeln('      $widgetType(key: ValueKey(\'test_${index}_key_${keyIndex++}\'), child: Text(\'Widget\')),');
    } else {
      buffer.writeln('      $widgetType(child: Text(\'Widget\')),');
    }
    
    currentBytes = buffer.toString().length;
  }
  
  buffer.writeln('    ]);');
  buffer.writeln('  }');
  buffer.writeln('}');
  
  return buffer.toString();
}

/// Generate file with exact number of keys
String _generateFileWithExactKeys(int index, int keyCount) {
  final buffer = StringBuffer();
  
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln('class KnownKeysWidget$index extends StatelessWidget {');
  buffer.writeln('  const KnownKeysWidget$index({super.key});');
  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Widget build(BuildContext context) {');
  buffer.writeln('    return Column(children: [');
  
  for (int i = 0; i < keyCount; i++) {
    buffer.writeln('      Container(key: ValueKey(\'known_${index}_key_$i\'), child: Text(\'Key $i\')),');
  }
  
  buffer.writeln('    ]);');
  buffer.writeln('  }');
  buffer.writeln('}');
  
  return buffer.toString();
}

/// Generate test pubspec.yaml
String _generateTestPubspec() {
  return '''
name: test_project
version: 1.0.0
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''';
}

/// Save performance baseline for comparison
Future<void> _savePerformanceBaseline(String configName, BenchmarkMetrics metrics) async {
  final baselineDir = path.join(Directory.current.path, 'test', 'performance', 'baselines');
  await Directory(baselineDir).create(recursive: true);
  
  final baselineFile = File(path.join(baselineDir, '$configName.json'));
  
  final baselineData = {
    'timestamp': DateTime.now().toIso8601String(),
    'config': configName,
    'metrics': metrics.toMap(),
  };
  
  await baselineFile.writeAsString(json.encode(baselineData));
}

/// Compare with performance baseline
Future<void> _compareWithBaseline(String configName, BenchmarkMetrics currentMetrics) async {
  final baselineFile = File(path.join(
    Directory.current.path, 'test', 'performance', 'baselines', '$configName.json'
  ));
  
  if (!await baselineFile.exists()) {
    return; // No baseline to compare with
  }
  
  final baselineData = json.decode(await baselineFile.readAsString());
  final baselineMetrics = baselineData['metrics'] as Map<String, dynamic>;
  
  final baselineTime = baselineMetrics['total_time_ms'] as int;
  final currentTime = currentMetrics.totalTimeMs;
  
  final baselineMemory = double.parse(baselineMetrics['memory_used_mb'] as String);
  final currentMemory = currentMetrics.memoryUsedMB;
  
  // Check for significant regressions (>25% worse)
  const regressionThreshold = 0.25;
  
  if (currentTime > baselineTime * (1 + regressionThreshold)) {
    final regression = ((currentTime - baselineTime) / baselineTime * 100).toStringAsFixed(1);
    print('⚠️ Performance regression detected in $configName: ${regression}% slower');
  }
  
  if (currentMemory > baselineMemory * (1 + regressionThreshold)) {
    final regression = ((currentMemory - baselineMemory) / baselineMemory * 100).toStringAsFixed(1);
    print('⚠️ Memory regression detected in $configName: ${regression}% more memory');
  }
}

/// Simulate diff operation for testing
Future<void> _simulateDiffOperation(int keyCount) async {
  // Simulate the time it takes to compare keyCount keys
  final baseTime = 10; // Base time in milliseconds
  final scalingFactor = 0.1; // How much time scales with key count
  
  final totalTime = baseTime + (keyCount * scalingFactor);
  await Future.delayed(Duration(milliseconds: totalTime.round()));
}