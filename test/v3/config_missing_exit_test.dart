import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import '../helpers/cli.dart';

void main() {
  group('Config Missing Exit Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_config_test_');

      // Create minimal project using path.join for cross-platform compatibility
      final pubspecPath = path.join(tempDir.path, 'pubspec.yaml');
      await File(pubspecPath).writeAsString('''
name: test_project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      final libDir = path.join(tempDir.path, 'lib');
      await Directory(libDir).create();

      final mainPath = path.join(libDir, 'main.dart');
      await File(mainPath).writeAsString('''
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
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('--config with missing file returns exit 2', () async {
      await expectExit(
        ['scan', '--config', 'missing_config.yaml'],
        code: 2,
        stderrContains: 'Config file not found:',
        projectRoot: tempDir.path,
      );
    });

    test('--config with existing file works normally', () async {
      // Create a valid config file
      final configPath = path.join(tempDir.path, '.flutter_keycheck.yaml');
      await File(configPath).writeAsString('''
tracked_keys:
  - test_key
''');

      await expectExit(
        ['scan', '--config', '.flutter_keycheck.yaml'],
        code: 0,
        projectRoot: tempDir.path,
      );
    });

    test('validate --config with missing file returns exit 2', () async {
      await expectExit(
        ['validate', '--config', 'does_not_exist.yaml'],
        code: 2,
        stderrContains: 'Config file not found:',
        projectRoot: tempDir.path,
      );
    });

    test('baseline create --config with missing file returns exit 2', () async {
      await expectExit(
        ['baseline', 'create', '--config', 'no_such_file.yaml'],
        code: 2,
        stderrContains: 'Config file not found:',
        projectRoot: tempDir.path,
      );
    });

    test('diff --config with missing file returns exit 2', () async {
      await expectExit(
        ['diff', '--config', 'absent.yaml'],
        code: 2,
        stderrContains: 'Config file not found:',
        projectRoot: tempDir.path,
      );
    });
  });
}
