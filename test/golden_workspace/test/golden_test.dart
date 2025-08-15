import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Golden Workspace Tests', () {
    group('Scan Command', () {
      test('scans workspace successfully', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'scan', '--report', 'json'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Scan complete'));
      });

      test('finds expected keys', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'scan', '--report', 'json', '--out-dir', 'reports'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));

        // Check that report was created
        final reportFile = File('reports/key-snapshot.json');
        expect(await reportFile.exists(), isTrue);

        // Parse report
        final report = await reportFile.readAsString();
        expect(report, contains('login_button'));
        expect(report, contains('email_field'));
        expect(report, contains('password_field'));
        expect(report, contains('submit_button'));
      });
    });

    group('Baseline Command', () {
      test('creates baseline', () async {
        // First scan
        await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'scan'],
          workingDirectory: Directory.current.path,
        );

        // Create baseline
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'baseline', 'create'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Baseline created'));
      });
    });

    group('Validate Command', () {
      test('validates against baseline', () async {
        // Ensure baseline exists
        await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'baseline', 'create'],
          workingDirectory: Directory.current.path,
        );

        // Run validation
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'validate', '--strict'],
          workingDirectory: Directory.current.path,
        );

        // Should pass if no changes
        expect(result.exitCode, equals(0));
      });

      test('ci-validate alias works', () async {
        // Ensure baseline exists
        await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'baseline', 'create'],
          workingDirectory: Directory.current.path,
        );

        // Run validation using alias
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'ci-validate'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, anyOf(equals(0), equals(1)));
      });

      test('detects lost critical keys', () async {
        // Create baseline
        await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'baseline', 'create'],
          workingDirectory: Directory.current.path,
        );

        // Modify main.dart to remove a critical key
        final mainFile = File('lib/main.dart');
        final content = await mainFile.readAsString();
        final modified = content.replaceAll(
          "key: const ValueKey('login_button')",
          "// key removed for test",
        );
        await mainFile.writeAsString(modified);

        try {
          // Run validation
          final result = await Process.run(
            'dart',
            ['run', '../../bin/flutter_keycheck_v3.dart', 'validate', '--fail-on-lost'],
            workingDirectory: Directory.current.path,
          );

          // Should fail due to lost critical key
          expect(result.exitCode, equals(1));
          expect(result.stdout.toString(), contains('login_button'));
        } finally {
          // Restore original file
          await mainFile.writeAsString(content);
        }
      });
    });

    group('Diff Command', () {
      test('compares snapshots', () async {
        // Create baseline
        await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'baseline', 'create'],
          workingDirectory: Directory.current.path,
        );

        // Run diff
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'diff', '--baseline', 'registry', '--current', 'scan'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0)); // No changes
        expect(result.stdout.toString(), contains('No changes detected'));
      });
    });

    group('Report Command', () {
      test('generates JSON report', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'report', '--format', 'json'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File('reports/report.json');
        expect(await reportFile.exists(), isTrue);
      });

      test('generates JUnit report', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'report', '--format', 'junit'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File('reports/report.xml');
        expect(await reportFile.exists(), isTrue);

        final content = await reportFile.readAsString();
        expect(content, contains('<?xml version="1.0"'));
        expect(content, contains('<testsuites'));
      });

      test('generates Markdown report', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', 'report', '--format', 'md'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));

        final reportFile = File('reports/report.md');
        expect(await reportFile.exists(), isTrue);

        final content = await reportFile.readAsString();
        expect(content, contains('# 🔍 Key'));
        expect(content, contains('## Summary'));
      });
    });

    group('Exit Codes', () {
      test('returns 0 on success', () async {
        final result = await Process.run(
          'dart',
          ['run', '../../bin/flutter_keycheck_v3.dart', '--version'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));
      });

      test('returns 2 on invalid config', () async {
        // Create invalid config
        final configFile = File('invalid.yaml');
        await configFile.writeAsString('invalid: yaml: content:');

        try {
          final result = await Process.run(
            'dart',
            ['run', '../../bin/flutter_keycheck_v3.dart', '--config', 'invalid.yaml', 'scan'],
            workingDirectory: Directory.current.path,
          );

          expect(result.exitCode, equals(2));
        } finally {
          if (await configFile.exists()) {
            await configFile.delete();
          }
        }
      });
    });
  });
}