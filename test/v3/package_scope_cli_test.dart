import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/commands/scan_command_v3.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import '../helpers/cli.dart';

void main() {
  group('Package Scope CLI Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_test_');

      // Create a minimal Flutter project structure
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      await Directory('${tempDir.path}/lib').create();
      await File('${tempDir.path}/lib/main.dart').writeAsString('''
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

    test('ScanScope enum values match CLI strings', () {
      expect(ScanScope.workspaceOnly.value, equals('workspace-only'));
      expect(ScanScope.depsOnly.value, equals('deps-only'));
      expect(ScanScope.all.value, equals('all'));
    });

    test('ScanScope.fromString handles all valid values', () {
      expect(ScanScope.fromString('workspace-only'),
          equals(ScanScope.workspaceOnly));
      expect(ScanScope.fromString('deps-only'), equals(ScanScope.depsOnly));
      expect(ScanScope.fromString('all'), equals(ScanScope.all));
    });

    test('ScanScope.fromString defaults to workspaceOnly for invalid input',
        () {
      expect(ScanScope.fromString('invalid'), equals(ScanScope.workspaceOnly));
      expect(ScanScope.fromString(''), equals(ScanScope.workspaceOnly));
    });

    test('--scope flag is registered in ScanCommandV3', () {
      final command = ScanCommandV3();
      final parser = command.argParser;

      expect(parser.options.containsKey('scope'), isTrue);
      final scopeOption = parser.options['scope']!;
      expect(scopeOption.allowed, contains('workspace-only'));
      expect(scopeOption.allowed, contains('deps-only'));
      expect(scopeOption.allowed, contains('all'));
      expect(scopeOption.defaultsTo, equals('workspace-only'));
    });

    test('--scope workspace-only scans only workspace files', () async {
      final runner = CliRunner();
      final result = await runner.run(['scan', '--scope', 'workspace-only', '--project-root', tempDir.path]);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('${tempDir.path}/reports').exists(), isTrue);
      expect(await File('${tempDir.path}/reports/key-snapshot.json').exists(), isTrue);
    });

    test('--scope deps-only scans only dependency files', () async {
      final runner = CliRunner();
      final result = await runner.run(['scan', '--scope', 'deps-only', '--project-root', tempDir.path]);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('${tempDir.path}/reports').exists(), isTrue);
    });

    test('--scope all scans both workspace and dependencies', () async {
      final runner = CliRunner();
      final result = await runner.run(['scan', '--scope', 'all', '--project-root', tempDir.path]);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('${tempDir.path}/reports').exists(), isTrue);
    });

    test('invalid --scope value returns exit 2', () async {
      await expectExit(
        ['scan', '--scope', 'invalid'],
        code: 2,
        stderrContains: '"invalid" is not an allowed value',
        projectRoot: tempDir.path,
      );
    });

    test('--scope flag works with other flags', () async {
      final runner = CliRunner();
      final result = await runner.run([
        'scan',
        '--scope',
        'workspace-only',
        '--include-tests',
        '--report',
        'json',
        '--project-root',
        tempDir.path,
      ]);

      expect(result, equals(ExitCode.ok));
    });
  });
}
