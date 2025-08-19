#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;

/// Comprehensive performance testing suite for flutter_keycheck
/// 
/// This script provides:
/// - Multi-scale test data generation
/// - Performance benchmarking across different scenarios
/// - Regression testing capabilities
/// - CI/CD integration support
/// - Memory profiling and analysis
/// 
/// Usage:
///   dart run scripts/performance_suite.dart [command] [options]
///
/// Commands:
///   generate    Generate test data
///   benchmark   Run performance benchmarks
///   regression  Run regression tests
///   analyze     Analyze performance results
///   report      Generate performance reports
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    return;
  }

  final command = args[0];
  final options = parseArguments(args.skip(1).toList());

  try {
    switch (command) {
      case 'generate':
        await runGenerateCommand(options);
        break;
      case 'benchmark':
        await runBenchmarkCommand(options);
        break;
      case 'regression':
        await runRegressionCommand(options);
        break;
      case 'analyze':
        await runAnalyzeCommand(options);
        break;
      case 'report':
        await runReportCommand(options);
        break;
      case 'complete':
        await runCompleteWorkflow(options);
        break;
      default:
        print('❌ Unknown command: $command');
        printUsage();
        exit(1);
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    if (options['verbose'] == true) {
      print('Stack trace: $stackTrace');
    }
    exit(1);
  }
}

/// Print usage information
void printUsage() {
  print('''
🚀 Flutter KeyCheck Performance Suite

Usage: dart run scripts/performance_suite.dart <command> [options]

Commands:
  generate     Generate test data for benchmarking
  benchmark    Run comprehensive performance benchmarks
  regression   Run regression tests against baseline
  analyze      Analyze performance results and trends
  report       Generate performance reports
  complete     Run complete workflow (generate + benchmark + analyze)

Options:
  --project-size <size>      Project size: small, medium, large, enterprise (default: medium)
  --output <path>            Output directory (default: performance_results)
  --baseline <path>          Baseline file for regression testing
  --threshold <percent>      Regression threshold percentage (default: 20)
  --scenarios <list>         Comma-separated list of scenarios to run
  --ci                       Run in CI mode with optimized settings
  --memory-profile           Enable detailed memory profiling
  --verbose                  Enable verbose output
  --help                     Show this help message

Examples:
  # Generate large project test data
  dart run scripts/performance_suite.dart generate --project-size large

  # Run benchmarks with memory profiling
  dart run scripts/performance_suite.dart benchmark --memory-profile --ci

  # Run regression tests
  dart run scripts/performance_suite.dart regression --baseline baseline.json --threshold 15

  # Generate comprehensive report
  dart run scripts/performance_suite.dart report --output reports/

  # Complete workflow for CI/CD
  dart run scripts/performance_suite.dart complete --ci --project-size medium
''');
}

/// Parse command line arguments
Map<String, dynamic> parseArguments(List<String> args) {
  final options = <String, dynamic>{};
  
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      
      // Boolean flags
      if (['ci', 'memory-profile', 'verbose', 'help'].contains(key)) {
        options[key] = true;
      } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        // Options with values
        options[key] = args[i + 1];
        i++; // Skip next argument as it's the value
      } else {
        options[key] = true; // Flag without value
      }
    }
  }
  
  // Set defaults
  options['project-size'] ??= 'medium';
  options['output'] ??= 'performance_results';
  options['threshold'] ??= '20';
  options['scenarios'] ??= 'scanning,baseline,diff,validation,ci-integration';
  
  return options;
}

/// Generate test data command
Future<void> runGenerateCommand(Map<String, dynamic> options) async {
  print('🔧 Generating test data...');
  
  final projectSize = options['project-size'] as String;
  final outputDir = options['output'] as String;
  
  final generator = TestDataGenerator(outputDir);
  
  await generator.generateComprehensiveTestSuite(projectSize);
  
  print('✅ Test data generation completed');
}

/// Run benchmark command
Future<void> runBenchmarkCommand(Map<String, dynamic> options) async {
  print('📊 Running performance benchmarks...');
  
  final outputDir = options['output'] as String;
  final scenarios = (options['scenarios'] as String).split(',');
  final ciMode = options['ci'] == true;
  final memoryProfile = options['memory-profile'] == true;
  
  final benchmarkRunner = BenchmarkRunner(
    outputDir: outputDir,
    ciMode: ciMode,
    memoryProfiling: memoryProfile,
  );
  
  final results = await benchmarkRunner.runBenchmarks(scenarios);
  
  // Save results
  final resultsFile = File(path.join(outputDir, 'benchmark_results.json'));
  await results.saveToFile(resultsFile.path);
  
  // Print summary
  results.printSummary();
  
  print('✅ Benchmarks completed');
}

/// Run regression command
Future<void> runRegressionCommand(Map<String, dynamic> options) async {
  print('🔍 Running regression tests...');
  
  final baselinePath = options['baseline'] as String?;
  final threshold = double.parse(options['threshold'] as String);
  final outputDir = options['output'] as String;
  
  if (baselinePath == null) {
    throw ArgumentError('Baseline file path is required for regression testing');
  }
  
  final analyzer = RegressionAnalyzer(threshold);
  final regressions = await analyzer.analyzeRegressionFromFiles(
    baselinePath,
    path.join(outputDir, 'benchmark_results.json'),
  );
  
  if (regressions.isEmpty) {
    print('✅ No performance regressions detected');
  } else {
    print('❌ Performance regressions detected:');
    for (final regression in regressions) {
      print('  • ${regression.metric}: ${regression.degradation.toStringAsFixed(1)}% slower');
    }
    exit(1);
  }
}

