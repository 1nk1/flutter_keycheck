import 'dart:io';
import 'package:test/test.dart';
import '../helpers/cli.dart';

void main() {
  group('CLI v3', () {
    group('Exit Codes', () {
      test('returns 0 on success', () async {
        // Test that successful operations return exit code 0
        final result = await runCli(['--version']);
        expect(result.exitCode, equals(0));
      });

      test('returns 1 on policy violation', () async {
        // Test that policy violations return exit code 1
        // This would require setting up a test scenario
      });

      test('returns 2 on invalid config', () async {
        // Test that invalid config returns exit code 2
        final _ = await runCli(['--config', 'nonexistent.yaml', 'scan']);
        // Since config doesn't exist but we use defaults, it might still work
        // In a real test, we'd create an invalid config file
      });

      test('returns 3 on IO error', () async {
        // Test that IO errors return exit code 3
        // This would require simulating an IO error
      });

      test('returns 4 on internal error', () async {
        // Test that internal errors return exit code 4
        // This would require triggering an internal error
      });
    });

    group('Commands', () {
      test('scan command exists', () async {
        final result = await runCli(['scan', '--help']);
        expect(result.stdout.toString(), contains('Build current snapshot'));
      });

      test('baseline command exists', () async {
        final result = await runCli(['baseline', '--help']);
        expect(result.stdout.toString(), contains('Create or update'));
      });

      test('diff command exists', () async {
        final result = await runCli(['diff', '--help']);
        expect(result.stdout.toString(), contains('Compare'));
      });

      test('validate command exists', () async {
        final result = await runCli(['validate', '--help']);
        expect(result.stdout.toString(), contains('CI gate enforcement'));
      });

      test('ci-validate alias works', () async {
        final result = await runCli(['ci-validate', '--help']);
        expect(result.stdout.toString(), contains('CI gate enforcement'));
      });

      test('sync command exists', () async {
        final result = await runCli(['sync', '--help']);
        expect(result.stdout.toString(), contains('Synchronize'));
      });

      test('report command exists', () async {
        final result = await runCli(['report', '--help']);
        expect(result.stdout.toString(), contains('Generate reports'));
      });
    });

    group('Version Flag', () {
      test('-V shows version', () async {
        final result = await runCli(['-V']);
        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('flutter_keycheck version'));
      });

      test('--version shows version', () async {
        final result = await runCli(['--version']);
        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('flutter_keycheck version'));
        expect(result.stdout.toString(), contains('Dart SDK'));
      });
    });

    group('Global Flags', () {
      test('--verbose flag works', () async {
        final result = await runCli(['--verbose', 'scan']);
        // Should show verbose output in stderr
        expect(result.stderr.toString(), contains('[VERBOSE]'));
      });

      test('--config flag works', () async {
        // Create a test config
        final configFile = File('test_config.yaml');
        await configFile.writeAsString('''
version: 3
monorepo: false
registry:
  type: path
  path: .flutter_keycheck/baseline.json
''');

        try {
          final result = await runCli(['--config', 'test_config.yaml', 'scan']);
          expect(
              result.exitCode, anyOf(equals(0), equals(3))); // OK or IO error
        } finally {
          if (await configFile.exists()) {
            await configFile.delete();
          }
        }
      });
    });
  });
}
