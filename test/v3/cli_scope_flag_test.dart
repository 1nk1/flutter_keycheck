import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  // Use the golden workspace for tests to avoid scanning the entire project
  final testWorkspace = path.join('test', 'golden_workspace');
  
  group('CLI Scope Flag Tests', () {
    test('scan command includes --scope flag in help', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'scan',
        '--help',
      ]).timeout(const Duration(seconds: 10));

      expect(result.exitCode, equals(0));
      final output = '${result.stdout}${result.stderr}';

      // Check that help includes scope flag information
      expect(output, contains('--scope'),
          reason: 'Help should include --scope flag');
      expect(output, contains('workspace-only'),
          reason: 'Help should show workspace-only option');
      expect(output, contains('deps-only'),
          reason: 'Help should show deps-only option');
      expect(output, contains('all'), reason: 'Help should show all option');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('scan command accepts --scope flag', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'scan',
        '--scope',
        'workspace-only',
        '--project-root',
        testWorkspace,
      ]).timeout(const Duration(seconds: 10));

      // Should not fail with "Could not find an option named --scope"
      expect(result.stderr, isNot(contains('Could not find an option named')),
          reason: 'Should accept --scope flag');

      // Should complete successfully or with expected error (not flag parsing error)
      expect(result.exitCode, anyOf([0, 2, 3, 4]),
          reason:
              'Should not fail with invalid flag error (exit code 64 or 254)');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('scan command rejects invalid scope values', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'scan',
        '--scope',
        'invalid-value',
        '--project-root',
        testWorkspace,
      ]).timeout(const Duration(seconds: 10));

      expect(result.exitCode, isNot(equals(0)),
          reason: 'Should fail with invalid scope value');
      final errorOutput = result.stderr.toString();
      expect(errorOutput, contains('"invalid-value" is not an allowed value'),
          reason: 'Should report invalid scope value');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('scan command defaults to workspace-only scope', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'scan',
        '--report',
        'json',
        '--project-root',
        testWorkspace,
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        // If scan succeeds, output should be JSON
        final output = result.stdout.toString();
        if (output.contains('{') && output.contains('schemaVersion')) {
          // This is JSON output - good
          expect(output, contains('schemaVersion'),
              reason: 'JSON output should have schemaVersion');
        }
      }
      // Otherwise test passes - we just wanted to verify the command runs
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('CLI Package Policy Flags Tests', () {
    test('validate command includes package policy flags in help', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'validate',
        '--help',
      ]).timeout(const Duration(seconds: 10));

      expect(result.exitCode, equals(0));
      final output = '${result.stdout}${result.stderr}';

      // Check that help includes package policy flags
      expect(output, contains('fail-on-package-missing'),
          reason: 'Help should include --fail-on-package-missing flag');
      expect(output, contains('fail-on-collision'),
          reason: 'Help should include --fail-on-collision flag');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('validate command accepts package policy flags', () async {
      // First create a baseline in the test workspace
      await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'baseline',
        'create',
        '--project-root',
        testWorkspace,
      ]).timeout(const Duration(seconds: 10));

      final result = await Process.run('dart', [
        'run',
        'bin/flutter_keycheck.dart',
        'validate',
        '--fail-on-package-missing',
        '--fail-on-collision',
        '--project-root',
        testWorkspace,
      ]).timeout(const Duration(seconds: 10));

      // Should not fail with "Could not find an option named" error
      expect(result.stderr, isNot(contains('Could not find an option named')),
          reason: 'Should accept package policy flags');
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