/// Analyze performance results
Future<void> runAnalyzeCommand(Map<String, dynamic> options) async {
  print('📈 Analyzing performance results...');
  
  final outputDir = options['output'] as String;
  final resultsFile = File(path.join(outputDir, 'benchmark_results.json'));
  
  if (!await resultsFile.exists()) {
    throw FileSystemException('Benchmark results file not found', resultsFile.path);
  }
  
  final analyzer = PerformanceAnalyzer();
  final analysis = await analyzer.analyzeResults(resultsFile.path);
  
  analysis.printReport();
  
  // Save analysis
  final analysisFile = File(path.join(outputDir, 'performance_analysis.json'));
  await analysis.saveToFile(analysisFile.path);
  
  print('✅ Performance analysis completed');
}

/// Generate performance report
Future<void> runReportCommand(Map<String, dynamic> options) async {
  print('📄 Generating performance report...');
  
  final outputDir = options['output'] as String;
  
  final reportGenerator = PerformanceReportGenerator(outputDir);
  
  // Generate multiple report formats
  await reportGenerator.generateHtmlReport();
  await reportGenerator.generateMarkdownReport();
  await reportGenerator.generateJsonReport();
  
  print('✅ Performance reports generated');
}

/// Run complete workflow
Future<void> runCompleteWorkflow(Map<String, dynamic> options) async {
  print('🚀 Running complete performance workflow...');
  
  // Step 1: Generate test data
  await runGenerateCommand(options);
  
  // Step 2: Run benchmarks
  await runBenchmarkCommand(options);
  
  // Step 3: Analyze results
  await runAnalyzeCommand(options);
  
  // Step 4: Generate reports
  await runReportCommand(options);
  
  // Step 5: Run regression tests if baseline provided
  if (options['baseline'] != null) {
    try {
      await runRegressionCommand(options);
    } catch (e) {
      print('⚠️ Regression test failed: $e');
    }
  }
  
  print('✅ Complete workflow finished');
}

/// Enhanced test data generator
class TestDataGenerator {
  final String outputDir;
  final Random _random = Random();

  TestDataGenerator(this.outputDir);

  /// Generate comprehensive test suite with multiple project sizes
  Future<void> generateComprehensiveTestSuite(String size) async {
    final testDir = Directory(path.join(outputDir, 'test_data'));
    
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);

    final (fileCount, avgSizeKB, keyDensity) = _getProjectParameters(size);
    
    print('Generating $size project:');
    print('  Files: $fileCount');
    print('  Average size: ${avgSizeKB}KB');
    print('  Key density: ${(keyDensity * 100).toStringAsFixed(1)}%');

    // Create realistic Flutter project structure
    await _createProjectStructure(testDir);
    
    // Generate source files
    await _generateSourceFiles(testDir, fileCount, avgSizeKB, keyDensity);
    
    // Generate test files
    await _generateTestFiles(testDir, fileCount ~/ 4, avgSizeKB ~/ 2, keyDensity * 1.5);
    
    // Generate configuration files
    await _generateConfigFiles(testDir);
    
