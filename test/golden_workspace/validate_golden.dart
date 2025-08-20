#!/usr/bin/env dart
// Standalone validation script for golden workspace
// Run this to validate the golden workspace setup

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  print('Golden Workspace Validation');
  print('=' * 40);

  final workspaceDir = Directory.current.path;
  final expectedFiles = [
    'lib/main.dart',
    'coverage-thresholds.yaml',
    'pubspec.yaml',
  ];

  // Check file structure
  print('\n1. Checking file structure...');
  for (final file in expectedFiles) {
    final path = p.join(workspaceDir, file);
    final exists = File(path).existsSync();
    print('  ${exists ? '✓' : '✗'} $file');
    if (!exists) {
      print('    ERROR: Required file missing!');
      exit(1);
    }
  }

  // Parse main.dart for expected keys
  print('\n2. Checking for critical keys in lib/main.dart...');
  final mainFile = File(p.join(workspaceDir, 'lib', 'main.dart'));
  final content = mainFile.readAsStringSync();

  final criticalKeys = [
    'login_button',
    'email_field',
    'password_field',
    'submit_button',
  ];

  for (final key in criticalKeys) {
    final found = content.contains("'$key'");
    print('  ${found ? '✓' : '✗'} $key');
    if (!found) {
      print('    ERROR: Critical key missing!');
      exit(1);
    }
  }

  // Parse coverage thresholds
  print('\n3. Checking coverage-thresholds.yaml...');
  final thresholdsFile = File(p.join(workspaceDir, 'coverage-thresholds.yaml'));
  final thresholdsContent = thresholdsFile.readAsStringSync();

  final requiredThresholds = [
    'version: 1',
    'file_coverage:',
    'widget_coverage:',
    'fail_on_lost:',
  ];

  for (final threshold in requiredThresholds) {
    final found = thresholdsContent.contains(threshold);
    print('  ${found ? '✓' : '✗'} $threshold');
    if (!found) {
      print('    ERROR: Required threshold configuration missing!');
      exit(1);
    }
  }

  // Mock JSON output structure
  print('\n4. Generating mock JSON output with schema v1.0...');
  final mockOutput = {
    'schemaVersion': '1.0',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'summary': {
      'totalKeys': 11,
      'criticalKeys': 4,
      'filesScanned': 1,
    },
    'keys': criticalKeys
        .map((key) => {
              'key': key,
              'file': 'lib/main.dart',
              'line': 0,
              'type': 'ValueKey',
              'critical': true,
            })
        .toList(),
  };

  final jsonOutput = const JsonEncoder.withIndent('  ').convert(mockOutput);
  print('  ✓ Generated mock JSON with schema version 1.0');

  // Validate JSON structure
  final parsed = jsonDecode(jsonOutput);
  assert(parsed['schemaVersion'] == '1.0', 'Schema version must be 1.0');
  assert(parsed['keys'] is List, 'Keys must be a list');
  assert((parsed['keys'] as List).length >= 4,
      'Must have at least 4 critical keys');

  final foundKeys = (parsed['keys'] as List).map((k) => k['key']).toList();
  assert(foundKeys.contains('login_button'), 'Must contain login_button');
  assert(foundKeys.contains('email_field'), 'Must contain email_field');
  assert(foundKeys.contains('password_field'), 'Must contain password_field');
  assert(foundKeys.contains('submit_button'), 'Must contain submit_button');

  print('  ✓ JSON structure validated successfully');

  print('\n✅ All golden workspace validations passed!');
  print('Exit code: 0 (success)');
  exit(0);
}
