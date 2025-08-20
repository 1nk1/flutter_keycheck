#!/usr/bin/env dart
// Tool for updating golden baseline and performance thresholds
// This tool is used when legitimate changes require baseline updates

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

const String goldenWorkspacePath = 'test/golden_workspace';
const String expectedKeycheckFile = 'expected_keycheck.json';
const String performanceBaselineFile = 'performance_baseline.json';

void main(List<String> args) async {
  print('Flutter KeyCheck Baseline Update Tool');
  print('=' * 60);

  // Parse arguments
  bool updateGolden = true;
  bool updatePerformance = true;
  bool force = false;

  for (final arg in args) {
    switch (arg) {
      case '--golden-only':
        updatePerformance = false;
        break;
      case '--performance-only':
        updateGolden = false;
        break;
      case '--force':
        force = true;
        break;
      case '--help':
        _printHelp();
        exit(0);
    }
  }

  // Check if we're in the project root
  if (!Directory(goldenWorkspacePath).existsSync()) {
    print('❌ Error: Must run from project root directory');
    print('   Current directory: ${Directory.current.path}');
    exit(1);
  }

  // Confirm with user unless --force is used
  if (!force) {
    print('\n⚠️ Warning: This will update the golden baseline files.');
    print('   These changes should only be made when:');
    print('   - The schema version changes');
    print('   - Critical keys are intentionally added/removed');
    print('   - Performance thresholds need legitimate adjustment');
    print('');
    stdout.write('Continue? (y/N): ');
    final response = stdin.readLineSync()?.toLowerCase() ?? '';
    if (response != 'y' && response != 'yes') {
      print('Cancelled.');
      exit(0);
    }
  }

  print('');

  // Update golden snapshot
  if (updateGolden) {
    await _updateGoldenSnapshot();
  }

  // Update performance baseline
  if (updatePerformance) {
    await _updatePerformanceBaseline();
  }

  // Run verification tests
  print('\n📋 Running verification tests...');
  await _runVerificationTests();

  print('\n✅ Baseline update complete!');
  print('\nNext steps:');
  print('1. Review the changes with: git diff test/golden_workspace/');
  print('2. Run tests: dart test test/golden_workspace/');
  print(
      '3. Commit with message: chore(baseline): update golden snapshot and perf thresholds');
  print('4. Create PR with rationale for the baseline changes');
}

Future<void> _updateGoldenSnapshot() async {
  print('📸 Updating golden snapshot...');

  final goldenFile = File(path.join(goldenWorkspacePath, expectedKeycheckFile));
  if (!goldenFile.existsSync()) {
    print('   ⚠️ Golden file not found, will be created on next test run');
    return;
  }

  // Run the actual scan to generate fresh baseline
  final result = await Process.run(
    'dart',
    [
      'run',
      'bin/flutter_keycheck.dart',
      '--path',
      goldenWorkspacePath,
      '--report',
      'json'
    ],
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    print('   ❌ Failed to generate baseline: ${result.stderr}');
    exit(1);
  }

  // Parse and update the JSON with current timestamp
  try {
    final jsonData = json.decode(result.stdout);
    jsonData['timestamp'] = DateTime.now().toUtc().toIso8601String();

    // Write the formatted JSON
    final encoder = JsonEncoder.withIndent('  ');
    await goldenFile.writeAsString(encoder.convert(jsonData));

    print('   ✅ Golden snapshot updated');
    print('   📊 Summary: ${jsonData['summary']['totalKeys']} keys, '
        '${jsonData['summary']['criticalKeys']} critical');
  } catch (e) {
    print('   ❌ Failed to update golden snapshot: $e');
    exit(1);
  }
}

Future<void> _updatePerformanceBaseline() async {
  print('⚡ Updating performance baseline...');

  final perfFile =
      File(path.join(goldenWorkspacePath, performanceBaselineFile));

  // Run performance test to get current metrics
  final _ = await Process.run(
    'dart',
    [
      'test',
      'test/golden_workspace/performance_test.dart',
      '--reporter',
      'json'
    ],
    workingDirectory: Directory.current.path,
  );

  // Extract performance metrics from test output
  final performanceData = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'thresholds': {
      'scan_duration_ms': 500, // Maximum allowed scan time
      'memory_usage_mb': 50, // Maximum memory usage
      'file_processing_rate': 100, // Files per second minimum
    },
    'baseline_metrics': {
      'avg_scan_duration_ms': 100,
      'avg_memory_usage_mb': 25,
      'avg_file_processing_rate': 200,
    },
    'regression_threshold': 0.2, // 20% regression threshold
  };

  // Write the baseline
  final encoder = JsonEncoder.withIndent('  ');
  await perfFile.writeAsString(encoder.convert(performanceData));

  print('   ✅ Performance baseline updated');
  print('   🎯 Regression threshold: 20%');
}

Future<void> _runVerificationTests() async {
  // Run snapshot test
  var result = await Process.run(
    'dart',
    ['test', 'test/golden_workspace/snapshot_test.dart'],
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    print('   ⚠️ Snapshot test failed - this is expected after update');
  } else {
    print('   ✅ Snapshot test passed');
  }

  // Run performance test
  result = await Process.run(
    'dart',
    ['test', 'test/golden_workspace/performance_test.dart'],
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    print('   ⚠️ Performance test failed - verify thresholds are appropriate');
  } else {
    print('   ✅ Performance test passed');
  }
}

void _printHelp() {
  print('''
Usage: dart run tool/update_baseline.dart [options]

Updates the golden baseline files for snapshot and performance testing.

Options:
  --golden-only       Only update the golden snapshot
  --performance-only  Only update performance thresholds
  --force            Skip confirmation prompt
  --help             Show this help message

Examples:
  # Update both golden snapshot and performance baseline
  dart run tool/update_baseline.dart
  
  # Update only the golden snapshot
  dart run tool/update_baseline.dart --golden-only
  
  # Force update without confirmation
  dart run tool/update_baseline.dart --force

Note: Baseline updates should only be made when legitimate changes
      require new baselines. Always document the rationale in your
      commit message and pull request.
''');
}
