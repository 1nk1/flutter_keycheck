#!/usr/bin/env dart

import 'dart:io';

import 'package:yaml/yaml.dart';

/// Prepublish validator for flutter_keycheck
/// Checks if the package is ready for publishing to pub.dev
void main() async {
  print('🔍 Flutter KeyCheck Prepublish Validator\n');

  final checks = <String, bool>{};

  // Check pubspec.yaml
  checks['pubspec.yaml validation'] = await _validatePubspec();

  // Check CHANGELOG.md
  checks['CHANGELOG.md validation'] = await _validateChangelog();

  // Check example/
  checks['example/ validation'] = await _validateExample();

  // Check .pubignore
  checks['pubignore validation'] = await _validatePubignore();

  // Check tests
  checks['test validation'] = await _validateTests();

  // Check for warnings
  checks['no warnings'] = await _validateNoWarnings();

  // Print results
  print('\n📊 Validation Results:');
  print('=' * 40);

  bool allPassed = true;
  for (final entry in checks.entries) {
    final icon = entry.value ? '✅' : '❌';
    print('$icon ${entry.key}');
    if (!entry.value) allPassed = false;
  }

  print('\n${'=' * 40}');

  if (allPassed) {
    print('🎉 All checks passed! Ready for publishing.');
    exit(0);
  } else {
    print('❌ Some checks failed. Please fix issues before publishing.');
    exit(1);
  }
}

Future<bool> _validatePubspec() async {
  try {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) {
      print('❌ pubspec.yaml not found');
      return false;
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map;

    // Check required fields
    final required = [
      'name',
      'description',
      'version',
      'repository',
      'homepage'
    ];
    for (final field in required) {
      if (!yaml.containsKey(field) || yaml[field] == null) {
        print('❌ Missing required field: $field');
        return false;
      }
    }

    // Check description length (60-180 chars for pub.dev)
    final description = yaml['description'] as String;
    if (description.length < 60 || description.length > 180) {
      print(
          '❌ Description length should be 60-180 characters (current: ${description.length})');
      return false;
    }

    // Check version format
    final version = yaml['version'] as String;
    final versionRegex = RegExp(r'^\d+\.\d+\.\d+(\+\d+)?(-\w+)?$');
    if (!versionRegex.hasMatch(version)) {
      print('❌ Invalid version format: $version');
      return false;
    }

    print('✅ pubspec.yaml is valid (version: $version)');
    return true;
  } catch (e) {
    print('❌ Error validating pubspec.yaml: $e');
    return false;
  }
}

Future<bool> _validateChangelog() async {
  try {
    final file = File('CHANGELOG.md');
    if (!file.existsSync()) {
      print('❌ CHANGELOG.md not found');
      return false;
    }

    final content = await file.readAsString();

    // Check if current version is in changelog
    final pubspecFile = File('pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    final pubspecYaml = loadYaml(pubspecContent) as Map;
    final currentVersion = pubspecYaml['version'] as String;

    if (!content.contains('[$currentVersion]')) {
      print('❌ Current version $currentVersion not found in CHANGELOG.md');
      return false;
    }

    // Check for current year
    final currentYear = DateTime.now().year;
    if (!content.contains('$currentYear')) {
      print(
          '⚠️ Warning: CHANGELOG.md might not contain current year ($currentYear)');
    }

    print('✅ CHANGELOG.md contains current version');
    return true;
  } catch (e) {
    print('❌ Error validating CHANGELOG.md: $e');
    return false;
  }
}

Future<bool> _validateExample() async {
  try {
    final exampleFile = File('example/example.dart');
    if (!exampleFile.existsSync()) {
      print('❌ example/example.dart not found (required for pub.dev scoring)');
      return false;
    }

    final content = await exampleFile.readAsString();
    if (content.trim().isEmpty) {
      print('❌ example/example.dart is empty');
      return false;
    }

    print('✅ example/example.dart exists and has content');
    return true;
  } catch (e) {
    print('❌ Error validating example/: $e');
    return false;
  }
}

Future<bool> _validatePubignore() async {
  try {
    final file = File('.pubignore');
    if (!file.existsSync()) {
      print('⚠️ .pubignore not found (recommended)');
      return true; // Not critical
    }

    final content = await file.readAsString();
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final recommended = [
      'test/',
      '.github/',
      'example/',
      '*.md',
      'keys/',
    ];

    bool hasRecommended = false;
    for (final rec in recommended) {
      if (lines.any((line) => line.contains(rec))) {
        hasRecommended = true;
        break;
      }
    }

    if (!hasRecommended) {
      print('⚠️ .pubignore exists but might be missing recommended exclusions');
    }

    print('✅ .pubignore validation passed');
    return true;
  } catch (e) {
    print('❌ Error validating .pubignore: $e');
    return false;
  }
}

Future<bool> _validateTests() async {
  try {
    final testDir = Directory('test');
    if (!testDir.existsSync()) {
      print('❌ test/ directory not found');
      return false;
    }

    final testFiles = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .toList();

    if (testFiles.isEmpty) {
      print('❌ No test files found in test/');
      return false;
    }

    print('✅ Found ${testFiles.length} test files');
    return true;
  } catch (e) {
    print('❌ Error validating tests: $e');
    return false;
  }
}

Future<bool> _validateNoWarnings() async {
  try {
    // Run dart analyze
    final analyzeResult = await Process.run('dart', ['analyze']);
    if (analyzeResult.exitCode != 0) {
      print('❌ Dart analyze failed');
      print(analyzeResult.stdout);
      print(analyzeResult.stderr);
      return false;
    }

    // Run dart pub publish --dry-run and check for warnings
    final publishResult =
        await Process.run('dart', ['pub', 'publish', '--dry-run']);
    final output = publishResult.stdout.toString();

    // Check for warnings in output
    final warningsMatch =
        RegExp(r'Package has (\d+) warning').firstMatch(output);
    if (warningsMatch != null) {
      final warningCount = int.parse(warningsMatch.group(1)!);
      if (warningCount > 0) {
        print('❌ Found $warningCount warnings in publish validation');
        // Print the warnings section for debugging
        final lines = output.split('\n');
        bool inWarnings = false;
        for (final line in lines) {
          if (line.contains(
              'Package validation found the following potential issue')) {
            inWarnings = true;
          }
          if (inWarnings && line.trim().isNotEmpty) {
            print('  $line');
          }
          if (inWarnings && line.contains('Package has')) {
            break;
          }
        }
        return false;
      }
    }

    print('✅ No analyze or publish warnings found');
    return true;
  } catch (e) {
    print('❌ Error checking for warnings: $e');
    return false;
  }
}
