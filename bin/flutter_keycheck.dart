#!/usr/bin/env dart

import 'dart:convert';
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
    ..addFlag('key-constants-report',
        help: 'Generate KeyConstants usage analysis report')
    ..addFlag('validate-key-constants',
        help: 'Validate KeyConstants class structure and usage')
    ..addFlag('json-key-constants',
        help: 'Output KeyConstants analysis in JSON format')
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

    // Handle KeyConstants specific operations
    if (results['key-constants-report'] as bool) {
      if (results['json-key-constants'] as bool) {
        _outputKeyConstantsJsonReport(finalConfig.getProjectPath());
      } else {
        _showKeyConstantsReport(finalConfig.getProjectPath());
      }
      exit(0);
    }

    if (results['validate-key-constants'] as bool) {
      if (results['json-key-constants'] as bool) {
        _outputKeyConstantsJsonValidation(finalConfig.getProjectPath());
      } else {
        _showKeyConstantsValidation(finalConfig.getProjectPath());
      }
      exit(0);
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
  final jsonOutput = {
    'timestamp': DateTime.now().toIso8601String(),
    'summary': {
      'total_expected_keys':
          result.missingKeys.length + result.matchedKeys.length,
      'found_keys': result.matchedKeys.length,
      'missing_keys': result.missingKeys.length,
      'extra_keys': result.extraKeys.length,
      'validation_passed': result.isValid,
    },
    'missing_keys': result.missingKeys.toList()..sort(),
    'extra_keys': result.extraKeys.toList()..sort(),
    'found_keys': result.matchedKeys.map((key, locations) => MapEntry(key, {
          'key': key,
          'locations': locations,
          'location_count': locations.length,
        })),
    'dependencies': {
      'integration_test': result.dependencyStatus.hasIntegrationTest,
      'appium_flutter_server': result.dependencyStatus.hasAppiumServer,
      'all_dependencies_present': result.dependencyStatus.hasAllDependencies,
    },
    'integration_test_setup': {
      'has_integration_tests': result.hasIntegrationTests,
      'setup_complete': result.hasIntegrationTests,
    },
    'tracked_keys': result.trackedKeys,
  };

  print(const JsonEncoder.withIndent('  ').convert(jsonOutput));
}

void _showHelp(ArgParser parser) {
  print('''
Flutter KeyCheck v2.2.0 - Validate automation keys in Flutter projects

USAGE:
  flutter_keycheck [options]

${parser.usage}

EXAMPLES:
  # Basic validation
  flutter_keycheck --keys keys/expected_keys.yaml

  # JSON output for CI/CD integration
  flutter_keycheck --keys keys.yaml --report json

  # KeyConstants analysis
  flutter_keycheck --key-constants-report --json-key-constants

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

void _showKeyConstantsReport(String projectPath) {
  final blue = AnsiPen()..blue(bold: true);
  final green = AnsiPen()..green();
  final yellow = AnsiPen()..yellow();
  final cyan = AnsiPen()..cyan();

  print(blue('🔑 KeyConstants Analysis Report'));
  print('');

  final report = KeyChecker.generateKeyReport(projectPath);

  print('📊 Total keys found: ${report['totalKeysFound']}');

  final traditionalKeys = report['traditionalKeys'] as List<String>;
  final constantKeys = report['constantKeys'] as List<String>;
  final dynamicKeys = report['dynamicKeys'] as List<String>;

  if (traditionalKeys.isNotEmpty) {
    print('\n📝 Traditional string-based keys (${traditionalKeys.length}):');
    for (final key in traditionalKeys) {
      print(yellow('   • $key'));
    }
  }

  if (constantKeys.isNotEmpty) {
    print('\n🏗️  KeyConstants static keys (${constantKeys.length}):');
    for (final key in constantKeys) {
      print(green('   • $key'));
    }
  }

  if (dynamicKeys.isNotEmpty) {
    print('\n⚡ KeyConstants dynamic methods (${dynamicKeys.length}):');
    for (final key in dynamicKeys) {
      print(cyan('   • $key'));
    }
  }

  final recommendations = report['recommendations'] as List<String>;
  if (recommendations.isNotEmpty) {
    print('\n💡 Recommendations:');
    for (final recommendation in recommendations) {
      print(blue('   • $recommendation'));
    }
  }

  print('');
}

void _showKeyConstantsValidation(String projectPath) {
  final blue = AnsiPen()..blue(bold: true);
  final green = AnsiPen()..green();
  final yellow = AnsiPen()..yellow();
  final red = AnsiPen()..red();
  final cyan = AnsiPen()..cyan();

  print(blue('🔍 KeyConstants Validation'));
  print('');

  final validation = KeyChecker.validateKeyConstants(projectPath);

  if (validation['hasKeyConstants'] as bool) {
    print(green('✅ KeyConstants class found'));
    print(cyan('   📁 Location: ${validation['filePath']}'));

    final constants = validation['constantsFound'] as List<String>;
    final methods = validation['methodsFound'] as List<String>;

    if (constants.isNotEmpty) {
      print('\n📋 Static constants (${constants.length}):');
      for (final constant in constants) {
        print(green('   • $constant'));
      }
    }

    if (methods.isNotEmpty) {
      print('\n⚙️  Dynamic methods (${methods.length}):');
      for (final method in methods) {
        print(cyan('   • $method'));
      }
    }

    if (constants.isEmpty && methods.isEmpty) {
      print(yellow('⚠️  KeyConstants class is empty'));
    }
  } else {
    print(red('❌ KeyConstants class not found'));
    print(yellow(
        '💡 Consider creating a KeyConstants class for better key management'));
  }

  print('');
}

void _outputKeyConstantsJsonReport(String projectPath) {
  final report = KeyChecker.generateKeyReport(projectPath);

  final jsonOutput = {
    'timestamp': DateTime.now().toIso8601String(),
    'analysis_type': 'key_constants_report',
    'summary': {
      'total_keys_found': report['totalKeysFound'],
      'traditional_keys_count': (report['traditionalKeys'] as List).length,
      'constant_keys_count': (report['constantKeys'] as List).length,
      'dynamic_keys_count': (report['dynamicKeys'] as List).length,
    },
    'traditional_keys': report['traditionalKeys'],
    'constant_keys': report['constantKeys'],
    'dynamic_keys': report['dynamicKeys'],
    'key_constants_validation': report['keyConstantsValidation'],
    'recommendations': report['recommendations'],
  };

  print(const JsonEncoder.withIndent('  ').convert(jsonOutput));
}

void _outputKeyConstantsJsonValidation(String projectPath) {
  final validation = KeyChecker.validateKeyConstants(projectPath);

  final jsonOutput = {
    'timestamp': DateTime.now().toIso8601String(),
    'analysis_type': 'key_constants_validation',
    'validation_result': {
      'has_key_constants': validation['hasKeyConstants'],
      'file_path': validation['filePath'],
      'constants_found': validation['constantsFound'],
      'methods_found': validation['methodsFound'],
      'constants_count': (validation['constantsFound'] as List).length,
      'methods_count': (validation['methodsFound'] as List).length,
      'is_empty': (validation['constantsFound'] as List).isEmpty &&
          (validation['methodsFound'] as List).isEmpty,
    },
    'details': {
      'constants': validation['constantsFound'],
      'methods': validation['methodsFound'],
    },
  };

  print(const JsonEncoder.withIndent('  ').convert(jsonOutput));
}
