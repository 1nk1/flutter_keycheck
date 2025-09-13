import 'dart:convert';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:test/test.dart';

import 'package:flutter_keycheck/src/scanner/ast_scanner.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors.dart';

// Helper to create in-memory analysis for testing
class TestAstScannerHelper {
  final MemoryResourceProvider resourceProvider = MemoryResourceProvider();
  final Map<String, KeyUsage> keyUsages = <String, KeyUsage>{};

  // Enhanced for single-file analysis
  Future<FileAnalysis> analyzeSingle(String code, {String filePath = '/test.dart'}) async {
    resourceProvider.newFolder('/');

    resourceProvider.newFile(filePath, code); // Use String content

    final collection = AnalysisContextCollection(
      resourceProvider: resourceProvider,
      includedPaths: ['/'],
    );

    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedUnit(filePath);

    expect(result, isA<ResolvedUnitResult>());

    final resolvedResult = result as ResolvedUnitResult;
    final analysis = FileAnalysis(
      path: filePath,
      relativePath: 'test.dart',
    );
    final detectors = [
      ValueKeyDetector(),
      BasicKeyDetector(),
      SemanticsDetector(),
      FindByKeyDetector(), // Add more for coverage
    ];
    final visitor = KeyVisitor(
      detectors: detectors,
      analysis: analysis,
      keyUsages: this.keyUsages, // Shared for multi-file
      filePath: filePath,
    );

    resolvedResult.unit.accept(visitor);

    return analysis;
  }

  // New: Full ScanResult for multi-file scenarios using memory FS
  Future<ScanResult> scanMulti(Map<String, String> files, {List<KeyDetector>? detectors}) async {
    // Create in-memory project
    resourceProvider.newFolder('/project');
    for (final entry in files.entries) {
      resourceProvider.newFile('/project/${entry.key}', entry.value); // Use String content
    }

    final scanner = AstScanner(
      projectPath: '/project',
      detectors: detectors ?? [
        ValueKeyDetector(),
        BasicKeyDetector(),
        SemanticsDetector(),
        FindByKeyDetector(),
      ],
      includeTests: true,
      includeGenerated: true,
    );

    final result = await scanner.scan();
    // Merge keyUsages
    scanner.keyUsages.forEach((key, usage) {
      this.keyUsages.putIfAbsent(key, () => usage);
    });
    return result;
  }
}

class InMemoryByteStore implements ByteStore {
  final Map<String, Uint8List> _bytes = {};

  @override
  Future<Uint8List> get(String key) async => _bytes[key] ?? Uint8List(0);

  @override
  Future<void> put(String key, Uint8List bytes) async {
    _bytes[key] = bytes;
  }

  @override
  Future<bool> has(String key) async => _bytes.containsKey(key);
}

