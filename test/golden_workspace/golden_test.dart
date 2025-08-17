import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Safe JSON access helpers
Map<String, dynamic> _asMap(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

int _totalKeys(Map<String, dynamic> json) {
  final summary = _asMap(json['summary']);
  if (summary.isNotEmpty && summary['totalKeys'] is num) {
    return (summary['totalKeys'] as num).toInt();
  }
  final keys = json['keys'];
  if (keys is List) return keys.length;
  return 0;
}

void main() {
  // Use absolute paths for reliability
  // When running from test/golden_workspace directory
  final currentDir = Directory.current.path;
  final workspaceDir = currentDir.endsWith('golden_workspace')
      ? currentDir
      : p.join(currentDir, 'test', 'golden_workspace');
  final projectRoot = currentDir.endsWith('golden_workspace')
      ? p.dirname(p.dirname(currentDir))
      : currentDir;
  final binPath = p.join(projectRoot, 'bin', 'flutter_keycheck.dart');

  // Environment for deterministic output
  final testEnv = {
    ...Platform.environment,
    'TZ': 'UTC',
    'NO_COLOR': '1', // Disable colored output for deterministic results
  };

  group('Golden Workspace Tests', () {
    setUpAll(() {
      // Verify workspace structure
      expect(
          File(p.join(workspaceDir, 'lib', 'main.dart')).existsSync(), isTrue,
          reason: 'lib/main.dart must exist');
      expect(
          File(p.join(workspaceDir, 'coverage-thresholds.yaml')).existsSync(),
          isTrue,
          reason: 'coverage-thresholds.yaml must exist');
    });

    group('Scan Command', () {
      @Timeout(Duration(minutes: 2))
      test('scans workspace with correct exit code and schema', () async {
        final result = await Process.run(
          'dart',
          [binPath, 'scan', '--report', 'json'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Explicit exit code assertion
        expect(result.exitCode, equals(0),
            reason: 'Scan should succeed with exit code 0');

        // Parse stdout as JSON
        final output = result.stdout.toString();
        final json = jsonDecode(output);

        // Validate schema version
        expect(json['schemaVersion'], equals('1.0'),
            reason: 'Schema version must be 1.0');

        // Validate structure
        expect(json, contains('timestamp'));
        expect(json, contains('metrics'));
        expect(json, contains('keys'));
      });

      test('finds all expected critical keys', () async {
        final reportDir = p.join(workspaceDir, 'test_reports');

        // Clean up any existing reports
        if (Directory(reportDir).existsSync()) {
          Directory(reportDir).deleteSync(recursive: true);
        }

        final result = await Process.run(
          'dart',
          [binPath, 'scan', '--report', 'json', '--out-dir', 'test_reports'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0),
            reason: 'Scan with report generation should succeed');

        // Check that report was created
        final reportFile = File(p.join(reportDir, 'key-snapshot.json'));
        expect(reportFile.existsSync(), isTrue,
            reason: 'Report file must be created');

        // Parse and validate report
        final report = jsonDecode(await reportFile.readAsString());

        // The report has the scan result wrapped
        final scanResult = report['scan_result'] ?? report;
        
        // Schema validation
        expect(scanResult['schemaVersion'], equals('1.0'));

        // Extract key names from the keys array
        final keys =
            (scanResult['keys'] as List).map((k) => k['key'] as String).toList();

        // Assert all critical keys are present
        expect(
            keys,
            containsAll([
              'login_button',
              'email_field',
              'password_field',
              'submit_button'
            ]),
            reason: 'All critical keys must be found');

        // Clean up
        Directory(reportDir).deleteSync(recursive: true);
      });
    });

    group('Baseline Command', () {
      test('creates baseline with exit code 0', () async {
        // Clean any existing baseline
        final baselineFile =
            File(p.join(workspaceDir, '.flutter_keycheck', 'baseline.json'));
        if (baselineFile.existsSync()) {
          baselineFile.deleteSync();
        }

        // Create baseline
        final result = await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0),
            reason: 'Baseline creation must succeed with exit code 0');
        expect(result.stdout.toString(), contains('Baseline created'));

        // Verify baseline file exists and has correct schema
        expect(baselineFile.existsSync(), isTrue);
        final baseline = jsonDecode(await baselineFile.readAsString());
        expect(baseline['schemaVersion'], equals('1.0'));
      });
    });

    group('Validate Command', () {
      test('validates against baseline successfully', () async {
        // Ensure baseline exists
        await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Run validation
        final result = await Process.run(
          'dart',
          [binPath, 'validate', '--strict'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Should pass with exit code 0
        expect(result.exitCode, equals(0),
            reason: 'Validation should pass when no changes');
      });

      test('validates with coverage thresholds', () async {
        // Create baseline
        await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Run validation with explicit threshold file
        final result = await Process.run(
          'dart',
          [binPath, 'validate', '--config', 'coverage-thresholds.yaml'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0),
            reason: 'Validation with coverage thresholds should pass');

        // Verify it's using the thresholds
        // Note: output could be checked for threshold references
        // final output = result.stdout.toString();
        // The tool should reference thresholds in its output when using them
      });

      @Timeout(Duration(minutes: 2))
      test('detects lost critical keys with exit code 1', () async {
        // Create baseline
        await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Backup and modify main.dart to remove a critical key
        final mainFile = File(p.join(workspaceDir, 'lib', 'main.dart'));
        final originalContent = await mainFile.readAsString();
        final modifiedContent = originalContent.replaceAll(
          "key: const ValueKey('login_button')",
          "// key removed for test",
        );
        await mainFile.writeAsString(modifiedContent);

        try {
          // Run validation
          final result = await Process.run(
            'dart',
            [binPath, 'validate', '--fail-on-lost'],
            workingDirectory: workspaceDir,
            environment: testEnv,
          );

          // Should fail with exit code 1
          expect(result.exitCode, equals(1),
              reason: 'Should fail with exit code 1 when critical key is lost');
          expect(result.stdout.toString(), contains('login_button'),
              reason: 'Output should mention the lost key');
        } finally {
          // Restore original file
          await mainFile.writeAsString(originalContent);
        }
      });

      test('fails validation when threshold violated', () async {
        // Create a custom threshold file with impossible threshold
        final strictThresholdFile =
            File(p.join(workspaceDir, 'strict-thresholds.yaml'));
        await strictThresholdFile.writeAsString('''
version: 1
thresholds:
  file_coverage: 1.0  # Impossible 100% requirement
  widget_coverage: 1.0
fail_on_lost: true
''');

        try {
          // Create baseline
          await Process.run(
            'dart',
            [binPath, 'baseline', 'create'],
            workingDirectory: workspaceDir,
            environment: testEnv,
          );

          // Run validation with strict thresholds
          final result = await Process.run(
            'dart',
            [binPath, 'validate', '--config', 'strict-thresholds.yaml'],
            workingDirectory: workspaceDir,
            environment: testEnv,
          );

          // Should fail due to threshold violation
          expect(result.exitCode, isNot(equals(0)),
              reason: 'Should fail when coverage threshold is not met');
        } finally {
          // Clean up
          if (strictThresholdFile.existsSync()) {
            await strictThresholdFile.delete();
          }
        }
      });
    });

    group('Diff Command', () {
      test('compares snapshots with no changes', () async {
        // Create baseline
        await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Run diff
        final result = await Process.run(
          'dart',
          [binPath, 'diff', '--baseline', 'registry', '--current', 'scan'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0),
            reason: 'Diff should succeed with exit code 0 when no changes');
        expect(result.stdout.toString(), contains('No changes detected'));
      });
    });

    group('Report Command', () {
      @Timeout(Duration(minutes: 2))
      test('generates valid JSON report with schema', () async {
        final reportDir = p.join(workspaceDir, 'test_reports');

        // Clean up any existing reports
        if (Directory(reportDir).existsSync()) {
          Directory(reportDir).deleteSync(recursive: true);
        }
        Directory(reportDir).createSync();

        final result = await Process.run(
          'dart',
          [binPath, 'report', '--format', 'json', '--out-dir', 'test_reports'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File(p.join(reportDir, 'report.json'));
        expect(reportFile.existsSync(), isTrue);

        // Validate JSON structure and schema
        final report = jsonDecode(await reportFile.readAsString());
        final schemaVersion = report['schemaVersion'];
        expect(schemaVersion, isNotNull,
            reason: 'Report must have schema version field');
        expect(schemaVersion, equals('1.0'),
            reason: 'Report must have schema version 1.0');

        // Clean up
        Directory(reportDir).deleteSync(recursive: true);
      });

      test('generates valid JUnit XML report', () async {
        final reportDir = p.join(workspaceDir, 'test_reports');
        if (Directory(reportDir).existsSync()) {
          Directory(reportDir).deleteSync(recursive: true);
        }
        Directory(reportDir).createSync();

        final result = await Process.run(
          'dart',
          [binPath, 'report', '--format', 'junit', '--out-dir', 'test_reports'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File(p.join(reportDir, 'report.xml'));
        expect(reportFile.existsSync(), isTrue);

        final content = await reportFile.readAsString();
        expect(content, contains('<?xml version="1.0"'));
        expect(content, contains('<testsuites'));

        // Clean up
        Directory(reportDir).deleteSync(recursive: true);
      });

      test('generates valid Markdown report', () async {
        final reportDir = p.join(workspaceDir, 'test_reports');
        if (Directory(reportDir).existsSync()) {
          Directory(reportDir).deleteSync(recursive: true);
        }
        Directory(reportDir).createSync();

        final result = await Process.run(
          'dart',
          [binPath, 'report', '--format', 'md', '--out-dir', 'test_reports'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File(p.join(reportDir, 'report.md'));
        expect(reportFile.existsSync(), isTrue);

        final content = await reportFile.readAsString();
        expect(content, contains('# 🔍 Key'));
        expect(content, contains('## Summary'));

        // Clean up
        Directory(reportDir).deleteSync(recursive: true);
      });
    });

    group('Exit Codes', () {
      test('returns 0 on success', () async {
        final result = await Process.run(
          'dart',
          [binPath, '--version'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(0),
            reason: 'Version command must return exit code 0');
      });

      test('returns 2 on invalid config', () async {
        // Create invalid config with truly invalid YAML
        final configFile = File(p.join(workspaceDir, 'invalid.yaml'));
        await configFile.writeAsString('[[[this is not valid yaml');

        try {
          final result = await Process.run(
            'dart',
            [binPath, 'scan', '--config', 'invalid.yaml'],
            workingDirectory: workspaceDir,
            environment: testEnv,
          );

          expect(result.exitCode, equals(2),
              reason: 'Invalid config must return exit code 2');
        } finally {
          if (configFile.existsSync()) {
            await configFile.delete();
          }
        }
      });

      test('returns 2 on invalid option', () async {
        // Try to use an invalid option
        final result = await Process.run(
          'dart',
          [binPath, 'scan', '--invalid-option'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, equals(2),
            reason: 'Invalid option should return exit code 2');
      });
    });

    group('CI Aliases', () {
      test('ci-validate alias works correctly', () async {
        // Ensure baseline exists
        await Process.run(
          'dart',
          [binPath, 'baseline', 'create'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        // Run validation using alias
        final result = await Process.run(
          'dart',
          [binPath, 'ci-validate'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        expect(result.exitCode, anyOf(equals(0), equals(1)),
            reason:
                'ci-validate should return 0 (success) or 1 (policy violation)');
      });
    });
  });
}