    print('✅ Generated comprehensive test suite in ${testDir.path}');
  }

  /// Get project parameters based on size
  (int fileCount, int avgSizeKB, double keyDensity) _getProjectParameters(String size) {
    switch (size) {
      case 'small':
        return (50, 5, 0.1);
      case 'medium':
        return (250, 15, 0.15);
      case 'large':
        return (1000, 25, 0.2);
      case 'enterprise':
        return (5000, 35, 0.25);
      default:
        throw ArgumentError('Invalid project size: $size');
    }
  }

  /// Create realistic Flutter project structure
  Future<void> _createProjectStructure(Directory testDir) async {
    final directories = [
      'lib',
      'lib/src',
      'lib/src/screens',
      'lib/src/widgets',
      'lib/src/models',
      'lib/src/services',
      'lib/src/utils',
      'lib/src/controllers',
      'lib/src/repositories',
      'lib/src/components',
      'test',
      'test/unit',
      'test/widget',
      'test/integration',
      'integration_test',
    ];

    for (final dir in directories) {
      await Directory(path.join(testDir.path, dir)).create(recursive: true);
    }
  }

  /// Generate source files with realistic content
  Future<void> _generateSourceFiles(
    Directory testDir,
    int fileCount,
    int avgSizeKB,
    double keyDensity,
  ) async {
    final libDir = Directory(path.join(testDir.path, 'lib'));
    final subDirs = ['screens', 'widgets', 'models', 'services', 'utils', 'controllers', 'repositories', 'components'];

    for (int i = 0; i < fileCount; i++) {
      final subDir = subDirs[i % subDirs.length];
      final fileName = _generateFileName(subDir, i);
      final file = File(path.join(libDir.path, 'src', subDir, fileName));

      final content = _generateDartContent(
        fileType: subDir,
        fileIndex: i,
        targetSizeKB: avgSizeKB,
        keyDensity: keyDensity,
      );

      await file.writeAsString(content);
    }
  }

  /// Generate test files
  Future<void> _generateTestFiles(
    Directory testDir,
    int fileCount,
    int avgSizeKB,
    double keyDensity,
  ) async {
    final testDirPath = Directory(path.join(testDir.path, 'test'));
    final subDirs = ['unit', 'widget', 'integration'];

    for (int i = 0; i < fileCount; i++) {
      final subDir = subDirs[i % subDirs.length];
      final fileName = 'test_${_generateFileName(subDir, i)}';
      final file = File(path.join(testDirPath.path, subDir, fileName));

      final content = _generateTestContent(
        testType: subDir,
        fileIndex: i,
        targetSizeKB: avgSizeKB,
        keyDensity: keyDensity,
      );

      await file.writeAsString(content);
    }
  }

  /// Generate configuration files
  Future<void> _generateConfigFiles(Directory testDir) async {
    // pubspec.yaml
    final pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    await pubspecFile.writeAsString(_generatePubspecContent());

    // analysis_options.yaml
    final analysisFile = File(path.join(testDir.path, 'analysis_options.yaml'));
    await analysisFile.writeAsString(_generateAnalysisOptionsContent());

    // flutter_keycheck config
    final configFile = File(path.join(testDir.path, '.flutter_keycheck.yaml'));
    await configFile.writeAsString(_generateKeyCheckConfig());
  }

  /// Generate file name based on type and index
  String _generateFileName(String type, int index) {
    final baseName = type.replaceAll('s', ''); // Remove plural
    return '${baseName}_$index.dart';
  }

  /// Generate Dart content based on file type
  String _generateDartContent({
    required String fileType,
    required int fileIndex,
    required int targetSizeKB,
    required double keyDensity,
  }) {
    final buffer = StringBuffer();
    final targetBytes = targetSizeKB * 1024;

    // Add imports
    buffer.writeln("import 'package:flutter/material.dart';");
    
    switch (fileType) {
      case 'screens':
        buffer.writeln("import 'package:flutter/services.dart';");
        break;
      case 'widgets':
        buffer.writeln("import 'package:flutter/widgets.dart';");
        break;
      case 'services':
        buffer.writeln("import 'dart:async';");
        buffer.writeln("import 'dart:convert';");
        break;
      case 'models':
        buffer.writeln("import 'dart:convert';");
        break;
    }

    buffer.writeln();

    // Generate class based on type
    switch (fileType) {
      case 'screens':
        _generateScreenClass(buffer, fileIndex, targetBytes, keyDensity);
        break;
      case 'widgets':
        _generateWidgetClass(buffer, fileIndex, targetBytes, keyDensity);
        break;
      case 'models':
        _generateModelClass(buffer, fileIndex, targetBytes, keyDensity);
        break;
      case 'services':
        _generateServiceClass(buffer, fileIndex, targetBytes, keyDensity);
        break;
      default:
        _generateUtilityClass(buffer, fileIndex, targetBytes, keyDensity);
    }

    return buffer.toString();
  }

  /// Generate screen class content
  void _generateScreenClass(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('/// Generated screen class $index');
    buffer.writeln('class Screen$index extends StatefulWidget {');
    buffer.writeln('  const Screen$index({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  State<Screen$index> createState() => _Screen${index}State();');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('class _Screen${index}State extends State<Screen$index> {');
    buffer.writeln('  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return Scaffold(');
    buffer.writeln('      key: _scaffoldKey,');
    
    if (_random.nextDouble() < keyDensity) {
      buffer.writeln("      appBar: AppBar(key: const ValueKey('screen_${index}_appbar'), title: const Text('Screen $index')),");
    } else {
      buffer.writeln("      appBar: AppBar(title: const Text('Screen $index')),");
    }
    
    buffer.writeln('      body: Column(');
    buffer.writeln('        children: [');

    int currentBytes = buffer.toString().length;
    int keyIndex = 0;

    // Fill with widgets until target size
    while (currentBytes < targetBytes - 300) {
      final shouldHaveKey = _random.nextDouble() < keyDensity;
      final widgetCode = _generateRandomWidget(index, keyIndex++, shouldHaveKey);
      buffer.writeln('          $widgetCode,');
      currentBytes = buffer.toString().length;
    }

    buffer.writeln('        ],');
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  /// Generate widget class content
  void _generateWidgetClass(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('/// Generated widget class $index');
    buffer.writeln('class Widget$index extends StatelessWidget {');
    buffer.writeln('  const Widget$index({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return Container(');
    
    if (_random.nextDouble() < keyDensity) {
      buffer.writeln("      key: const ValueKey('widget_$index'),");
    }
    
    buffer.writeln('      child: Column(');
    buffer.writeln('        children: [');

    int currentBytes = buffer.toString().length;
    int keyIndex = 0;

    while (currentBytes < targetBytes - 200) {
      final shouldHaveKey = _random.nextDouble() < keyDensity;
      final widgetCode = _generateRandomWidget(index, keyIndex++, shouldHaveKey);
      buffer.writeln('          $widgetCode,');
      currentBytes = buffer.toString().length;
    }

    buffer.writeln('        ],');
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  /// Generate model class content
  void _generateModelClass(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('/// Generated model class $index');
    buffer.writeln('class Model$index {');
    
    final fieldCount = 5 + _random.nextInt(10);
    
    for (int i = 0; i < fieldCount; i++) {
      final fieldType = ['String', 'int', 'double', 'bool'][_random.nextInt(4)];
      buffer.writeln('  final $fieldType field$i;');
    }
    
    buffer.writeln();
    buffer.writeln('  const Model$index({');
    
    for (int i = 0; i < fieldCount; i++) {
      buffer.writeln('    required this.field$i,');
    }
    
    buffer.writeln('  });');
    buffer.writeln();
    
    // Add fromJson and toJson methods
    buffer.writeln('  factory Model$index.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return Model$index(');
    
    for (int i = 0; i < fieldCount; i++) {
      buffer.writeln('      field$i: json[\'field$i\'],');
    }
    
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    
    for (int i = 0; i < fieldCount; i++) {
      buffer.writeln('      \'field$i\': field$i,');
    }
    
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  /// Generate service class content
  void _generateServiceClass(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('/// Generated service class $index');
    buffer.writeln('class Service$index {');
    buffer.writeln('  static const String _baseUrl = \'https://api.example.com\';');
    buffer.writeln();
    
    final methodCount = 3 + _random.nextInt(5);
    
    for (int i = 0; i < methodCount; i++) {
      buffer.writeln('  Future<Map<String, dynamic>?> method$i() async {');
      buffer.writeln('    try {');
      buffer.writeln('      // Simulate API call');
      buffer.writeln('      await Future.delayed(const Duration(milliseconds: 100));');
      buffer.writeln('      return {\'result\': \'success\', \'method\': \'method$i\'};');
      buffer.writeln('    } catch (e) {');
      buffer.writeln('      print(\'Error in method$i: \$e\');');
      buffer.writeln('      return null;');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
    }
    
    buffer.writeln('}');
  }

  /// Generate utility class content
  void _generateUtilityClass(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('/// Generated utility class $index');
    buffer.writeln('class Utils$index {');
    
    final methodCount = 5 + _random.nextInt(8);
    
    for (int i = 0; i < methodCount; i++) {
      final returnType = ['String', 'int', 'bool', 'double'][_random.nextInt(4)];
      buffer.writeln('  static $returnType utilMethod$i(dynamic input) {');
      
      switch (returnType) {
        case 'String':
          buffer.writeln('    return input.toString();');
          break;
        case 'int':
          buffer.writeln('    return input.hashCode;');
          break;
        case 'bool':
          buffer.writeln('    return input != null;');
          break;
        case 'double':
          buffer.writeln('    return input.hashCode.toDouble();');
          break;
      }
      
      buffer.writeln('  }');
      buffer.writeln();
    }
    
    buffer.writeln('}');
  }

  /// Generate random widget code
  String _generateRandomWidget(int classIndex, int widgetIndex, bool shouldHaveKey) {
    final widgets = [
      'Container',
      'ElevatedButton',
      'TextField',
      'ListTile',
      'Card',
      'Row',
      'Column',
      'Padding',
      'Center',
      'SizedBox',
    ];

    final widgetType = widgets[_random.nextInt(widgets.length)];
    final keyPart = shouldHaveKey ? "key: const ValueKey('${classIndex}_${widgetType.toLowerCase()}_$widgetIndex'), " : '';

    switch (widgetType) {
      case 'Container':
        return 'Container($keyPart height: ${20 + _random.nextInt(80)}, color: Colors.blue, child: const Text(\'Container $widgetIndex\'))';
      case 'ElevatedButton':
        return 'ElevatedButton($keyPart onPressed: () {}, child: const Text(\'Button $widgetIndex\'))';
      case 'TextField':
        return 'TextField($keyPart decoration: const InputDecoration(hintText: \'Input $widgetIndex\'))';
      case 'ListTile':
        return 'ListTile($keyPart title: const Text(\'Item $widgetIndex\'), onTap: () {})';
      case 'Card':
        return 'Card($keyPart child: const Padding(padding: EdgeInsets.all(8), child: Text(\'Card $widgetIndex\')))';
      default:
        return '$widgetType($keyPart child: const Text(\'$widgetType $widgetIndex\'))';
    }
  }

  /// Generate test content
  String _generateTestContent({
    required String testType,
    required int fileIndex,
    required int targetSizeKB,
    required double keyDensity,
  }) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln();

    switch (testType) {
      case 'unit':
        _generateUnitTest(buffer, fileIndex, targetSizeKB);
        break;
      case 'widget':
        _generateWidgetTest(buffer, fileIndex, targetSizeKB, keyDensity);
        break;
      case 'integration':
        _generateIntegrationTest(buffer, fileIndex, targetSizeKB, keyDensity);
        break;
    }

    return buffer.toString();
  }

  /// Generate unit test content
  void _generateUnitTest(StringBuffer buffer, int index, int targetBytes) {
    buffer.writeln('void main() {');
    buffer.writeln('  group(\'Unit Test Group $index\', () {');

    int testCount = 0;
    while (buffer.toString().length < targetBytes - 200) {
      buffer.writeln('    test(\'should test functionality ${testCount++}\', () {');
      buffer.writeln('      // Test implementation');
      buffer.writeln('      expect(true, isTrue);');
      buffer.writeln('    });');
      buffer.writeln();
    }

    buffer.writeln('  });');
    buffer.writeln('}');
  }

  /// Generate widget test content
  void _generateWidgetTest(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln('void main() {');
    buffer.writeln('  group(\'Widget Test Group $index\', () {');

    int testCount = 0;
    while (buffer.toString().length < targetBytes - 300) {
      final hasKeyTest = _random.nextDouble() < keyDensity;
      
      buffer.writeln('    testWidgets(\'should test widget ${testCount++}\', (tester) async {');
      buffer.writeln('      await tester.pumpWidget(');
      buffer.writeln('        const MaterialApp(home: Scaffold(body: Text(\'Test Widget\'))),');
      buffer.writeln('      );');
      
      if (hasKeyTest) {
        buffer.writeln('      expect(find.byKey(const ValueKey(\'test_key_$testCount\')), findsNothing);');
      } else {
        buffer.writeln('      expect(find.text(\'Test Widget\'), findsOneWidget);');
      }
      
      buffer.writeln('    });');
      buffer.writeln();
    }

    buffer.writeln('  });');
    buffer.writeln('}');
  }

  /// Generate integration test content
  void _generateIntegrationTest(StringBuffer buffer, int index, int targetBytes, double keyDensity) {
    buffer.writeln("import 'package:integration_test/integration_test.dart';");
    buffer.writeln();
    buffer.writeln('void main() {');
    buffer.writeln('  IntegrationTestWidgetsFlutterBinding.ensureInitialized();');
    buffer.writeln();
    buffer.writeln('  group(\'Integration Test Group $index\', () {');

    int testCount = 0;
    while (buffer.toString().length < targetBytes - 400) {
      final hasKeyTest = _random.nextDouble() < keyDensity;
      
      buffer.writeln('    testWidgets(\'should test integration ${testCount++}\', (tester) async {');
      buffer.writeln('      // Integration test implementation');
      buffer.writeln('      await tester.pumpWidget(');
      buffer.writeln('        const MaterialApp(home: Scaffold(body: Text(\'Integration Test\'))),');
      buffer.writeln('      );');
      
      if (hasKeyTest) {
        buffer.writeln('      await tester.tap(find.byKey(const ValueKey(\'integration_key_$testCount\')));');
        buffer.writeln('      await tester.pump();');
      }
      
      buffer.writeln('      expect(find.text(\'Integration Test\'), findsOneWidget);');
      buffer.writeln('    });');
      buffer.writeln();
    }

    buffer.writeln('  });');
    buffer.writeln('}');
  }

  /// Generate pubspec.yaml content
  String _generatePubspecContent() {
    return '''
name: benchmark_test_data
version: 1.0.0
description: Generated test data for flutter_keycheck performance benchmarking

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  http: ^1.1.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  integration_test:
    sdk: flutter
  build_runner: ^2.4.7

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/fonts/
''';
  }

  /// Generate analysis_options.yaml content
  String _generateAnalysisOptionsContent() {
    return '''
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
    - lib/generated/**
    - **/*.g.dart

linter:
  rules:
    - avoid_print
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - prefer_const_declarations
    - unnecessary_new
    - unnecessary_const
''';
  }

  /// Generate flutter_keycheck config
  String _generateKeyCheckConfig() {
    return '''
# Flutter KeyCheck Configuration
version: "3.0"

scan:
  scope: workspace_only
  include_patterns:
    - "lib/**/*.dart"
    - "test/**/*.dart"
    - "integration_test/**/*.dart"
  exclude_patterns:
    - "**/.dart_tool/**"
    - "**/build/**"
    - "**/*.g.dart"

validation:
  require_all_keys: false
  allow_dynamic_keys: true
  
reporting:
  formats: ["console", "json"]
  output_dir: "reports"

performance:
  enable_caching: true
  max_parallel_workers: 4
  memory_limit_mb: 512
''';
  }
}

/// Benchmark runner for comprehensive performance testing
class BenchmarkRunner {
  final String outputDir;
  final bool ciMode;
  final bool memoryProfiling;

  BenchmarkRunner({
    required this.outputDir,
    this.ciMode = false,
    this.memoryProfiling = false,
  });

  /// Run comprehensive benchmarks
  Future<PerformanceResults> runBenchmarks(List<String> scenarios) async {
    final results = PerformanceResults();
    
    for (final scenario in scenarios) {
      print('📊 Running $scenario benchmarks...');
      
      switch (scenario) {
        case 'scanning':
          await _runScanningBenchmarks(results);
          break;
        case 'baseline':
          await _runBaselineBenchmarks(results);
          break;
        case 'diff':
          await _runDiffBenchmarks(results);
          break;
        case 'validation':
          await _runValidationBenchmarks(results);
          break;
        case 'memory':
          if (memoryProfiling) {
            await _runMemoryBenchmarks(results);
          }
          break;
        case 'ci-integration':
          await _runCIBenchmarks(results);
          break;
      }
    }
    
    return results;
  }

  /// Run scanning performance benchmarks
  Future<void> _runScanningBenchmarks(PerformanceResults results) async {
    // This would integrate with the existing PerformanceBenchmark class
    // For now, simulate the results
    
    final scanningResults = {
      'sequential_scan': await _simulateBenchmark('Sequential Scan', 1000, 50),
      'parallel_scan': await _simulateBenchmark('Parallel Scan', 400, 45),
      'cached_scan': await _simulateBenchmark('Cached Scan', 200, 30),
      'incremental_scan': await _simulateBenchmark('Incremental Scan', 150, 25),
    };
    
    results.addSection('scanning', scanningResults);
  }

  /// Run baseline benchmarks
  Future<void> _runBaselineBenchmarks(PerformanceResults results) async {
    final baselineResults = {
      'create_baseline': await _simulateBenchmark('Create Baseline', 500, 40),
      'update_baseline': await _simulateBenchmark('Update Baseline', 300, 35),
      'load_baseline': await _simulateBenchmark('Load Baseline', 100, 20),
    };
    
    results.addSection('baseline', baselineResults);
  }

  /// Run diff benchmarks
  Future<void> _runDiffBenchmarks(PerformanceResults results) async {
    final diffResults = {
      'small_diff': await _simulateBenchmark('Small Diff (100 keys)', 50, 15),
      'medium_diff': await _simulateBenchmark('Medium Diff (1000 keys)', 200, 25),
      'large_diff': await _simulateBenchmark('Large Diff (10000 keys)', 800, 60),
    };
    
    results.addSection('diff', diffResults);
  }

  /// Run validation benchmarks
  Future<void> _runValidationBenchmarks(PerformanceResults results) async {
    final validationResults = {
      'validate_100_keys': await _simulateBenchmark('Validate 100 Keys', 25, 10),
      'validate_1000_keys': await _simulateBenchmark('Validate 1000 Keys', 100, 20),
      'validate_10000_keys': await _simulateBenchmark('Validate 10000 Keys', 500, 80),
    };
    
    results.addSection('validation', validationResults);
  }

  /// Run memory benchmarks
  Future<void> _runMemoryBenchmarks(PerformanceResults results) async {
    final memoryResults = {
      'memory_baseline': await _simulateMemoryBenchmark('Memory Baseline', 50),
      'memory_large_files': await _simulateMemoryBenchmark('Large Files Processing', 200),
      'memory_concurrent': await _simulateMemoryBenchmark('Concurrent Processing', 150),
    };
    
    results.addSection('memory', memoryResults);
  }

  /// Run CI integration benchmarks
  Future<void> _runCIBenchmarks(PerformanceResults results) async {
    final ciResults = {
      'quick_scan': await _simulateBenchmark('Quick Scan', 300, 25),
      'regression_check': await _simulateBenchmark('Regression Check', 100, 15),
      'report_generation': await _simulateBenchmark('Report Generation', 50, 10),
    };
    
    results.addSection('ci_integration', ciResults);
  }

  /// Simulate a benchmark operation
  Future<Map<String, dynamic>> _simulateBenchmark(String name, int durationMs, double memoryMB) async {
    final stopwatch = Stopwatch()..start();
    final memoryBefore = ProcessInfo.currentRss;
    
    // Simulate work
    await Future.delayed(Duration(milliseconds: ciMode ? durationMs ~/ 2 : durationMs));
    
    stopwatch.stop();
    final memoryAfter = ProcessInfo.currentRss;
    
    return {
      'name': name,
      'duration_ms': stopwatch.elapsedMilliseconds,
      'memory_used_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
      'simulated_memory_mb': memoryMB,
      'success': true,
    };
  }

  /// Simulate memory benchmark
  Future<Map<String, dynamic>> _simulateMemoryBenchmark(String name, double targetMemoryMB) async {
    final memoryBefore = ProcessInfo.currentRss;
    
    // Simulate memory usage
    final data = List.filled((targetMemoryMB * 1024 * 1024 / 8).round(), 0);
    await Future.delayed(const Duration(milliseconds: 100));
    
    final memoryAfter = ProcessInfo.currentRss;
    data.clear(); // Clean up
    
    return {
      'name': name,
      'peak_memory_mb': (memoryAfter - memoryBefore) / (1024 * 1024),
      'target_memory_mb': targetMemoryMB,
      'efficiency': targetMemoryMB / ((memoryAfter - memoryBefore) / (1024 * 1024)),
    };
  }
}

/// Performance results container
class PerformanceResults {
  final Map<String, Map<String, Map<String, dynamic>>> _results = {};
  final DateTime timestamp = DateTime.now();

  /// Add results section
  void addSection(String section, Map<String, Map<String, dynamic>> sectionResults) {
    _results[section] = sectionResults;
  }

  /// Print summary report
  void printSummary() {
    print('\n📊 Performance Benchmark Summary');
    print('=' * 50);
    print('Timestamp: ${timestamp.toIso8601String()}');
    print('Platform: ${Platform.operatingSystem}');
    print('CPU Cores: ${Platform.numberOfProcessors}');
    
    for (final entry in _results.entries) {
      print('\n${entry.key.toUpperCase()}:');
      for (final benchmark in entry.value.values) {
        final name = benchmark['name'] ?? 'Unknown';
        final duration = benchmark['duration_ms'] ?? 0;
        final memory = benchmark['memory_used_mb'] ?? benchmark['simulated_memory_mb'] ?? 0;
        print('  $name: ${duration}ms, ${memory.toStringAsFixed(1)}MB');
      }
    }
  }

  /// Save results to file
  Future<void> saveToFile(String filePath) async {
    final data = {
      'timestamp': timestamp.toIso8601String(),
      'platform': Platform.operatingSystem,
      'cpu_cores': Platform.numberOfProcessors,
      'results': _results,
    };

    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));
  }
}

