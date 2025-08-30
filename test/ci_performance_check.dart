#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as path;

/// CI performance regression checker
/// This script is designed to be run in CI environments to detect performance regressions
Future<void> main(List<String> args) async {
  print('🔍 Flutter KeyCheck Performance Regression Check');
  print('=' * 50);
  print('');
  
  final projectRoot = path.dirname(path.dirname(Platform.script.toFilePath()));
  final baselineFile = File(path.join(projectRoot, 'performance_baseline.json'));
  
  // Check if baseline exists
  if (!baselineFile.existsSync()) {
    print('⚠️  WARNING: No performance baseline found.');
    print('   Run "dart test/performance_baseline.dart" to establish baseline.');
    print('   Skipping regression check for this run.');
    exit(0); // Don't fail CI if no baseline exists
  }
  
  print('📊 Running performance profiling...');
  print('');
  
  // Run the performance profiler in comparison mode
  final result = await Process.run(
    'dart',
    ['test/performance_baseline.dart', '--compare'],
    workingDirectory: projectRoot,
  );
  
  // Print output
  stdout.write(result.stdout);
  if (result.stderr.toString().isNotEmpty) {
    stderr.write(result.stderr);
  }
  
  // Check exit code
  if (result.exitCode != 0) {
    print('');
    print('=' * 50);
    print('❌ PERFORMANCE REGRESSION DETECTED');
    print('=' * 50);
    print('');
    print('One or more metrics have regressed by >20% compared to baseline.');
    print('This indicates a significant performance degradation.');
    print('');
    print('Actions to take:');
    print('1. Review recent changes that might impact performance');
    print('2. Profile the specific operations that have degraded');
    print('3. If the regression is expected, update the baseline:');
    print('   dart test/performance_baseline.dart');
    print('');
    exit(1);
  }
  
  print('');
  print('=' * 50);
  print('✅ PERFORMANCE CHECK PASSED');
  print('=' * 50);
  print('');
  print('All metrics are within acceptable bounds (±20% of baseline).');
  exit(0);
}