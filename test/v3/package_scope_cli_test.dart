import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/commands/scan_command_v3.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:args/command_runner.dart';

void main() {
  group('Package Scope CLI Tests', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;

      // Create a minimal Flutter project structure
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
      final result = await runner.run(['scan', '--scope', 'workspace-only']);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('reports').exists(), isTrue);
      expect(await File('reports/key-snapshot.json').exists(), isTrue);
    });

    test('--scope deps-only scans only dependency files', () async {
      final runner = CliRunner();
      final result = await runner.run(['scan', '--scope', 'deps-only']);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('reports').exists(), isTrue);
    });

    test('--scope all scans both workspace and dependencies', () async {
      final runner = CliRunner();
      final result = await runner.run(['scan', '--scope', 'all']);

      // Should complete without errors
      expect(result, equals(ExitCode.ok));

      // Check that output directory was created
      expect(await Directory('reports').exists(), isTrue);
    });

    test('invalid --scope value throws UsageException', () async {
      final runner = CliRunner();

      expect(
        () async => await runner.run(['scan', '--scope', 'invalid']),
        throwsA(isA<UsageException>()),
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
      ]);

      expect(result, equals(ExitCode.ok));
    });
  });
}