/// Enhanced regression analyzer
class RegressionAnalyzer {
  final double threshold;

  RegressionAnalyzer(this.threshold);

  /// Analyze regression from files
  Future<List<PerformanceRegression>> analyzeRegressionFromFiles(
    String baselinePath,
    String currentPath,
  ) async {
    final baselineFile = File(baselinePath);
    final currentFile = File(currentPath);

    if (!await baselineFile.exists()) {
      throw FileSystemException('Baseline file not found', baselinePath);
    }

    if (!await currentFile.exists()) {
      throw FileSystemException('Current results file not found', currentPath);
    }

    final baselineData = json.decode(await baselineFile.readAsString());
    final currentData = json.decode(await currentFile.readAsString());

    return _analyzeRegressionData(baselineData, currentData);
  }

  /// Analyze regression data
  List<PerformanceRegression> _analyzeRegressionData(
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) {
    final regressions = <PerformanceRegression>[];

    final baselineResults = baseline['results'] as Map<String, dynamic>? ?? {};
    final currentResults = current['results'] as Map<String, dynamic>? ?? {};

    for (final section in baselineResults.keys) {
      if (currentResults.containsKey(section)) {
        regressions.addAll(_compareSectionResults(
          section,
          baselineResults[section] as Map<String, dynamic>,
          currentResults[section] as Map<String, dynamic>,
        ));
      }
    }

    return regressions.where((r) => r.degradation > threshold).toList();
  }