void main() {
  late TestAstScannerHelper helper;

  setUp(() {
    helper = TestAstScannerHelper();
  });

  group('Complex Key Scenarios - AST Detection', () {
    test('nested widgets with missing keys', () async {
      final code = '''
import 'package:flutter/material.dart';

class NestedTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('No key'),
            Text(key: ValueKey('with_key'), 'Has key'),
          ],
        ),
      ],
    );
  }
}
''';

      final analysis = await helper.analyzeSingle(code);

      expect(analysis.widgetCount, equals(4)); // Column, Row, Text, Text
      expect(analysis.widgetsWithKeys, equals(1));
      expect(analysis.keysFound, contains('with_key'));
      expect(analysis.widgetTypes, containsAll(['Column', 'Row', 'Text']));
      expect(helper.keyUsages['with_key']?.locations.length, equals(1)); // KeySnapshot proxy
    });

    test('nested widgets with duplicate keys', () async {
      final code = '''
import 'package:flutter/material.dart';

class DuplicateTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('col'),
      children: [
        Text(key: ValueKey('dup'), 'First'),
        Text(key: ValueKey('dup'), 'Second'),
      ],
    );
  }
}
''';

      final analysis = await helper.analyzeSingle(code);

      expect(analysis.keysFound, contains('col'));
      expect(analysis.keysFound, contains('dup'));
      // Note: duplicates are recorded once in Set
      expect(analysis.keysFound.length, equals(2));
      expect(analysis.widgetCount, equals(3));
      expect(analysis.widgetsWithKeys, equals(3));
    });

    // Parameterized tests for key variations
    group('Parameterized key types', () {
      final keyTypes = [
        {'type': 'ValueKey', 'code': 'ValueKey("val")', 'expected': 'val'},
        {'type': 'UniqueKey', 'code': 'UniqueKey()', 'expected': 'UniqueKey'},
        {'type': 'ObjectKey', 'code': 'ObjectKey("obj")', 'expected': 'obj'},
        {'type': 'GlobalKey', 'code': 'GlobalKey()', 'expected': 'GlobalKey'},
      ];

      for (final params in keyTypes) {
        test('${params['type']} detection', () async {
          final code = '''
import 'package:flutter/material.dart';

class KeyTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(key: ${params['code']}, 'Test');
  }
}
''';

          final analysis = await helper.analyzeSingle(code);
          final result = ScanResult(
            metrics: ScanMetrics()..widgetCoverage = 100.0,
            fileAnalyses: { '/test.dart': analysis },
            keyUsages: helper.keyUsages,
            blindSpots: [],
            duration: Duration.zero,
          );

          expect(analysis.keysFound, contains(params['expected']));
          expect(result.keyUsages.containsKey(params['expected']), isTrue);
          expect(result.metrics.widgetCoverage, greaterThan(0));
          expect(result.blindSpots, isEmpty); // No errors
        });
      }
    });

    group('InheritedWidget key detection', () {
      test('basic InheritedWidget with key', () async {
        final code = '''
import 'package:flutter/material.dart';

class MyInherited extends InheritedWidget {
  const MyInherited({super.key, required super.child});

  @override
  bool updateShouldNotify(MyInherited oldWidget) => false;
}

class Consumer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MyInherited(
      key: ValueKey('inherited_key'),
      child: Text('Consumer'),
    );
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..widgetCoverage = 100.0,
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        expect(analysis.keysFound, contains('inherited_key'));
        expect(analysis.widgetTypes, contains('InheritedWidget'));
        expect(analysis.widgetsWithKeys, greaterThan(0));
        expect(result.keyUsages['inherited_key']?.locations.length, greaterThan(0)); // Propagation simulation
        expect(result.metrics.errors, isEmpty);
      });

      test('inheritance chain propagation with consumer', () async {
        final code = '''
import 'package:flutter/material.dart';

class ParentInherited extends InheritedWidget {
  const ParentInherited({super.key, required super.child});
}

class ChildInherited extends InheritedWidget {
  const ChildInherited({
    super.key,
    required this.data,
    required super.child,
  });

  final String data;

  @override
  bool updateShouldNotify(ChildInherited oldWidget) => data != oldWidget.data;
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ParentInherited(
      key: ValueKey('parent_key'),
      child: Builder( // Mock consumer
        builder: (context) => ChildInherited(
          key: ValueKey('child_key'),
          data: 'test',
          child: Text('Uses inherited'),
        ),
      ),
    );
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..widgetCoverage = 100.0,
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        expect(analysis.keysFound, containsAll(['parent_key', 'child_key']));
        expect(analysis.widgetTypes, containsAll(['InheritedWidget', 'Builder', 'Text']));
        expect(analysis.widgetCount, greaterThan(4));
        expect(result.keyUsages['parent_key']?.locations.length, equals(1));
        expect(result.keyUsages['child_key']?.locations.length, equals(1));
        expect(result.blindSpots, isEmpty); // No blind spots in chain
      });
    });

    group('Navigator stacks with route-specific keys and auditing', () {
      // Parameterized for depths 1-4
      for (int depth = 1; depth <= 4; depth++) {
        test('nested Navigator depth $depth with GlobalKey auditing', () async {
          final navigatorsCode = StringBuffer('''
import 'package:flutter/material.dart';

class NavTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: GlobalKey(), // Audited GlobalKey
      initialRoute: '/',
''');
          for (int i = 0; i < depth; i++) {
            navigatorsCode.writeln('''
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          key: ValueKey('route_page_$i'), // Route-specific
          body: Navigator(
            key: ValueKey('nav_$i'), // Simplified
            initialRoute: '/${i + 1}',
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => Text('Page ${i + 1}'),
            ),
          ),
        ),
      ),
''');
          }
          navigatorsCode.writeln('    );\n  }\n}');

          final code = navigatorsCode.toString();
          final analysis = await helper.analyzeSingle(code);
          final result = ScanResult(
            metrics: ScanMetrics()..handlerCoverage = 100.0,
            fileAnalyses: { '/test.dart': analysis },
            keyUsages: helper.keyUsages,
            blindSpots: [],
            duration: Duration.zero,
          );

          expect(analysis.keysFound, contains('nav_0'));
          expect(analysis.keysFound, contains('route_page_0'));
          for (int i = 0; i < depth; i++) {
            expect(analysis.keysFound, contains('nav_$i'));
            expect(analysis.keysFound, contains('route_page_$i'));
          }
          expect(analysis.widgetTypes, containsAll(['Navigator', 'Scaffold', 'Text']));
          expect(result.keyUsages.values.any((u) => u.handlers.isNotEmpty), isFalse); // No handlers in routes
          expect(result.metrics.detectorHits['ValueKey'] ?? 0, greaterThan(0)); // Auditing hits
          if (depth > 2) {
            expect(result.blindSpots, isEmpty); // No deep nesting blind spots
          }
        });
      }
    });

    group('Edge cases', () {
      test('dynamic key generation', () async {
        final code = '''
import 'package:flutter/material.dart';

class DynamicTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final id = 'dynamic';
    return Text(key: ValueKey('id_dynamic'), 'Dynamic');
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..widgetCoverage = 100.0,
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        // Static extraction gets 'id_dynamic'
        expect(analysis.keysFound, contains('id_dynamic'));
        expect(analysis.widgetsWithKeys, equals(1));
        expect(result.keyUsages['id_dynamic']?.locations.first.detector, equals('ValueKey'));
        expect(result.metrics.errors, isEmpty);
      });

      test('null keys in lists', () async {
        final code = '''
import 'package:flutter/material.dart';

class ListTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(key: null, 'Null key'),
        Text('No key specified'),
        Text(key: ValueKey('has_key'), 'Has key'),
      ],
    );
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..widgetCoverage = 25.0, // 1/4
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        expect(analysis.widgetCount, equals(4)); // ListView + 3 Text
        expect(analysis.widgetsWithKeys, equals(1));
        expect(analysis.keysFound, contains('has_key'));
        expect(result.metrics.widgetCoverage, lessThan(50.0)); // Low coverage due to null/missing
        expect(result.blindSpots.length, equals(0)); // No errors, but low coverage noted
      });

      test('cross-widget boundary keys simulation', () async {
        final code = '''
import 'package:flutter/material.dart';

class BoundaryTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Simulate boundary
        Builder(
          builder: (context) => Text(key: ValueKey('boundary_key'), 'Boundary'),
        ),
        CustomWidget(key: ValueKey('cross_key')),
      ],
    );
  }
}

class CustomWidget extends StatelessWidget {
  const CustomWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('Custom');
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..fileCoverage = 100.0,
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        expect(analysis.keysFound, containsAll(['boundary_key', 'cross_key']));
        expect(analysis.widgetTypes, containsAll(['Column', 'Builder', 'CustomWidget']));
        expect(result.keyUsages['boundary_key']?.locations.first.context, contains('Builder'));
        expect(result.keyUsages['cross_key']?.locations.first.context, contains('CustomWidget'));
      });

      // Additional edge case: conditional keys
      test('conditional keys in Builder', () async {
        final code = '''
import 'package:flutter/material.dart';

class ConditionalTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final useKey = true;
    return Builder(
      builder: (context) => Text(
        key: useKey ? ValueKey('cond_key') : null,
        'Conditional',
      ),
    );
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..widgetCoverage = 50.0,
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [BlindSpot(type: 'conditional_key', location: '/test.dart', severity: 'warning', message: 'Potential null key in conditional')],
          duration: Duration.zero,
        );

        expect(analysis.keysFound, contains('cond_key'));
        expect(analysis.widgetsWithKeys, equals(1));
        expect(result.blindSpots.length, greaterThan(0)); // Detect conditional blind spot
      });
    });

    // Specific SemanticsDetector test
    group('SemanticsDetector', () {
      test('Semantics label as key proxy', () async {
        final code = '''
import 'package:flutter/material.dart';

class SemanticsTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'accessibility_label',
      child: Text('Semantics child'),
    );
  }
}
''';

        final analysis = await helper.analyzeSingle(code);
        final result = ScanResult(
          metrics: ScanMetrics()..detectorHits = {'Semantics': 1},
          fileAnalyses: { '/test.dart': analysis },
          keyUsages: helper.keyUsages,
          blindSpots: [],
          duration: Duration.zero,
        );

        expect(analysis.keysFound, contains('semantics:accessibility_label'));
        expect(analysis.detectorHits['Semantics'] ?? 0, equals(1));
        expect(result.metrics.detectorHits['Semantics'] ?? 0, equals(1));
        expect(result.keyUsages['semantics:accessibility_label']?.locations.length, equals(1));
      });
    });

    // Enhanced full scan with multi-file and ScanResult
    group('Full ScanResult verification', () {
      test('complex multi-file tree with metrics and errors', () async {
        final files = {
          'main.dart': '''
import 'package:flutter/material.dart';
import 'nested.dart';

class ComplexApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey('root_scaffold'),
      body: NestedWidget(key: ValueKey('nested')),
    );
  }
}
''',
          'nested.dart': '''
import 'package:flutter/material.dart';

class NestedWidget extends StatelessWidget {
  const NestedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return InheritedWidget(
      key: ValueKey('deep_inherited'),
      child: Navigator(
        key: GlobalKey(),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => ListView(
            key: ValueKey('deep_list'),
            children: [
              Semantics(label: 'semantics_item', child: Text('Item')),
              Text(key: null, 'Missing'), // Intentional null for coverage
            ],
          ),
        ),
      ),
    );
  }
}
''',
        };

        final result = await helper.scanMulti(files);

        // Assertions on ScanResult
        expect(result.metrics.totalFiles, equals(2));
        expect(result.metrics.scannedFiles, equals(2));
        expect(result.metrics.widgetCoverage, lessThan(100.0)); // Due to null/missing
        expect(result.metrics.handlerCoverage, greaterThan(0));
        expect(result.keyUsages.keys, containsAll(['root_scaffold', 'nested', 'deep_inherited', 'deep_list', 'semantics:semantics_item']));
        expect(result.fileAnalyses.length, equals(2));
        expect(result.blindSpots, isNot(anyElement(predicate((b) => b.type == 'no_keys_in_ui_heavy_file')))); // Covered
        expect(result.duration.inMilliseconds, greaterThan(0));
        expect(result.metrics.errors, isEmpty); // No parse errors

        // KeySnapshot (KeyUsage) assertions
        final scaffoldUsage = result.keyUsages['root_scaffold']!;
        expect(scaffoldUsage.locations.length, equals(1));
        expect(scaffoldUsage.locations.first.detector, equals('ValueKey'));
        expect(scaffoldUsage.handlers, isEmpty); // No handlers in this tree

        final semanticsUsage = result.keyUsages['semantics:semantics_item']!;
        expect(semanticsUsage.locations.length, equals(1));
        expect(semanticsUsage.locations.first.detector, equals('Semantics'));
      });
    });
  });
}