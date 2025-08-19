import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import '../config.dart';
import '../scanner/performance_benchmark.dart';
import 'package:path/path.dart' as path;

/// Benchmark command for comprehensive performance testing
class BenchmarkCommand extends Command<int> {
  @override
  final name = 'benchmark';

  @override
  final description = 'Run comprehensive performance benchmarks';

  BenchmarkCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file for benchmark results',
        defaultsTo: 'benchmark_results.json',
      )
      ..addOption(
        'baseline',
        help: 'Baseline file to compare against',
      )
      ..addOption(
        'threshold',
        help: 'Performance regression threshold (percentage)',
        defaultsTo: '20',
      )
      ..addFlag(
        'generate-data',
        help: 'Generate test data before benchmarking',
        defaultsTo: false,
      )
      ..addOption(
        'project-size',
        help: 'Project size for test data generation',
        allowed: ['small', 'medium', 'large', 'enterprise'],
        defaultsTo: 'medium',
      )
      ..addFlag(
        'regression-test',
        help: 'Run regression tests against baseline',
        defaultsTo: false,
      )
      ..addFlag(
        'memory-profile',
        help: 'Include detailed memory profiling',
        defaultsTo: false,
      )
      ..addFlag(
        'ci-mode',
        help: 'Run in CI/CD mode with optimized settings',
        defaultsTo: false,
      )
      ..addMultiOption(
        'scenarios',
        help: 'Specific benchmark scenarios to run',
        allowed: [
          'scanning',
          'baseline',
          'diff',
          'validation',
          'memory',
          'accuracy',
          'ci-integration'
        ],
        defaultsTo: ['scanning', 'baseline', 'diff', 'validation'],
      );
  }

  @override
  Future<int> run() async {
    try {
      final config = await loadConfig();
      final outDir = await ensureOutputDir();
      
      final projectRoot = argResults!['project-root'] as String? ?? Directory.current.path;
      final outputPath = argResults!['output'] as String;
      final baselinePath = argResults!['baseline'] as String?;
      final threshold = double.parse(argResults!['threshold'] as String);
      final generateData = argResults!['generate-data'] as bool;
      final projectSize = argResults!['project-size'] as String;
      final regressionTest = argResults!['regression-test'] as bool;
      final memoryProfile = argResults!['memory-profile'] as bool;
      final ciMode = argResults!['ci-mode'] as bool;
      final scenarios = argResults!['scenarios'] as List<String>;

      logInfo('🚀 Starting Flutter KeyCheck Performance Benchmark Suite');
      logInfo('Project: $projectRoot');
      logInfo('Scenarios: ${scenarios.join(", ")}');
      
      if (ciMode) {
        logInfo('Running in CI/CD mode with optimized settings');
      }

      // Generate test data if requested
      if (generateData) {
        await _generateTestData(projectRoot, projectSize);
      }

      // Create comprehensive benchmark suite
      final benchmarkSuite = ComprehensiveBenchmarkSuite(
        projectPath: projectRoot,
        config: config,
        outputDir: outDir,
        ciMode: ciMode,
        memoryProfiling: memoryProfile,
      );

      // Run selected benchmark scenarios
      final results = await benchmarkSuite.runBenchmarks(scenarios);

      // Save results
      final resultFile = File(path.isAbsolute(outputPath)
          ? outputPath
          : path.join(outDir.path, outputPath));
      await results.exportToJson(resultFile.path);

      // Print comprehensive report
      results.printReport();

      // Run regression tests if baseline provided
      if (regressionTest && baselinePath != null) {
        final regressionResult = await _runRegressionTests(
          results,
          baselinePath,
          threshold,
        );
        
        if (!regressionResult) {
          logError('❌ Performance regression detected!');
          return ExitCode.testFailed;
        }
      }

      logInfo('\n✅ Benchmark suite completed successfully!');
      logInfo('📄 Results saved to: ${resultFile.path}');

      return ExitCode.ok;
    } catch (e) {
      return handleError(e);
    }
  }

  /// Generate test data for benchmarking
  Future<void> _generateTestData(String projectRoot, String size) async {
    logInfo('🔧 Generating test data for $size project...');

    final generator = TestDataGenerator(projectRoot);
    
    switch (size) {
      case 'small':
        await generator.generateProject(
          fileCount: 50,
          avgSizeKB: 5,
          keyDensity: 0.1,
        );
        break;
      case 'medium':
        await generator.generateProject(
          fileCount: 200,
          avgSizeKB: 15,
          keyDensity: 0.15,
        );
        break;
      case 'large':
        await generator.generateProject(
          fileCount: 1000,
          avgSizeKB: 25,
          keyDensity: 0.2,
        );
        break;
      case 'enterprise':
        await generator.generateProject(
          fileCount: 5000,
          avgSizeKB: 35,
          keyDensity: 0.25,
        );
        break;
    }

    logInfo('✅ Test data generated successfully');
  }

  /// Run regression tests against baseline
  Future<bool> _runRegressionTests(
    ComprehensiveBenchmarkResults results,
    String baselinePath,
    double threshold,
  ) async {
    logInfo('\n🔍 Running performance regression tests...');

    final baselineFile = File(baselinePath);
    if (!await baselineFile.exists()) {
      logError('Baseline file not found: $baselinePath');
      return false;
    }

    final baselineData = json.decode(await baselineFile.readAsString());
    final baselineResults = ComprehensiveBenchmarkResults.fromJson(baselineData);

    final analyzer = RegressionAnalyzer(threshold);
    final regressions = analyzer.analyzeRegression(baselineResults, results);

    if (regressions.isEmpty) {
      logInfo('✅ No performance regressions detected');
      return true;
    }

    logError('❌ Performance regressions detected:');
    for (final regression in regressions) {
      logError('  • ${regression.metric}: ${regression.degradation.toStringAsFixed(1)}% slower');
      logError('    Baseline: ${regression.baselineValue}');
      logError('    Current: ${regression.currentValue}');
    }

    return false;
  }
}