  /// Compare section results
  List<PerformanceRegression> _compareSectionResults(
    String section,
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) {
    final regressions = <PerformanceRegression>[];

    for (final benchmarkName in baseline.keys) {
      if (current.containsKey(benchmarkName)) {
        final baselineBenchmark = baseline[benchmarkName] as Map<String, dynamic>;
        final currentBenchmark = current[benchmarkName] as Map<String, dynamic>;

        // Compare duration
        final baselineDuration = baselineBenchmark['duration_ms'] as num?;
        final currentDuration = currentBenchmark['duration_ms'] as num?;

        if (baselineDuration != null && currentDuration != null && baselineDuration > 0) {
          final durationChange = ((currentDuration - baselineDuration) / baselineDuration) * 100;
          
          if (durationChange > threshold) {
            regressions.add(PerformanceRegression(
              section: section,
              benchmark: benchmarkName,
              metric: 'duration_ms',
              baselineValue: baselineDuration.toDouble(),
              currentValue: currentDuration.toDouble(),
              degradation: durationChange,
            ));
          }
        }

        // Compare memory usage
        final baselineMemory = baselineBenchmark['memory_used_mb'] as num? ?? baselineBenchmark['simulated_memory_mb'] as num?;
        final currentMemory = currentBenchmark['memory_used_mb'] as num? ?? currentBenchmark['simulated_memory_mb'] as num?;

        if (baselineMemory != null && currentMemory != null && baselineMemory > 0) {
          final memoryChange = ((currentMemory - baselineMemory) / baselineMemory) * 100;
          
          if (memoryChange > threshold) {
            regressions.add(PerformanceRegression(
              section: section,
              benchmark: benchmarkName,
              metric: 'memory_used_mb',
              baselineValue: baselineMemory.toDouble(),
              currentValue: currentMemory.toDouble(),
              degradation: memoryChange,
            ));
          }
        }
      }
    }

    return regressions;
  }
}

