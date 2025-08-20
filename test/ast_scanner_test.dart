import 'package:flutter_keycheck/src/ast_scanner.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  group('AstScanner', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ast_scanner_test_');
      projectPath = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should detect basic Key() usage', () async {
      // Create a test file with keys
      final libDir = Directory(path.join(projectPath, 'lib'))..createSync();
      final testFile = File(path.join(libDir.path, 'test_widget.dart'));
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(key: Key('container_key')),
        Text('Test', key: ValueKey('text_key')),
        ElevatedButton(
          key: Key('button_key'),
          onPressed: () {},
          child: Text('Button'),
        ),
      ],
    );
  }
}
''');

      final scanner = AstScanner(
        projectPath: projectPath,
        verbose: false,
      );

      final result = await scanner.scan();

      expect(result.foundKeys, contains('container_key'));
      expect(result.foundKeys, contains('text_key'));
      expect(result.foundKeys, contains('button_key'));
      expect(result.foundKeys.length, equals(3));
    });

    test('should respect include/exclude filters', () async {
      // Create test files
      final libDir = Directory(path.join(projectPath, 'lib'))..createSync();
      
      File(path.join(libDir.path, 'included.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';
Widget test() => Container(key: Key('included_key'));
''');

      File(path.join(libDir.path, 'excluded.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';
Widget test() => Container(key: Key('excluded_key'));
''');

      final scanner = AstScanner(
        projectPath: projectPath,
        exclude: ['.*excluded.*'],
        verbose: false,
      );

      final result = await scanner.scan();

      expect(result.foundKeys, contains('included_key'));
      expect(result.foundKeys, isNot(contains('excluded_key')));
    });

    test('should track key locations', () async {
      final libDir = Directory(path.join(projectPath, 'lib'))..createSync();
      final testFile = File(path.join(libDir.path, 'test.dart'));
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';
Widget test() => Container(key: Key('test_key'));
''');

      final scanner = AstScanner(
        projectPath: projectPath,
        verbose: false,
      );

      final result = await scanner.scan();

      expect(result.keyLocations['test_key'], isNotNull);
      expect(result.keyLocations['test_key']!.length, equals(1));
      
      final location = result.keyLocations['test_key']!.first;
      expect(location.line, equals(2));
      expect(location.filePath, endsWith('test.dart'));
    });

    test('should count key usage', () async {
      final libDir = Directory(path.join(projectPath, 'lib'))..createSync();
      final testFile = File(path.join(libDir.path, 'test.dart'));
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';
class Test extends StatelessWidget {
  Widget build(context) => Column(children: [
    Container(key: Key('repeated_key')),
    Container(key: Key('repeated_key')),
    Container(key: Key('unique_key')),
  ]);
}
''');

      final scanner = AstScanner(
        projectPath: projectPath,
        verbose: false,
      );

      final result = await scanner.scan();

      expect(result.keyUsageCounts['repeated_key'], equals(2));
      expect(result.keyUsageCounts['unique_key'], equals(1));
    });
  });
}