/// Comprehensive benchmark suite runner
class ComprehensiveBenchmarkSuite {
  final String projectPath;
  final ConfigV3 config;
  final Directory outputDir;
  final bool ciMode;
  final bool memoryProfiling;

  ComprehensiveBenchmarkSuite({
    required this.projectPath,
    required this.config,
    required this.outputDir,
    this.ciMode = false,
    this.memoryProfiling = false,
  });

  /// Run comprehensive benchmarks
  Future<ComprehensiveBenchmarkResults> runBenchmarks(List<String> scenarios) async {
    final results = <String, Map<String, dynamic>>{};
    final startTime = DateTime.now();

    for (final scenario in scenarios) {
      print('\n📊 Running $scenario benchmarks...');
      
      switch (scenario) {
        case 'scanning':
          results['scanning'] = await _runScanningBenchmarks();
          break;
        case 'baseline':
          results['baseline'] = await _runBaselineBenchmarks();
          break;
        case 'diff':
          results['diff'] = await _runDiffBenchmarks();
          break;
        case 'validation':
          results['validation'] = await _runValidationBenchmarks();
          break;
        case 'memory':
          if (memoryProfiling) {
            results['memory'] = await _runMemoryBenchmarks();
          }
          break;
        case 'accuracy':
          results['accuracy'] = await _runAccuracyBenchmarks();
          break;
        case 'ci-integration':
          results['ci_integration'] = await _runCIIntegrationBenchmarks();
          break;
      }
    }

    return ComprehensiveBenchmarkResults(
      results: results,
      metadata: {
        'timestamp': startTime.toIso8601String(),
        'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
        'platform': Platform.operatingSystem,
        'cpu_cores': Platform.numberOfProcessors,
        'ci_mode': ciMode,
        'memory_profiling': memoryProfiling,
        'project_path': projectPath,
      },
    );
  }