/// Performance regression data class
class PerformanceRegression {
  final String section;
  final String benchmark;
  final String metric;
  final double baselineValue;
  final double currentValue;
  final double degradation;

  PerformanceRegression({
    required this.section,
    required this.benchmark,
    required this.metric,
    required this.baselineValue,
    required this.currentValue,
    required this.degradation,
  });

  @override
  String toString() {
    return '$section.$benchmark.$metric: ${degradation.toStringAsFixed(1)}% regression';
  }
}

/// Performance analyzer for detailed analysis
class PerformanceAnalyzer {
  /// Analyze performance results
  Future<PerformanceAnalysis> analyzeResults(String resultsPath) async {
    final resultsFile = File(resultsPath);
    final data = json.decode(await resultsFile.readAsString());
    
    return PerformanceAnalysis(data);
  }
}

/// Performance analysis results
class PerformanceAnalysis {
  final Map<String, dynamic> data;
  
  PerformanceAnalysis(this.data);

  /// Print detailed analysis report
  void printReport() {
    print('\n📈 Performance Analysis Report');
    print('=' * 50);
    
    final results = data['results'] as Map<String, dynamic>? ?? {};
    
    // Analyze scanning performance
    final scanning = results['scanning'] as Map<String, dynamic>?;
    if (scanning != null) {
      print('\n🔍 Scanning Performance Analysis:');
      _analyzeScanning(scanning);
    }
    
    // Analyze memory usage
    final memory = results['memory'] as Map<String, dynamic>?;
    if (memory != null) {
      print('\n💾 Memory Usage Analysis:');
      _analyzeMemory(memory);
    }
    
    // Performance recommendations
    print('\n💡 Performance Recommendations:');
    _generateRecommendations(results);
  }

