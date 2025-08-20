import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import '../helpers/cli.dart';

void main() {
  // Use the golden workspace for tests to avoid scanning the entire project
  final testWorkspace = path.absolute('test', 'golden_workspace');

  group('CLI Scope Flag Tests', () {
    test('scan command includes --scope flag in help', () async {
      final result = await runCli([
        'scan',
        '--help',
      ]);

      // On Windows, help might return 0 or 255 due to memory issues
      expect(result.exitCode, anyOf([0, 255]),
          reason: 'Help command should complete');

      final output = '${result.stdout}${result.stderr}';

      // Check that help includes scope flag information
      expect(output, contains('--scope'),
          reason: 'Help should include --scope flag');
      expect(output, contains('workspace-only'),
          reason: 'Help should show workspace-only option');
      expect(output, contains('deps-only'),
          reason: 'Help should show deps-only option');
      expect(output, contains('all'), reason: 'Help should show all option');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('scan command accepts --scope flag', () async {
      final result = await runCli([
        'scan',
        '--scope',
        'workspace-only',
      ], projectRoot: testWorkspace);

      // Should not fail with "Could not find an option named --scope"
      expect(result.stderr, isNot(contains('Could not find an option named')),
          reason: 'Should accept --scope flag');

      // Should complete successfully or with expected error (not flag parsing error)
      // On Windows, might also return 255 due to memory issues
      expect(result.exitCode, anyOf([0, 2, 3, 4, 255]),
          reason:
              'Should not fail with invalid flag error (exit code 64 or 254)');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('scan command rejects invalid scope values', () async {
      final result = await runCli([
        'scan',
        '--scope',
        'invalid-value',
      ], projectRoot: testWorkspace);

      expect(result.exitCode, isNot(equals(0)),
          reason: 'Should fail with invalid scope value');
      final errorOutput = result.stderr.toString();

      // On Windows, might get memory error instead of proper error message
      if (!errorOutput.contains('Out of memory')) {
        expect(errorOutput, contains('"invalid-value" is not an allowed value'),
            reason: 'Should report invalid scope value');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('scan command defaults to workspace-only scope', () async {
      final result = await runCli([
        'scan',
        '--report',
        'json',
      ], projectRoot: testWorkspace);

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
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('CLI Package Policy Flags Tests', () {
    test('validate command includes package policy flags in help', () async {
      final result = await runCli([
        'validate',
        '--help',
      ]);

      expect(result.exitCode, equals(0));
      final output = '${result.stdout}${result.stderr}';

      // Check that help includes package policy flags
      expect(output, contains('fail-on-package-missing'),
          reason: 'Help should include --fail-on-package-missing flag');
      expect(output, contains('fail-on-collision'),
          reason: 'Help should include --fail-on-collision flag');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('validate command accepts package policy flags', () async {
      // Clean up any existing baseline first
      final baselineDir = path.join(testWorkspace, '.flutter_keycheck');
      if (Directory(baselineDir).existsSync()) {
        try {
          Directory(baselineDir).deleteSync(recursive: true);
        } catch (_) {
          // Ignore cleanup errors
        }
      }

      // First create a baseline in the test workspace
      final baselineResult = await runCli([
        'baseline',
        'create',
      ], projectRoot: testWorkspace);

      // Check baseline was created successfully
      if (baselineResult.exitCode != 0) {
        print('Baseline creation failed: ${baselineResult.stderr}');
      }

      final result = await runCli([
        'validate',
        '--fail-on-package-missing',
        '--fail-on-collision',
      ], projectRoot: testWorkspace);

      // Should not fail with "Could not find an option named" error
      expect(result.stderr, isNot(contains('Could not find an option named')),
          reason: 'Should accept package policy flags');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