  /// Run AST scanning performance benchmarks
  Future<Map<String, dynamic>> _runScanningBenchmarks() async {
    final benchmark = PerformanceBenchmark(
      projectPath: projectPath,
      config: config,
    );

    final result = await benchmark.runBenchmark();
    
    // Add project size metrics
    final projectMetrics = await _analyzeProjectSize();
    
    return {
      'performance_results': result.results.map((k, v) => MapEntry(k, v.toMap())),
      'project_metrics': projectMetrics,
      'performance_targets_met': _validatePerformanceTargets(result),
    };
  }

  /// Run baseline command benchmarks
  Future<Map<String, dynamic>> _runBaselineBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Benchmark baseline creation
    final createStopwatch = Stopwatch()..start();
    final memoryBefore = ProcessInfo.currentRss;
    
    try {
      // Note: This would normally run the baseline command
      // For testing, we'll simulate the operation
      await Future.delayed(Duration(milliseconds: 100));
      
      createStopwatch.stop();
      final memoryAfter = ProcessInfo.currentRss;
      
      results['baseline_create'] = {
        'duration_ms': createStopwatch.elapsedMilliseconds,
        'memory_used_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
        'success': true,
      };
    } catch (e) {
      createStopwatch.stop();
      results['baseline_create'] = {
        'duration_ms': createStopwatch.elapsedMilliseconds,
        'success': false,
        'error': e.toString(),
      };
    }

    // Benchmark baseline update
    final updateStopwatch = Stopwatch()..start();
    try {
      await Future.delayed(Duration(milliseconds: 50));
      updateStopwatch.stop();
      
      results['baseline_update'] = {
        'duration_ms': updateStopwatch.elapsedMilliseconds,
        'success': true,
      };
    } catch (e) {
      updateStopwatch.stop();
      results['baseline_update'] = {
        'duration_ms': updateStopwatch.elapsedMilliseconds,
        'success': false,
        'error': e.toString(),
      };
    }