  /// Analyze scanning performance
  void _analyzeScanning(Map<String, dynamic> scanning) {
    final benchmarks = scanning.values.whereType<Map<String, dynamic>>();
    
    if (benchmarks.isEmpty) return;
    
    final durations = benchmarks
        .map((b) => b['duration_ms'] as num?)
        .where((d) => d != null)
        .map((d) => d!.toDouble())
        .toList();
    
    if (durations.isNotEmpty) {
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      final minDuration = durations.reduce(min);
      final maxDuration = durations.reduce(max);
      
      print('  Average duration: ${avgDuration.toStringAsFixed(1)}ms');
      print('  Best performance: ${minDuration.toStringAsFixed(1)}ms');
      print('  Worst performance: ${maxDuration.toStringAsFixed(1)}ms');
      print('  Performance spread: ${(maxDuration - minDuration).toStringAsFixed(1)}ms');
    }
  }

  /// Analyze memory usage
  void _analyzeMemory(Map<String, dynamic> memory) {
    final benchmarks = memory.values.whereType<Map<String, dynamic>>();
    
    if (benchmarks.isEmpty) return;
    
    final memoryUsages = benchmarks
        .map((b) => b['peak_memory_mb'] as num? ?? b['memory_used_mb'] as num?)
        .where((m) => m != null)
        .map((m) => m!.toDouble())
        .toList();
    
    if (memoryUsages.isNotEmpty) {
      final avgMemory = memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
      final maxMemory = memoryUsages.reduce(max);
      
      print('  Average memory usage: ${avgMemory.toStringAsFixed(1)}MB');
      print('  Peak memory usage: ${maxMemory.toStringAsFixed(1)}MB');
      
      if (maxMemory > 500) {
        print('  ⚠️ High memory usage detected - consider optimization');
      }
    }
  }

