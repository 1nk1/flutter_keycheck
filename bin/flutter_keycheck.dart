#!/usr/bin/env dart

import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:flutter_keycheck/src/checker.dart';
import 'package:flutter_keycheck/src/config.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('keys', abbr: 'k', help: 'Path to expected keys YAML file')
    ..addOption('path',
        abbr: 'p', help: 'Path to Flutter project to scan', defaultsTo: '.')
    ..addFlag('strict',
        abbr: 's', help: 'Fail if integration_test/appium_test.dart is missing')
    ..addFlag('verbose', abbr: 'v', help: 'Show verbose output')
    ..addFlag('fail-on-extra',
        help: 'Fail if extra keys (not in expected list) are found')
    ..addFlag('generate-keys',
        help: 'Generate expected_keys.yaml from project and exit')
    ..addOption('include-only',
        help: 'Comma-separated patterns to include only matching keys')
    ..addOption('exclude',
        help: 'Comma-separated patterns to exclude matching keys')
    ..addOption('config',
        help: 'Path to configuration file',
        defaultsTo: '.flutter_keycheck.yaml')
    ..addOption('report',
        help: 'Output format: human (default) or json', defaultsTo: 'human')
    ..addFlag('help',
        abbr: 'h', help: 'Show this help message', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _showHelp(parser);
      exit(0);
    }

    // Load configuration from file first
    final configPath = results['config'] as String;
    final config = FlutterKeycheckConfig.loadFromFile(configPath) ??
        FlutterKeycheckConfig.defaults();

    // Parse comma-separated include-only patterns
    List<String>? includeOnly;
    if (results['include-only'] != null) {
      includeOnly = (results['include-only'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Parse comma-separated exclude patterns
    List<String>? exclude;
    if (results['exclude'] != null) {
      exclude = (results['exclude'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Merge CLI arguments with config (CLI takes priority)
    final finalConfig = config.mergeWith(
      keys: results['keys'] as String?,
      projectPath: results['path'] as String?,
      strict: results['strict'] as bool?,
      verbose: results['verbose'] as bool?,
      failOnExtra: results['fail-on-extra'] as bool?,
      includeOnly: includeOnly,
      exclude: exclude,
      report: results['report'] as String?,
    );

    // Show warning if using --fail-on-extra without keys file
    if (finalConfig.shouldFailOnExtra() && finalConfig.keys == null) {
      final yellow = AnsiPen()..yellow();
      print(
          '${yellow('⚠️  Warning:')} --fail-on-extra requires a keys file to be specified');
      exit(1);
    }

    // Generate keys mode
    if (results['generate-keys'] as bool) {
      final yaml = KeyChecker.generateKeysYaml(
        sourcePath: finalConfig.getProjectPath(),
        includeOnly: finalConfig.getIncludeOnly(),
        exclude: finalConfig.getExclude(),
        trackedKeys: finalConfig.getTrackedKeys(),
      );
      print(yaml);
      exit(0);
    }

    // Regular validation mode
    if (finalConfig.keys == null) {
      final red = AnsiPen()..red(bold: true);
      print('${red('❌ Error:')} Keys file is required for validation');
      print(
          'Use --keys to specify a keys file or --generate-keys to create one');
      exit(1);
    }

    // Show active configuration in verbose mode
    if (finalConfig.isVerbose()) {
      _showConfiguration(finalConfig);
    }

    // Validate keys
    final result = KeyChecker.validateKeys(
      keysPath: finalConfig.getKeysPath(),
      sourcePath: finalConfig.getProjectPath(),
      strict: finalConfig.isStrict(),
      includeOnly: finalConfig.getIncludeOnly(),
      exclude: finalConfig.getExclude(),
      trackedKeys: finalConfig.getTrackedKeys(),
    );

    // Output results
    if (finalConfig.getReportFormat() == 'json') {
      _outputJsonReport(result);
    } else {
      _outputHumanReport(result, finalConfig);
    }

    // Exit with appropriate code
    final hasFailures = result.missingKeys.isNotEmpty ||
        (finalConfig.shouldFailOnExtra() && result.extraKeys.isNotEmpty) ||
        (finalConfig.isStrict() &&
            (!result.hasDependencies || !result.hasIntegrationTests));

    exit(hasFailures ? 1 : 0);
  } catch (e) {
    final red = AnsiPen()..red(bold: true);
    print('${red('❌ Error:')} $e');
    exit(1);
  }
}

void _showConfiguration(FlutterKeycheckConfig config) {
  final blue = AnsiPen()..blue(bold: true);
  final cyan = AnsiPen()..cyan();

  print(blue('📋 Configuration'));
  print('${cyan('Keys file:')} ${config.getKeysPath()}');
  print('${cyan('Project path:')} ${config.getProjectPath()}');
  print('${cyan('Strict mode:')} ${config.isStrict()}');
  print('${cyan('Fail on extra:')} ${config.shouldFailOnExtra()}');

  if (config.getIncludeOnly().isNotEmpty) {
    print('${cyan('Include only:')} ${config.getIncludeOnly().join(', ')}');
  }
  if (config.getExclude().isNotEmpty) {
    print('${cyan('Exclude:')} ${config.getExclude().join(', ')}');
  }
  if (config.hasTrackedKeys()) {
    print('${cyan('Tracked keys:')} ${config.getTrackedKeys()!.join(', ')}');
  }
  print('');
}

void _outputHumanReport(
    KeyValidationResult result, FlutterKeycheckConfig config) {
  final green = AnsiPen()..green(bold: true);
  final red = AnsiPen()..red(bold: true);
  final yellow = AnsiPen()..yellow(bold: true);
  final cyan = AnsiPen()..cyan();
  final blue = AnsiPen()..blue(bold: true);

  print(blue('🔍 Flutter KeyCheck Results'));
  print('');

  // Show tracked keys information if enabled
  if (config.hasTrackedKeys()) {
    print(cyan('📌 Tracking ${config.getTrackedKeys()!.length} specific keys'));
    print('');
  }

  // Missing keys
  if (result.missingKeys.isNotEmpty) {
    print(red('❌ Missing tracked keys (${result.missingKeys.length}):'));
    for (final key in result.missingKeys.toList()..sort()) {
      print('  - $key');
    }
    print('');
  }

  // Found keys
  if (result.matchedKeys.isNotEmpty) {
    if (config.hasTrackedKeys()) {
      print(green('✅ Matched tracked keys (${result.matchedKeys.length}):'));
    } else {
      print(green('✅ Found keys (${result.matchedKeys.length}):'));
    }

    for (final entry in result.matchedKeys.entries) {
      final key = entry.key;
      final locations = entry.value;
      print('  - $key');
      if (config.isVerbose()) {
        for (final location in locations) {
          print('    📍 $location');
        }
      }
    }
    print('');
  }

  // Extra keys (only if fail-on-extra is enabled)
  if (config.shouldFailOnExtra() && result.extraKeys.isNotEmpty) {
    print(yellow('⚠️  Extra keys found (${result.extraKeys.length}):'));
    for (final key in result.extraKeys.toList()..sort()) {
      print('  - $key');
    }
    print('');
  }

  // Dependencies status
  if (!result.dependencyStatus.hasAllDependencies) {
    print(red('❌ Missing dependencies:'));
    if (!result.dependencyStatus.hasIntegrationTest) {
      print('  - integration_test (add to dev_dependencies)');
    }
    if (!result.dependencyStatus.hasAppiumServer) {
      print('  - appium_flutter_server (add to dev_dependencies)');
    }
    print('');
  } else {
    print(green('✅ Required dependencies found'));
  }

  // Integration tests status
  if (!result.hasIntegrationTests) {
    if (config.isStrict()) {
      print(red('❌ Integration test setup incomplete'));
    } else {
      print(yellow(
          '⚠️  Integration test setup incomplete (use --strict to enforce)'));
    }
  } else {
    print(green('✅ Integration test setup complete'));
  }

  // Summary
  print('');
  if (result.missingKeys.isEmpty &&
      (!config.shouldFailOnExtra() || result.extraKeys.isEmpty) &&
      (!config.isStrict() ||
          (result.hasDependencies && result.hasIntegrationTests))) {
    print(green('🎉 All checks passed!'));
  } else {
    print(red('💥 Some checks failed'));
  }
}

void _outputJsonReport(KeyValidationResult result) {
  // Implementation for JSON output would go here
  print('JSON output not yet implemented');
}

void _showHelp(ArgParser parser) {
  print('''
Flutter KeyCheck v2.1.0 - Validate automation keys in Flutter projects

USAGE:
  flutter_keycheck [options]

${parser.usage}

EXAMPLES:
  # Basic validation
  flutter_keycheck --keys keys/expected_keys.yaml

  # Generate keys with QA filtering
  flutter_keycheck --generate-keys --include-only="qa_,e2e_" > keys/qa_keys.yaml

  # Strict validation with extra key detection
  flutter_keycheck --keys keys.yaml --fail-on-extra --strict

  # Filter out noise keys
  flutter_keycheck --keys keys.yaml --exclude="user.id,token,status"

  # Use configuration file
  flutter_keycheck --config .flutter_keycheck.yaml

CONFIGURATION:
  Create .flutter_keycheck.yaml in your project root:

  keys: keys/expected_keys.yaml
  path: .
  strict: false
  verbose: false
  fail_on_extra: false
  include_only:
    - qa_
    - e2e_
    - _field
  exclude:
    - user.id
    - token
  tracked_keys:
    - login_submit_button
    - signup_email_field
    - card_dropdown

For more information, visit: https://pub.dev/packages/flutter_keycheck
''');
}