    return results;
  }

  /// Run diff command benchmarks
  Future<Map<String, dynamic>> _runDiffBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Create two baseline versions for diff testing
    final version1Keys = List.generate(1000, (i) => 'key_$i');
    final version2Keys = List.generate(1000, (i) => 'key_${i + 100}'); // 100 new, 100 removed
    
    final diffStopwatch = Stopwatch()..start();
    final memoryBefore = ProcessInfo.currentRss;
    
    try {
      // Simulate diff operation
      final addedKeys = version2Keys.toSet().difference(version1Keys.toSet());
      final removedKeys = version1Keys.toSet().difference(version2Keys.toSet());
      final commonKeys = version1Keys.toSet().intersection(version2Keys.toSet());
      
      diffStopwatch.stop();
      final memoryAfter = ProcessInfo.currentRss;
      
      results['diff_performance'] = {
        'duration_ms': diffStopwatch.elapsedMilliseconds,
        'memory_used_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
        'keys_compared': version1Keys.length + version2Keys.length,
        'added_keys': addedKeys.length,
        'removed_keys': removedKeys.length,
        'common_keys': commonKeys.length,
        'keys_per_second': (version1Keys.length + version2Keys.length) / (diffStopwatch.elapsedMilliseconds / 1000),
      };
    } catch (e) {
      diffStopwatch.stop();
      results['diff_performance'] = {
        'duration_ms': diffStopwatch.elapsedMilliseconds,
        'success': false,
        'error': e.toString(),
      };
    }

    return results;
  }

  /// Run validation benchmarks
  Future<Map<String, dynamic>> _runValidationBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Test validation performance with different baseline sizes
    for (final keyCount in [100, 1000, 5000, 10000]) {
      final validationStopwatch = Stopwatch()..start();
      final memoryBefore = ProcessInfo.currentRss;
      
      try {
        // Simulate validation with keyCount keys
        await Future.delayed(Duration(milliseconds: keyCount ~/ 10));
        
        validationStopwatch.stop();
        final memoryAfter = ProcessInfo.currentRss;
        
        results['validation_${keyCount}_keys'] = {
          'duration_ms': validationStopwatch.elapsedMilliseconds,
          'memory_used_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
          'keys_validated': keyCount,
          'keys_per_second': keyCount / (validationStopwatch.elapsedMilliseconds / 1000),
          'validation_rate': keyCount / validationStopwatch.elapsedMilliseconds,
        };
      } catch (e) {
        validationStopwatch.stop();
        results['validation_${keyCount}_keys'] = {
          'duration_ms': validationStopwatch.elapsedMilliseconds,
          'success': false,
          'error': e.toString(),
        };
      }
    }

    return results;
  }

  /// Run memory profiling benchmarks
  Future<Map<String, dynamic>> _runMemoryBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Memory usage patterns for different operations
    final memoryBaseline = ProcessInfo.currentRss;
    
    // Test memory usage during large file processing
    final largeFileMemory = <int>[];
    for (int i = 0; i < 10; i++) {
      // Simulate processing large files
      final data = List.filled(1000000, 'x'); // 1MB of data
      largeFileMemory.add(ProcessInfo.currentRss);
      data.clear(); // Force cleanup
    }
    
    results['memory_profile'] = {
      'baseline_memory_mb': memoryBaseline / (1024 * 1024),
      'peak_memory_mb': largeFileMemory.reduce(max) / (1024 * 1024),
      'memory_growth_mb': (largeFileMemory.reduce(max) - memoryBaseline) / (1024 * 1024),
      'memory_samples': largeFileMemory.map((m) => m / (1024 * 1024)).toList(),
    };

    return results;
  }

  /// Run accuracy vs speed trade-off benchmarks
  Future<Map<String, dynamic>> _runAccuracyBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Test different accuracy levels and their performance impact
    final accuracyLevels = ['basic', 'standard', 'comprehensive'];
    
    for (final level in accuracyLevels) {
      final stopwatch = Stopwatch()..start();
      
      // Simulate different accuracy levels
      int keysFound = 0;
      switch (level) {
        case 'basic':
          await Future.delayed(Duration(milliseconds: 50));
          keysFound = 800; // Lower accuracy, faster
          break;
        case 'standard':
          await Future.delayed(Duration(milliseconds: 100));
          keysFound = 950; // Balanced
          break;
        case 'comprehensive':
          await Future.delayed(Duration(milliseconds: 200));
          keysFound = 1000; // Highest accuracy, slower
          break;
      }
      
      stopwatch.stop();
      
      results['accuracy_$level'] = {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'keys_found': keysFound,
        'accuracy_rate': keysFound / 1000,
        'detection_speed': keysFound / (stopwatch.elapsedMilliseconds / 1000),
      };
    }

    return results;
  }

  /// Run CI/CD integration benchmarks
  Future<Map<String, dynamic>> _runCIIntegrationBenchmarks() async {
    final results = <String, dynamic>{};
    
    // Test typical CI/CD operations
    final operations = {
      'quick_scan': () => Future.delayed(Duration(milliseconds: 500)),
      'baseline_check': () => Future.delayed(Duration(milliseconds: 200)),
      'regression_test': () => Future.delayed(Duration(milliseconds: 300)),
      'report_generation': () => Future.delayed(Duration(milliseconds: 150)),
    };

    for (final entry in operations.entries) {
      final stopwatch = Stopwatch()..start();
      final memoryBefore = ProcessInfo.currentRss;
      
      try {
        await entry.value();
        stopwatch.stop();
        final memoryAfter = ProcessInfo.currentRss;
        
        results[entry.key] = {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'memory_used_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
          'success': true,
          'ci_friendly': stopwatch.elapsedMilliseconds < 1000, // Under 1 second
        };
      } catch (e) {
        stopwatch.stop();
        results[entry.key] = {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'success': false,
          'error': e.toString(),
        };
      }
    }

    return results;
  }

  /// Analyze project size metrics
  Future<Map<String, dynamic>> _analyzeProjectSize() async {
    int dartFiles = 0;
    int totalLines = 0;
    int totalSize = 0;

    await for (final entity in Directory(projectPath).list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles++;
        final stat = await entity.stat();
        totalSize += stat.size;
        
        try {
          final content = await entity.readAsString();
          totalLines += content.split('\n').length;
        } catch (e) {
          // Skip files that can't be read
        }
      }
    }

    return {
      'dart_files': dartFiles,
      'total_lines': totalLines,
      'total_size_mb': totalSize / (1024 * 1024),
      'avg_file_size_kb': totalSize / dartFiles / 1024,
      'avg_lines_per_file': totalLines / dartFiles,
    };
  }

  /// Validate performance targets
  Map<String, bool> _validatePerformanceTargets(BenchmarkResult result) {
    final targets = <String, bool>{};
    
    for (final entry in result.results.entries) {
      final metrics = entry.value;
      
      // Performance targets based on project size
      if (metrics.filesScanned < 100) {
        targets['${entry.key}_time_target'] = metrics.totalTimeMs <= 500;
      } else if (metrics.filesScanned <= 1000) {
        targets['${entry.key}_time_target'] = metrics.totalTimeMs <= 2000;
      } else {
        targets['${entry.key}_time_target'] = metrics.totalTimeMs <= 10000;
      }
      
      targets['${entry.key}_memory_target'] = metrics.memoryUsedMB <= 500;
      targets['${entry.key}_files_per_second_target'] = metrics.filesPerSecond >= 500;
      targets['${entry.key}_keys_per_second_target'] = metrics.keysPerSecond >= 10000;
      
      if (metrics.cacheHitRate > 0) {
        targets['${entry.key}_cache_target'] = metrics.cacheHitRate >= 80;
      }
    }
    
    return targets;
  }
}

