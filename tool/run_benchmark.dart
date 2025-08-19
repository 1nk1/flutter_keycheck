#!/usr/bin/env dart

import 'dart:io';
import 'package:flutter_keycheck/src/scanner/performance_benchmark.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:path/path.dart' as path;

/// Benchmark runner for flutter_keycheck performance optimization
Future<void> main(List<String> args) async {
  final projectPath = args.isNotEmpty ? args[0] : Directory.current.path;
  final outputPath = args.length > 1 ? args[1] : 'benchmark_results.json';

  print('🚀 Flutter KeyCheck Performance Benchmark');
  print('Project: $projectPath');
  print('Output: $outputPath\n');

  // Create default config
  final config = ConfigV3(
    verbose: true,
    scan: ScanConfigV3(
      scope: ScanScope.workspaceOnly,
      excludePatterns: [
        '**/.dart_tool/**',
        '**/build/**',
        '**/.git/**',
      ],
    ),
  );

  final benchmark = PerformanceBenchmark(
    projectPath: projectPath,
    config: config,
  );

  try {
    // Run benchmarks
    final result = await benchmark.runBenchmark();
    
    // Print report
    result.printReport();
    
    // Export results
    await result.exportToJson(outputPath);
    
    print('\n✅ Benchmark completed successfully!');
    
  } catch (e, stackTrace) {
    print('\n❌ Benchmark failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

/// Generate test files for benchmarking
Future<void> generateTestProject() async {
  final testDir = Directory('benchmark_test_project');
  if (await testDir.exists()) {
    await testDir.delete(recursive: true);
  }
  
  await testDir.create();
  
  // Create a Flutter project structure
  final libDir = Directory(path.join(testDir.path, 'lib'));
  final testDirPath = Directory(path.join(testDir.path, 'test'));
  
  await libDir.create();
  await testDirPath.create();
  
  // Generate various file sizes
  final sizes = [
    (10, 5),   // 10 files of ~5KB each
    (50, 10),  // 50 files of ~10KB each
    (100, 20), // 100 files of ~20KB each
    (20, 50),  // 20 files of ~50KB each
    (5, 100),  // 5 files of ~100KB each
  ];
  
  int fileCount = 0;
  for (final (count, sizeKB) in sizes) {
    for (int i = 0; i < count; i++) {
      final file = File(path.join(libDir.path, 'generated_${fileCount++}.dart'));
      final content = _generateDartFile(sizeKB * 1024);
      await file.writeAsString(content);
    }
  }
  
  // Create pubspec.yaml
  final pubspec = File(path.join(testDir.path, 'pubspec.yaml'));
  await pubspec.writeAsString('''
name: benchmark_test_project
version: 1.0.0
environment:
  sdk: ">=2.17.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
  
  print('✅ Generated test project with $fileCount files in ${testDir.path}');
}

/// Generate a Dart file with specified target size
String _generateDartFile(int targetBytes) {
  final buffer = StringBuffer();
  
  buffer.writeln('''
import 'package:flutter/material.dart';

class GeneratedWidget extends StatelessWidget {
  const GeneratedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('app_bar'),
        title: const Text('Generated Widget'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
''');

  int currentBytes = buffer.toString().length;
  int keyIndex = 0;
  
  final widgets = [
    'Container',
    'ElevatedButton',
    'TextField',
    'ListTile',
    'Card',
    'Row',
    'Column',
    'Stack',
    'Padding',
    'Center',
  ];
  
  while (currentBytes < targetBytes - 200) { // Leave space for closing
    final widgetType = widgets[keyIndex % widgets.length];
    final hasKey = keyIndex % 3 == 0; // Add key to every 3rd widget
    final keyPart = hasKey ? 'key: ValueKey(\'generated_key_$keyIndex\'), ' : '';
    
    switch (widgetType) {
      case 'Container':
        buffer.writeln('            Container(');
        if (hasKey) buffer.writeln('              $keyPart');
        buffer.writeln('              height: 50,');
        buffer.writeln('              color: Colors.blue,');
        buffer.writeln('              child: const Text(\'Container $keyIndex\'),');
        buffer.writeln('            ),');
        break;
        
      case 'ElevatedButton':
        buffer.writeln('            ElevatedButton(');
        if (hasKey) buffer.writeln('              $keyPart');
        buffer.writeln('              onPressed: () {},');
        buffer.writeln('              child: const Text(\'Button $keyIndex\'),');
        buffer.writeln('            ),');
        break;
        
      case 'TextField':
        buffer.writeln('            TextField(');
        if (hasKey) buffer.writeln('              $keyPart');
        buffer.writeln('              decoration: const InputDecoration(');
        buffer.writeln('                hintText: \'Input $keyIndex\',');
        buffer.writeln('              ),');
        buffer.writeln('            ),');
        break;
        
      default:
        buffer.writeln('            $widgetType(');
        if (hasKey) buffer.writeln('              $keyPart');
        buffer.writeln('              child: Text(\'$widgetType $keyIndex\'),');
        buffer.writeln('            ),');
    }
    
    keyIndex++;
    currentBytes = buffer.toString().length;
  }
  
  buffer.writeln('''
          ],
        ),
      ),
    );
  }
}
''');
  
  return buffer.toString();
}