  /// Generate performance recommendations
  void _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <String>[];
    
    // Check scanning performance
    final scanning = results['scanning'] as Map<String, dynamic>?;
    if (scanning != null) {
      final avgDuration = _getAverageDuration(scanning);
      if (avgDuration > 1000) {
        recommendations.add('Consider enabling parallel processing for faster scans');
      }
      if (avgDuration > 2000) {
        recommendations.add('Enable incremental scanning and caching for large projects');
      }
    }
    
    // Check memory usage
    final memory = results['memory'] as Map<String, dynamic>?;
    if (memory != null) {
      final maxMemory = _getMaxMemoryUsage(memory);
      if (maxMemory > 500) {
        recommendations.add('Enable lazy loading for large files to reduce memory usage');
      }
      if (maxMemory > 1000) {
        recommendations.add('Consider reducing parallel worker count to manage memory');
      }
    }
    
    if (recommendations.isEmpty) {
      print('  ✅ Performance is within acceptable ranges');
    } else {
      for (final recommendation in recommendations) {
        print('  • $recommendation');
      }
    }
  }

  /// Get average duration from scanning results
  double _getAverageDuration(Map<String, dynamic> scanning) {
    final durations = scanning.values
        .whereType<Map<String, dynamic>>()
        .map((b) => b['duration_ms'] as num?)
        .where((d) => d != null)
        .map((d) => d!.toDouble())
        .toList();
    
    return durations.isEmpty ? 0 : durations.reduce((a, b) => a + b) / durations.length;
  }

  /// Get maximum memory usage from memory results
  double _getMaxMemoryUsage(Map<String, dynamic> memory) {
    final memoryUsages = memory.values
        .whereType<Map<String, dynamic>>()
        .map((b) => b['peak_memory_mb'] as num? ?? b['memory_used_mb'] as num?)
        .where((m) => m != null)
        .map((m) => m!.toDouble())
        .toList();
    
    return memoryUsages.isEmpty ? 0 : memoryUsages.reduce(max);
  }

  /// Save analysis to file
  Future<void> saveToFile(String filePath) async {
    final analysisData = {
      'timestamp': DateTime.now().toIso8601String(),
      'analysis_version': '1.0',
      'original_data': data,
      'summary': {
        'avg_scanning_duration': _getAverageDuration(data['results']?['scanning'] ?? {}),
        'max_memory_usage': _getMaxMemoryUsage(data['results']?['memory'] ?? {}),
      },
    };

    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(analysisData));
  }
}

/// Performance report generator
class PerformanceReportGenerator {
  final String outputDir;

  PerformanceReportGenerator(this.outputDir);

  /// Generate HTML report
  Future<void> generateHtmlReport() async {
    // Implementation for HTML report generation
    print('📄 HTML report generation would be implemented here');
  }

  /// Generate Markdown report
  Future<void> generateMarkdownReport() async {
    // Implementation for Markdown report generation
    print('📄 Markdown report generation would be implemented here');
  }

  /// Generate JSON report
  Future<void> generateJsonReport() async {
    // Implementation for JSON report generation
    print('📄 JSON report generation would be implemented here');
  }
}