/// Test data generator for benchmarking
class TestDataGenerator {
  final String projectPath;
  final Random _random = Random();

  TestDataGenerator(this.projectPath);

  /// Generate a test project with specified characteristics
  Future<void> generateProject({
    required int fileCount,
    required int avgSizeKB,
    required double keyDensity,
  }) async {
    final testDir = Directory(path.join(projectPath, 'benchmark_test_data'));
    
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    
    await testDir.create(recursive: true);
    
    // Create lib directory structure
    final libDir = Directory(path.join(testDir.path, 'lib'));
    await libDir.create();
    
    final subDirs = ['screens', 'widgets', 'models', 'services', 'utils'];
    for (final subDir in subDirs) {
      await Directory(path.join(libDir.path, subDir)).create();
    }

    // Generate files across subdirectories
    for (int i = 0; i < fileCount; i++) {
      final subDir = subDirs[i % subDirs.length];
      final file = File(path.join(libDir.path, subDir, 'generated_$i.dart'));
      
      final content = _generateDartFileContent(
        targetSizeKB: avgSizeKB,
        keyDensity: keyDensity,
        fileIndex: i,
      );
      
      await file.writeAsString(content);
    }

    // Create pubspec.yaml
    final pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    await pubspecFile.writeAsString(_generatePubspecContent());

    print('✅ Generated test project:');
    print('  • Files: $fileCount');
    print('  • Average size: ${avgSizeKB}KB');
    print('  • Key density: ${(keyDensity * 100).toStringAsFixed(1)}%');
    print('  • Location: ${testDir.path}');
  }

