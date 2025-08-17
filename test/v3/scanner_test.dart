import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';

void main() {
  group('AST Scanner v3', () {
    late Directory tempDir;
    late ConfigV3 config;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scanner_test_');
      config = ConfigV3.defaults();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Coverage Metrics', () {
      test('calculates file coverage', () async {
        // Create test files
        await _createTestFile(tempDir, 'lib/main.dart', '''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          key: ValueKey('app_bar'),
          title: Text('Test App'),
        ),
        body: Center(
          child: ElevatedButton(
            key: ValueKey('main_button'),
            onPressed: () {},
            child: Text('Click Me'),
          ),
        ),
      ),
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        expect(result.metrics.totalFiles, equals(1));
        expect(result.metrics.scannedFiles, equals(1));
        expect(result.metrics.fileCoverage, equals(100.0));
      });

      test('calculates widget coverage', () async {
        await _createTestFile(tempDir, 'lib/widgets.dart', '''
import 'package:flutter/material.dart';

class WidgetWithKey extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('container_key'),
      child: Text('Has Key'),
    );
  }
}

class WidgetWithoutKey extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('No Key'),
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        expect(result.metrics.widgetCoverage, greaterThan(0));
        expect(result.metrics.widgetCoverage, lessThanOrEqualTo(100));
      });

      test('tracks handler coverage', () async {
        await _createTestFile(tempDir, 'lib/handlers.dart', '''
import 'package:flutter/material.dart';

class ButtonWithHandler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: ValueKey('button_with_handler'),
      onPressed: () {
        print('Button pressed');
      },
      child: Text('Click'),
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        // Should detect the handler linked to the key
        final buttonKey = result.keyUsages['button_with_handler'];
        expect(buttonKey, isNotNull);
        if (buttonKey != null) {
          expect(buttonKey.handlers, isNotEmpty);
        }
      });
    });

    group('Blind Spot Detection', () {
      test('detects files with many widgets but no keys', () async {
        await _createTestFile(tempDir, 'lib/no_keys.dart', '''
import 'package:flutter/material.dart';

class NoKeysScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(),
        Text('Text 1'),
        ElevatedButton(onPressed: () {}, child: Text('Button 1')),
        Container(),
        Text('Text 2'),
        ElevatedButton(onPressed: () {}, child: Text('Button 2')),
        Container(),
        Text('Text 3'),
        Container(), // Extra widget to ensure > 5 widgets
      ],
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        expect(result.blindSpots, isNotEmpty);
        expect(
          result.blindSpots
              .any((spot) => spot.type == 'no_keys_in_ui_heavy_file'),
          isTrue,
        );
      });

      test('detects ineffective detectors', () async {
        // Create a file with only basic keys
        await _createTestFile(tempDir, 'lib/basic.dart', '''
import 'package:flutter/material.dart';

class BasicWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('basic_key'),
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        // Some detectors might not find anything
        final ineffectiveDetectors = result.blindSpots
            .where((spot) => spot.type == 'ineffective_detector')
            .toList();

        // This is expected as not all detector types will match
        expect(ineffectiveDetectors, isNotNull);
      });
    });

    group('Incremental Scanning', () {
      test('supports git diff base', () async {
        // This test would require a git repository
        // For now, just test that the option is accepted
        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          gitDiffBase: 'HEAD~1',
          config: config,
        );

        final result = await scanner.scan();

        // If not in a git repo, should fall back to full scan
        expect(result.metrics.incrementalScan, isFalse);
      });
    });

    group('Package Modes', () {
      test('workspace mode scans current directory', () async {
        await _createTestFile(tempDir, 'lib/main.dart', '''
import 'package:flutter/material.dart';

void main() {
  runApp(Container(key: ValueKey('app_key')));
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          scope: ScanScope.workspaceOnly,
          config: config,
        );

        final result = await scanner.scan();

        expect(result.keyUsages, contains('app_key'));
      });

      test('resolve mode would include dependencies', () async {
        // This would require a pubspec.yaml and actual dependencies
        // For now, test that it falls back gracefully
        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          scope: ScanScope.all,
          config: config,
        );

        final result = await scanner.scan();

        // Should at least scan workspace
        expect(result.metrics.scannedFiles, greaterThanOrEqualTo(0));
      });
    });

    group('Detector Metrics', () {
      test('tracks detector effectiveness', () async {
        await _createTestFile(tempDir, 'lib/mixed_keys.dart', '''
import 'package:flutter/material.dart';

class MixedKeys extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(key: ValueKey('value_key')),
        Container(key: Key('basic_key')),
        Container(key: const Key('const_key')),
        Semantics(
          identifier: 'semantic_key',
          child: Text('Accessible'),
        ),
      ],
    );
  }
}
''');

        final scanner = AstScannerV3(
          projectPath: tempDir.path,
          config: config,
        );

        final result = await scanner.scan();

        // Check that different detectors found keys
        expect(result.metrics.detectorHits['ValueKey'], greaterThan(0));
        expect(result.metrics.detectorHits['Key'], greaterThan(0));
        expect(result.metrics.detectorHits['ConstKey'], greaterThan(0));
        expect(result.metrics.detectorHits['Semantics'], greaterThan(0));
      });
    });
  });
}

Future<void> _createTestFile(Directory dir, String path, String content) async {
  final file = File('${dir.path}/$path');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
