#!/usr/bin/env dart

import 'dart:io';
import 'lib/src/scanner/ast_scanner_v3.dart';
import 'lib/src/config/config_v3.dart';

/// Quick performance test to validate optimizations
Future<void> main() async {
  print('🚀 Testing Performance Optimizations...\n');

  final projectPath = Directory.current.path;
  final config = ConfigV3(
    verbose: true,
    scan: ScanConfigV3(
      scope: ScanScope.workspaceOnly,
      excludePatterns: ['**/.dart_tool/**', '**/build/**'],
    ),
  );

  // Test 1: Sequential scanning
  print('📊 Test 1: Sequential Processing');
  final scanner1 = AstScannerV3(
    projectPath: projectPath,
    config: config,
    enableParallelProcessing: false,
    enableIncrementalScanning: false,
    enableLazyLoading: false,
    enableAggressiveCaching: false,
  );

  final stopwatch1 = Stopwatch()..start();
  try {
    final result1 = await scanner1.scan();
    stopwatch1.stop();
    
    print('  ✅ Sequential: ${stopwatch1.elapsedMilliseconds}ms');
    print('     Files: ${result1.metrics.scannedFiles}');
    print('     Keys: ${result1.keyUsages.length}');
    print('     Errors: ${result1.metrics.errors.length}');
    
    final performance1 = result1.metrics.dependencyTree?['performance'] as Map<String, dynamic>?;
    if (performance1 != null) {
      print('     Performance: ${performance1['files_per_second']} files/sec');
    }
  } catch (e) {
    stopwatch1.stop();
    print('  ❌ Sequential failed: $e');
  }

  print('\n📊 Test 2: Optimized Processing');
  final scanner2 = AstScannerV3(
    projectPath: projectPath,
    config: config,
    enableParallelProcessing: true,
    enableIncrementalScanning: true,
    enableLazyLoading: true,
    enableAggressiveCaching: true,
  );

  final stopwatch2 = Stopwatch()..start();
  try {
    final result2 = await scanner2.scan();
    stopwatch2.stop();
    
    print('  ✅ Optimized: ${stopwatch2.elapsedMilliseconds}ms');
    print('     Files: ${result2.metrics.scannedFiles}');
    print('     Keys: ${result2.keyUsages.length}');
    print('     Errors: ${result2.metrics.errors.length}');
    
    final performance2 = result2.metrics.dependencyTree?['performance'] as Map<String, dynamic>?;
    if (performance2 != null) {
      print('     Performance: ${performance2['files_per_second']} files/sec');
      print('     Cache hit rate: ${performance2['cache_hit_rate']}');
      print('     Parallel files: ${performance2['files_processed_parallel']}');
    }
    
    // Performance comparison
    if (stopwatch1.elapsedMilliseconds > 0) {
      final improvement = stopwatch1.elapsedMilliseconds / stopwatch2.elapsedMilliseconds;
      print('\n🎯 Performance Improvement: ${improvement.toStringAsFixed(2)}x faster');
    }
    
  } catch (e) {
    stopwatch2.stop();
    print('  ❌ Optimized failed: $e');
  }

  print('\n✅ Performance test completed!');
}