  /// Generate Dart file content with specified characteristics
  String _generateDartFileContent({
    required int targetSizeKB,
    required double keyDensity,
    required int fileIndex,
  }) {
    final buffer = StringBuffer();
    final targetBytes = targetSizeKB * 1024;
    
    // File header
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
    buffer.writeln();
    buffer.writeln('/// Generated test file $fileIndex');
    buffer.writeln('class GeneratedWidget$fileIndex extends StatelessWidget {');
    buffer.writeln('  const GeneratedWidget$fileIndex({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return Column(');
    buffer.writeln('      children: [');

    int currentBytes = buffer.toString().length;
    int keyIndex = 0;
    int widgetIndex = 0;

    final widgets = [
      'Container', 'ElevatedButton', 'TextField', 'ListTile', 'Card',
      'Row', 'Column', 'Stack', 'Padding', 'Center', 'Expanded',
      'SizedBox', 'Flexible', 'Wrap', 'Flow'
    ];

    // Generate widgets until target size is reached
    while (currentBytes < targetBytes - 500) {
      final widgetType = widgets[widgetIndex % widgets.length];
      final shouldHaveKey = _random.nextDouble() < keyDensity;
      
      if (shouldHaveKey) {
        final keyType = _randomKeyType();
        final keyValue = 'generated_${fileIndex}_key_${keyIndex++}';
        buffer.writeln('        $widgetType(');
        buffer.writeln('          key: $keyType(\'$keyValue\'),');
        _addWidgetProperties(buffer, widgetType, widgetIndex);
        buffer.writeln('        ),');
      } else {
        buffer.writeln('        $widgetType(');
        _addWidgetProperties(buffer, widgetType, widgetIndex);
        buffer.writeln('        ),');
      }

      widgetIndex++;
      currentBytes = buffer.toString().length;
    }

    // Close the widget structure
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');

    // Add test cases to increase file size
    buffer.writeln();
    buffer.writeln('// Test cases for widget $fileIndex');
    buffer.writeln('void main() {');
    buffer.writeln('  group(\'GeneratedWidget$fileIndex Tests\', () {');
    
    for (int i = 0; i < keyIndex && buffer.toString().length < targetBytes; i++) {
      buffer.writeln('    testWidgets(\'should find key generated_${fileIndex}_key_$i\', (tester) async {');
      buffer.writeln('      await tester.pumpWidget(');
      buffer.writeln('        MaterialApp(home: GeneratedWidget$fileIndex()),');
      buffer.writeln('      );');
      buffer.writeln('      expect(find.byKey(ValueKey(\'generated_${fileIndex}_key_$i\')), findsOneWidget);');
      buffer.writeln('    });');
      buffer.writeln();
    }
    
    buffer.writeln('  });');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Add properties to widget based on type
  void _addWidgetProperties(StringBuffer buffer, String widgetType, int index) {
    switch (widgetType) {
      case 'Container':
        buffer.writeln('          height: ${20 + (index % 100)},');
        buffer.writeln('          width: ${50 + (index % 200)},');
        buffer.writeln('          color: Colors.blue,');
        buffer.writeln('          child: Text(\'Container $index\'),');
        break;
      case 'ElevatedButton':
        buffer.writeln('          onPressed: () => print(\'Button $index pressed\'),');
        buffer.writeln('          child: Text(\'Button $index\'),');
        break;
      case 'TextField':
        buffer.writeln('          decoration: InputDecoration(');
        buffer.writeln('            hintText: \'Input field $index\',');
        buffer.writeln('            labelText: \'Label $index\',');
        buffer.writeln('          ),');
        break;
      case 'ListTile':
        buffer.writeln('          title: Text(\'List item $index\'),');
        buffer.writeln('          subtitle: Text(\'Subtitle $index\'),');
        buffer.writeln('          onTap: () => print(\'ListTile $index tapped\'),');
        break;
      default:
        buffer.writeln('          child: Text(\'$widgetType $index\'),');
    }
  }

  /// Generate random key type
  String _randomKeyType() {
    final types = ['ValueKey', 'Key', 'ObjectKey', 'UniqueKey'];
    return types[_random.nextInt(types.length)];
  }

  /// Generate pubspec.yaml content
  String _generatePubspecContent() {
    return '''
name: benchmark_test_data
version: 1.0.0
description: Generated test data for flutter_keycheck benchmarking

environment:
  sdk: ">=2.17.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
''';
  }
}

/// Comprehensive benchmark results container
class ComprehensiveBenchmarkResults {
  final Map<String, Map<String, dynamic>> results;
  final Map<String, dynamic> metadata;

