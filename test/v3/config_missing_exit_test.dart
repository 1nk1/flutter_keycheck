import 'dart:io';
import 'package:test/test.dart';
import '../helpers/cli.dart';

void main() {
  group('Config Missing Exit Tests', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_config_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;

      // Create minimal project
      await File('pubspec.yaml').writeAsString('''
name: test_project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      await Directory('lib').create();
      await File('lib/main.dart').writeAsString('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(key: const Key('test_key'));
  }
}
''');
    });

    tearDown(() async {
      Directory.current = Directory(originalDir);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('--config with missing file returns exit 2', () async {
      await expectExit(
        ['scan', '--config', 'missing_config.yaml'],
        code: 2,
        stderrContains: 'Config file not found: missing_config.yaml',
      );
    });

    test('--config with existing file works normally', () async {
      // Create a valid config file
      await File('.flutter_keycheck.yaml').writeAsString('''
tracked_keys:
  - test_key
''');

      await expectExit(
        ['scan', '--config', '.flutter_keycheck.yaml'],
        code: 0,
      );
    });

    test('validate --config with missing file returns exit 2', () async {
      await expectExit(
        ['validate', '--config', 'does_not_exist.yaml'],
        code: 2,
        stderrContains: 'Config file not found: does_not_exist.yaml',
      );
    });

    test('baseline create --config with missing file returns exit 2', () async {
      await expectExit(
        ['baseline', 'create', '--config', 'no_such_file.yaml'],
        code: 2,
        stderrContains: 'Config file not found: no_such_file.yaml',
      );
    });

    test('diff --config with missing file returns exit 2', () async {
      await expectExit(
        ['diff', '--config', 'absent.yaml'],
        code: 2,
        stderrContains: 'Config file not found: absent.yaml',
      );
    });
  });
}
