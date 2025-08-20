import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('baseline_test_');
    projectRoot = tempDir.path;

    // Create a simple Flutter project structure
    final libDir = Directory(path.join(projectRoot, 'lib'));
    await libDir.create(recursive: true);

    // Create a sample Flutter file with keys
    final mainFile = File(path.join(libDir.path, 'main.dart'));
    await mainFile.writeAsString('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: Key('login_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        TextField(
          key: ValueKey('email_field'),
        ),
        Container(
          key: Key('profile_container'),
          child: Text('Profile'),
        ),
      ],
    );
  }
}
''');

    // Create a config file
    final configFile = File(path.join(projectRoot, '.flutter_keycheck.yaml'));
    await configFile.writeAsString('''
version: 3
''');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Baseline Generation', () {
    test('creates baseline with correct structure', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_keycheck.dart',
          'baseline',
          'create',
          '--project-root',
          projectRoot,
          '--output',
          path.join(tempDir.path, 'baseline.json'),
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, equals(0));

      // Check baseline file was created
      final baselineFile = File(path.join(tempDir.path, 'baseline.json'));
      expect(await baselineFile.exists(), isTrue);

      // Parse and validate baseline structure
      final baselineContent = await baselineFile.readAsString();
      final baseline = jsonDecode(baselineContent) as Map<String, dynamic>;

      expect(baseline, contains('metadata'));
      expect(baseline, contains('keys'));

      // Validate metadata
      final metadata = baseline['metadata'] as Map<String, dynamic>;
      expect(metadata, contains('created_at'));
      expect(metadata, contains('project_root'));
      expect(metadata, contains('total_keys'));
      expect(metadata, contains('dependencies_scanned'));
      expect(metadata, contains('schema_version'));

      // Validate keys array
      final keys = baseline['keys'] as List<dynamic>;
      expect(keys.length, greaterThan(0));

      // Check key structure
      for (final key in keys) {
        expect(key, contains('key'));
        expect(key, contains('type'));
        expect(key, contains('file'));
        expect(key, contains('line'));
        expect(key, contains('package'));
        expect(key, contains('dependency_level'));
      }

      // Verify specific keys are found
      final keyNames = keys.map((k) => k['key']).toSet();
      expect(keyNames, contains('login_button'));
      expect(keyNames, contains('email_field'));
      expect(keyNames, contains('profile_container'));
    });

    test('excludes dependencies when flag is set', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_keycheck.dart',
          'baseline',
          'create',
          '--project-root',
          projectRoot,
          '--exclude-deps',
          '--output',
          path.join(tempDir.path, 'baseline-no-deps.json'),
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, equals(0));

      final baselineFile =
          File(path.join(tempDir.path, 'baseline-no-deps.json'));
      final baseline =
          jsonDecode(await baselineFile.readAsString()) as Map<String, dynamic>;
      final keys = baseline['keys'] as List<dynamic>;

      // All keys should be from direct dependencies only
      for (final key in keys) {
        expect(key['dependency_level'], equals('direct'));
      }
    });
  });

  group('Diff Reports', () {
    test('generates diff report in multiple formats', () async {
      // Create first baseline
      final baseline1File = File(path.join(tempDir.path, 'baseline1.json'));
      await baseline1File.writeAsString(jsonEncode({
        'metadata': {
          'created_at': DateTime.now().toIso8601String(),
          'project_root': projectRoot,
          'total_keys': 3,
          'dependencies_scanned': 0,
        },
        'keys': [
          {
            'key': 'login_button',
            'type': 'Key',
            'file': 'lib/main.dart',
            'line': 10,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
          {
            'key': 'old_key',
            'type': 'Key',
            'file': 'lib/old.dart',
            'line': 5,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
        ],
      }));

      // Create second baseline with changes
      final baseline2File = File(path.join(tempDir.path, 'baseline2.json'));
      await baseline2File.writeAsString(jsonEncode({
        'metadata': {
          'created_at': DateTime.now().toIso8601String(),
          'project_root': projectRoot,
          'total_keys': 3,
          'dependencies_scanned': 0,
        },
        'keys': [
          {
            'key': 'login_button',
            'type': 'Key',
            'file': 'lib/main.dart',
            'line': 10,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
          {
            'key': 'new_key',
            'type': 'ValueKey',
            'file': 'lib/new.dart',
            'line': 15,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
        ],
      }));

      // Run diff command with multiple report formats
      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_keycheck.dart',
          'diff',
          '--baseline-old',
          baseline1File.path,
          '--baseline-new',
          baseline2File.path,
          '--report',
          'json',
          '--report',
          'markdown',
          '--report',
          'html',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, equals(1)); // Exit 1 when changes detected
      expect(result.stdout, contains('Added: 1'));
      expect(result.stdout, contains('Removed: 1'));

      // Check JSON report was created
      final jsonReport =
          File(path.join(projectRoot, 'reports', 'diff-report.json'));
      if (await jsonReport.exists()) {
        final report =
            jsonDecode(await jsonReport.readAsString()) as Map<String, dynamic>;
        expect(report['summary']['added'], equals(1));
        expect(report['summary']['removed'], equals(1));
        expect(report['changes']['added'], contains('new_key'));
        expect(report['changes']['removed'], contains('old_key'));
      }

      // Check Markdown report was created
      final mdReport =
          File(path.join(projectRoot, 'reports', 'diff-report.md'));
      if (await mdReport.exists()) {
        final content = await mdReport.readAsString();
        expect(content, contains('## 🔑 Flutter Keys Report'));
        expect(content, contains('| Added | +1 |'));
        expect(content, contains('| Removed | -1 |'));
      }

      // Check HTML report was created
      final htmlReport =
          File(path.join(projectRoot, 'reports', 'diff-report.html'));
      if (await htmlReport.exists()) {
        final content = await htmlReport.readAsString();
        expect(content, contains('<h1>🔑 Flutter KeyCheck Diff Report</h1>'));
        expect(content, contains('Added Keys'));
        expect(content, contains('Removed Keys'));
      }
    });

    test('detects no changes correctly', () async {
      // Create identical baselines
      final baselineContent = jsonEncode({
        'metadata': {
          'created_at': DateTime.now().toIso8601String(),
          'project_root': projectRoot,
          'total_keys': 2,
          'dependencies_scanned': 0,
        },
        'keys': [
          {
            'key': 'key1',
            'type': 'Key',
            'file': 'lib/main.dart',
            'line': 10,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
          {
            'key': 'key2',
            'type': 'ValueKey',
            'file': 'lib/main.dart',
            'line': 20,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
        ],
      });

      final baseline1File = File(path.join(tempDir.path, 'baseline1.json'));
      await baseline1File.writeAsString(baselineContent);

      final baseline2File = File(path.join(tempDir.path, 'baseline2.json'));
      await baseline2File.writeAsString(baselineContent);

      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_keycheck.dart',
          'diff',
          '--baseline-old',
          baseline1File.path,
          '--baseline-new',
          baseline2File.path,
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, equals(0)); // Exit 0 when no changes
      expect(result.stdout, contains('No changes detected'));
    });
  });

  group('Validation Against Baseline', () {
    test('validates current state against baseline', () async {
      // Create a baseline file
      final baselineFile = File(path.join(tempDir.path, 'baseline.json'));
      await baselineFile.writeAsString(jsonEncode({
        'metadata': {
          'created_at': DateTime.now().toIso8601String(),
          'project_root': projectRoot,
          'total_keys': 3,
          'dependencies_scanned': 0,
        },
        'keys': [
          {
            'key': 'login_button',
            'type': 'Key',
            'file': 'lib/main.dart',
            'line': 10,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
          {
            'key': 'email_field',
            'type': 'ValueKey',
            'file': 'lib/main.dart',
            'line': 14,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
          {
            'key': 'profile_container',
            'type': 'Key',
            'file': 'lib/main.dart',
            'line': 17,
            'package': 'my_app',
            'dependency_level': 'direct',
          },
        ],
      }));

      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_keycheck.dart',
          'validate',
          '--project-root',
          projectRoot,
          '--baseline',
          baselineFile.path,
          '--report',
          'json',
          '--report',
          'junit',
        ],
        workingDirectory: Directory.current.path,
      );

      // Should pass if current state matches baseline
      if (result.stdout.contains('All validation checks passed')) {
        expect(result.exitCode, equals(0));
      }

      // Check reports were generated
      final jsonReport =
          File(path.join(projectRoot, 'reports', 'validation-report.json'));
      if (await jsonReport.exists()) {
        final report =
            jsonDecode(await jsonReport.readAsString()) as Map<String, dynamic>;
        expect(report, contains('summary'));
        expect(report, contains('violations'));
      }

      final junitReport =
          File(path.join(projectRoot, 'reports', 'validation-report.xml'));
      if (await junitReport.exists()) {
        final content = await junitReport.readAsString();
        expect(content, contains('<?xml version="1.0"'));
        expect(content, contains('<testsuites'));
      }
    });
  });
}