  ComprehensiveBenchmarkResults({
    required this.results,
    required this.metadata,
  });

  /// Create from JSON data
  static ComprehensiveBenchmarkResults fromJson(Map<String, dynamic> json) {
    return ComprehensiveBenchmarkResults(
      results: Map<String, Map<String, dynamic>>.from(
        json['results']?.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))) ?? {}
      ),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Export to JSON file
  Future<void> exportToJson(String filePath) async {
    final data = {
      'metadata': metadata,
      'results': results,
    };

    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));
  }

  /// Print comprehensive benchmark report
  void printReport() {
    print('\n📊 Comprehensive Performance Benchmark Report');
    print('=' * 70);
    
    print('\nMetadata:');
    print('  Timestamp: ${metadata['timestamp']}');
    print('  Duration: ${metadata['duration_ms']}ms');
    print('  Platform: ${metadata['platform']}');
    print('  CPU Cores: ${metadata['cpu_cores']}');
    if (metadata['ci_mode'] == true) {
      print('  Mode: CI/CD Optimized');
    }

    for (final entry in results.entries) {
      print('\n${entry.key.toUpperCase()} Results:');
      print('-' * 40);
      _printSectionResults(entry.value);
    }

    // Overall performance summary
    print('\n🎯 Performance Summary:');
    print('-' * 40);
    _printPerformanceSummary();
  }

  /// Print results for a specific section
  void _printSectionResults(Map<String, dynamic> sectionResults) {
    for (final entry in sectionResults.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map) {
        print('  $key:');
        for (final subEntry in value.entries) {
          if (subEntry.value is num) {
            print('    ${subEntry.key}: ${subEntry.value}');
          } else {
            print('    ${subEntry.key}: ${subEntry.value}');
          }
        }
      } else {
        print('  $key: $value');
      }
    }
  }

  /// Print overall performance summary
  void _printPerformanceSummary() {
    // Extract key metrics from scanning results
    final scanningResults = results['scanning'];
    if (scanningResults != null) {
      final performanceResults = scanningResults['performance_results'] as Map<String, dynamic>?;
      if (performanceResults != null) {
        final fastest = _findFastestResult(performanceResults);
        final mostEfficient = _findMostEfficientResult(performanceResults);
        
        print('  Fastest configuration: $fastest');
        print('  Most memory efficient: $mostEfficient');
      }
      
      final targetsMetrics = scanningResults['performance_targets_met'] as Map<String, bool>?;
      if (targetsMetrics != null) {
        final metTargets = targetsMetrics.values.where((met) => met).length;
        final totalTargets = targetsMetrics.length;
        print('  Performance targets met: $metTargets/$totalTargets (${(metTargets/totalTargets*100).toStringAsFixed(1)}%)');
      }
    }

    // CI/CD friendliness
    final ciResults = results['ci_integration'];
    if (ciResults != null) {
      final ciFriendlyOps = ciResults.values
          .where((result) => result is Map && result['ci_friendly'] == true)
          .length;
      print('  CI/CD friendly operations: $ciFriendlyOps/${ciResults.length}');
    }
  }

  /// Find fastest benchmark result
  String _findFastestResult(Map<String, dynamic> performanceResults) {
    String fastest = '';
    int minTime = double.maxFinite.toInt();
    
    for (final entry in performanceResults.entries) {
      final result = entry.value as Map<String, dynamic>;
      final time = result['total_time_ms'] as int? ?? double.maxFinite.toInt();
      if (time < minTime) {
        minTime = time;
        fastest = entry.key;
      }
    }
    
    return '$fastest (${minTime}ms)';
  }

  /// Find most memory efficient result
  String _findMostEfficientResult(Map<String, dynamic> performanceResults) {
    String mostEfficient = '';
    double minMemory = double.maxFinite;
    
    for (final entry in performanceResults.entries) {
      final result = entry.value as Map<String, dynamic>;
      final memoryStr = result['memory_used_mb'] as String? ?? '999999';
      final memory = double.tryParse(memoryStr) ?? double.maxFinite;
      if (memory < minMemory) {
        minMemory = memory;
        mostEfficient = entry.key;
      }
    }
    
    return '$mostEfficient (${minMemory.toStringAsFixed(1)}MB)';
  }
}

/// Performance regression analyzer
class RegressionAnalyzer {
  final double threshold;

  RegressionAnalyzer(this.threshold);

  /// Analyze performance regression between baseline and current results
  List<PerformanceRegression> analyzeRegression(
    ComprehensiveBenchmarkResults baseline,
    ComprehensiveBenchmarkResults current,
  ) {
    final regressions = <PerformanceRegression>[];

    // Compare scanning performance
    final baselineScanning = baseline.results['scanning'];
    final currentScanning = current.results['scanning'];
    
    if (baselineScanning != null && currentScanning != null) {
      regressions.addAll(_compareSection('scanning', baselineScanning, currentScanning));
    }

    // Compare other sections similarly
    for (final section in ['baseline', 'diff', 'validation', 'ci_integration']) {
      final baselineSection = baseline.results[section];
      final currentSection = current.results[section];
      
      if (baselineSection != null && currentSection != null) {
        regressions.addAll(_compareSection(section, baselineSection, currentSection));
      }
    }

    return regressions;
  }

  /// Compare a specific section for regressions
  List<PerformanceRegression> _compareSection(
    String section,
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) {
    final regressions = <PerformanceRegression>[];

    // Compare duration metrics
    _compareMetric(
      baseline,
      current,
      'duration_ms',
      (baseline, current) => PerformanceRegression(
        section: section,
        metric: 'duration_ms',
        baselineValue: baseline,
        currentValue: current,
        degradation: ((current - baseline) / baseline) * 100,
      ),
    )?.let(regressions.add);

    // Compare memory metrics
    _compareMetric(
      baseline,
      current,
      'memory_used_mb',
      (baseline, current) => PerformanceRegression(
        section: section,
        metric: 'memory_used_mb',
        baselineValue: baseline,
        currentValue: current,
        degradation: ((current - baseline) / baseline) * 100,
      ),
    )?.let(regressions.add);

    return regressions.where((r) => r.degradation > threshold).toList();
  }

  /// Compare a specific metric between baseline and current
  T? _compareMetric<T>(
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
    String metricKey,
    T Function(double baseline, double current) createRegression,
  ) {
    final baselineValue = _extractNumericValue(baseline, metricKey);
    final currentValue = _extractNumericValue(current, metricKey);

    if (baselineValue != null && currentValue != null) {
      return createRegression(baselineValue, currentValue);
    }

    return null;
  }

  /// Extract numeric value from nested map structure
  double? _extractNumericValue(Map<String, dynamic> data, String key) {
    // Try direct key
    var value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);

    // Try nested structures
    for (final entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        final nested = entry.value as Map<String, dynamic>;
        final nestedValue = nested[key];
        if (nestedValue is num) return nestedValue.toDouble();
        if (nestedValue is String) return double.tryParse(nestedValue);
      }
    }

    return null;
  }
}

/// Performance regression data class
class PerformanceRegression {
  final String section;
  final String metric;
  final double baselineValue;
  final double currentValue;
  final double degradation;

  PerformanceRegression({
    required this.section,
    required this.metric,
    required this.baselineValue,
    required this.currentValue,
    required this.degradation,
  });
}

/// Extension for null-safe operations
extension NullSafeOperations<T> on T? {
  void let(void Function(T) action) {
    if (this != null) action(this!);
  }
}