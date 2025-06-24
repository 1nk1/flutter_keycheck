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

  // Show KeyConstants resolver information if available and verbose
  if (config.isVerbose() && result.keyConstantsInfo != null) {
    final keyConstantsInfo = result.keyConstantsInfo!;
    final hasKeyConstants = keyConstantsInfo['hasKeyConstants'] as bool;

    if (hasKeyConstants) {
      print(blue('📋 KeyConstants resolver: ACTIVE'));
      print(
          cyan('   📁 Location: ${keyConstantsInfo['keyConstantsFilePath']}'));

      final constantsCount = keyConstantsInfo['constantsCount'] as int;
      final dynamicMethodsCount =
          keyConstantsInfo['dynamicMethodsCount'] as int;

      if (constantsCount > 0) {
        print(cyan('   📊 Static constants: $constantsCount'));
      }
      if (dynamicMethodsCount > 0) {
        print(cyan('   ⚙️  Dynamic methods: $dynamicMethodsCount'));
      }
      print('');
    } else {
      print(yellow(
          '📋 KeyConstants resolver: INACTIVE (no KeyConstants class found)'));
      print('');
    }
  }

  // Show tracked keys information if applicable
  if (result.trackedKeys != null && result.trackedKeys!.isNotEmpty) {
    print(blue('📌 Tracking ${result.trackedKeys!.length} specific keys'));
    print('');

    final trackedSet = result.trackedKeys!.toSet();
    final foundTrackedKeys = result.matchedKeys.keys
        .where((key) => trackedSet.contains(key))
        .toList()
      ..sort();
    final missingTrackedKeys =
        trackedSet.difference(result.matchedKeys.keys.toSet()).toList()..sort();

    if (foundTrackedKeys.isNotEmpty) {
      print(green('✅ Matched tracked keys (${foundTrackedKeys.length}):'));
      for (final key in foundTrackedKeys) {
        print(green('  ✅ $key'));
        if (config.isVerbose()) {
          final locations = result.matchedKeys[key]!;
          for (final location in locations) {
            print(cyan('     📍 $location'));
          }
        }
      }
      print('');
    }

    if (missingTrackedKeys.isNotEmpty) {
      print(red('❌ Missing tracked keys (${missingTrackedKeys.length}):'));
      for (final key in missingTrackedKeys) {
        print(red('  ❌ $key'));
      }
      print('');
    }
  } else {
    // Standard key validation output
    if (result.missingKeys.isNotEmpty) {
      print(red('❌ Missing keys (${result.missingKeys.length}):'));
      for (final key in result.missingKeys) {
        print(red('  ❌ $key'));
      }
      print('');
    }

    if (result.extraKeys.isNotEmpty) {
      print(yellow('⚠️  Extra keys (${result.extraKeys.length}):'));
      for (final key in result.extraKeys) {
        print(yellow('  ⚠️  $key'));
      }
      print('');
    }

    if (result.matchedKeys.isNotEmpty) {
      print(green('✅ Found keys (${result.matchedKeys.length}):'));
      for (final entry in result.matchedKeys.entries) {
        // Show resolution information in verbose mode
        if (config.isVerbose() && result.keyConstantsInfo != null) {
          final keyConstantsInfo = result.keyConstantsInfo!;
          final constants =
              keyConstantsInfo['constants'] as Map<String, String>;
          final dynamicMethods =
              keyConstantsInfo['dynamicMethods'] as Map<String, String>;

          // Check if this key was resolved from KeyConstants
          String? resolvedFrom;
          for (final constantEntry in constants.entries) {
            if (constantEntry.value == entry.key) {
              resolvedFrom = 'KeyConstants.${constantEntry.key}';
              break;
            }
          }
          if (resolvedFrom == null) {
            for (final methodEntry in dynamicMethods.entries) {
              if (methodEntry.value == entry.key) {
                resolvedFrom = 'KeyConstants.${methodEntry.key}()';
                break;
              }
            }
          }

          if (resolvedFrom != null) {
            print(green('  ✅ ${entry.key} (resolved from $resolvedFrom)'));
          } else {
            print(green('  ✅ ${entry.key} (string literal)'));
          }
        } else {
          print(green('  ✅ ${entry.key}'));
        }

        if (config.isVerbose()) {
          for (final location in entry.value) {
            print(cyan('     📍 $location'));
          }
        }
      }
      print('');
    }
  }

  // Show resolution statistics in verbose mode
  if (config.isVerbose() && result.keyConstantsInfo != null) {
    final keyConstantsInfo = result.keyConstantsInfo!;
    final hasKeyConstants = keyConstantsInfo['hasKeyConstants'] as bool;

    if (hasKeyConstants) {
      final constants = keyConstantsInfo['constants'] as Map<String, String>;
      final dynamicMethods =
          keyConstantsInfo['dynamicMethods'] as Map<String, String>;

      var resolvedCount = 0;
      var stringLiteralCount = 0;

      for (final key in result.matchedKeys.keys) {
        bool isResolved = false;
        for (final constantValue in constants.values) {
          if (constantValue == key) {
            isResolved = true;
            break;
          }
        }
        if (!isResolved) {
          for (final methodValue in dynamicMethods.values) {
            if (methodValue == key) {
              isResolved = true;
              break;
            }
          }
        }

        if (isResolved) {
          resolvedCount++;
        } else {
          stringLiteralCount++;
        }
      }

      print(blue('📊 Resolution Stats:'));
      print(cyan('   • String literals: $stringLiteralCount keys'));
      print(cyan('   • KeyConstants resolved: $resolvedCount keys'));
      print('');
    }
  }

  // Dependency status
  print(blue('📦 Dependencies'));
  if (result.dependencyStatus.hasIntegrationTest) {
    print(green('  ✅ integration_test'));
  } else {
    print(red('  ❌ integration_test missing'));
  }

  if (result.dependencyStatus.hasAppiumServer) {
    print(green('  ✅ appium_flutter_server'));
  } else {
    print(red('  ❌ appium_flutter_server missing'));
  }
  print('');

  // Integration test status
  print(blue('🧪 Integration Tests'));
  if (result.hasIntegrationTests) {
    print(green('  ✅ Setup complete'));
  } else {
    print(red('  ❌ Setup incomplete'));
  }
  print('');

  // Final verdict
  final hasFailures = result.missingKeys.isNotEmpty ||
      (config.shouldFailOnExtra() && result.extraKeys.isNotEmpty) ||
      (config.isStrict() &&
          (!result.hasDependencies || !result.hasIntegrationTests));

  if (hasFailures) {
    print(red('💥 Some checks failed'));
  } else {
    print(green('🎉 All checks passed!'));
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
    'key_constants_info': result.keyConstantsInfo,
  };

  // Add resolution statistics if KeyConstants are available
  if (result.keyConstantsInfo != null) {
    final keyConstantsInfo = result.keyConstantsInfo!;
    final hasKeyConstants = keyConstantsInfo['hasKeyConstants'] as bool;

    if (hasKeyConstants) {
      final constants = keyConstantsInfo['constants'] as Map<String, String>;
      final dynamicMethods =
          keyConstantsInfo['dynamicMethods'] as Map<String, String>;

      var resolvedCount = 0;
      var stringLiteralCount = 0;
      final resolvedKeys = <String, String>{};

      for (final key in result.matchedKeys.keys) {
        bool isResolved = false;
        String? resolvedFrom;

        // Check constants
        for (final constantEntry in constants.entries) {
          if (constantEntry.value == key) {
            isResolved = true;
            resolvedFrom = 'KeyConstants.${constantEntry.key}';
            resolvedKeys[key] = resolvedFrom;
            break;
          }
        }

        // Check dynamic methods if not found in constants
        if (!isResolved) {
          for (final methodEntry in dynamicMethods.entries) {
            if (methodEntry.value == key) {
              isResolved = true;
              resolvedFrom = 'KeyConstants.${methodEntry.key}()';
              resolvedKeys[key] = resolvedFrom;
              break;
            }
          }
        }

        if (isResolved) {
          resolvedCount++;
        } else {
          stringLiteralCount++;
        }
      }

      jsonOutput['resolution_stats'] = {
        'string_literal_keys': stringLiteralCount,
        'key_constants_resolved': resolvedCount,
        'total_keys': result.matchedKeys.length,
        'resolved_keys': resolvedKeys,
      };
    }
  }

  print(const JsonEncoder.withIndent('  ').convert(jsonOutput));
}

void _showHelp(ArgParser parser) {
  print('''
Flutter KeyCheck v2.3.3 - Validate automation keys in Flutter projects

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
  final keyConstantsResolver =
      report['keyConstantsResolver'] as Map<String, dynamic>;

  print('📊 Total keys found: ${report['totalKeysFound']}');
  print('');

  // Show KeyConstants resolver information
  final hasKeyConstants = keyConstantsResolver['hasKeyConstants'] as bool;
  if (hasKeyConstants) {
    print(green('✅ KeyConstants class found'));
    print(cyan(
        '   📁 Location: ${keyConstantsResolver['keyConstantsFilePath']}'));
    print(cyan(
        '   📊 Static constants: ${keyConstantsResolver['constantsCount']}'));
    print(cyan(
        '   ⚙️  Dynamic methods: ${keyConstantsResolver['dynamicMethodsCount']}'));
    print('');
  } else {
    print(yellow('⚠️  KeyConstants class not found'));
    print('');
  }

  final traditionalKeys = report['traditionalKeys'] as List<String>;
  final constantKeys = report['constantKeys'] as List<String>;
  final dynamicKeys = report['dynamicKeys'] as List<String>;
  final resolvedKeys = report['resolvedKeys'] as Map<String, String>;

  if (traditionalKeys.isNotEmpty) {
    print('📝 Traditional string-based keys (${traditionalKeys.length}):');
    for (final key in traditionalKeys) {
      print(yellow('   • $key'));
    }
    print('');
  }

  if (constantKeys.isNotEmpty) {
    print('🏗️  KeyConstants static keys (${constantKeys.length}):');
    for (final key in constantKeys) {
      final resolvedFrom = resolvedKeys[key];
      if (resolvedFrom != null) {
        print(green('   • $key (resolved from $resolvedFrom)'));
      } else {
        print(green('   • $key'));
      }
    }
    print('');
  }

  if (dynamicKeys.isNotEmpty) {
    print('⚡ KeyConstants dynamic methods (${dynamicKeys.length}):');
    for (final key in dynamicKeys) {
      final resolvedFrom = resolvedKeys[key];
      if (resolvedFrom != null) {
        print(cyan('   • $key (resolved from $resolvedFrom)'));
      } else {
        print(cyan('   • $key'));
      }
    }
    print('');
  }

  // Show available constants and methods
  if (hasKeyConstants) {
    final constants = keyConstantsResolver['constants'] as Map<String, String>;
    final dynamicMethods =
        keyConstantsResolver['dynamicMethods'] as Map<String, String>;

    if (constants.isNotEmpty) {
      print('📋 Available KeyConstants (${constants.length}):');
      for (final entry in constants.entries) {
        final isUsed =
            resolvedKeys.values.contains('KeyConstants.${entry.key}');
        if (isUsed) {
          print(green('   ✅ ${entry.key} = \'${entry.value}\' (used)'));
        } else {
          print(yellow('   ⚠️  ${entry.key} = \'${entry.value}\' (unused)'));
        }
      }
      print('');
    }

    if (dynamicMethods.isNotEmpty) {
      print('⚙️  Available Dynamic Methods (${dynamicMethods.length}):');
      for (final entry in dynamicMethods.entries) {
        final isUsed =
            resolvedKeys.values.contains('KeyConstants.${entry.key}()');
        if (isUsed) {
          print(green('   ✅ ${entry.key}() => \'${entry.value}_...\' (used)'));
        } else {
          print(yellow(
              '   ⚠️  ${entry.key}() => \'${entry.value}_...\' (unused)'));
        }
      }
      print('');
    }
  }

  final recommendations = report['recommendations'] as List<String>;
  if (recommendations.isNotEmpty) {
    print('💡 Recommendations:');
    for (final recommendation in recommendations) {
      print(blue('   • $recommendation'));
    }
    print('');
  }
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
  final keyConstantsResolver =
      report['keyConstantsResolver'] as Map<String, dynamic>;

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
    'resolved_keys': report['resolvedKeys'],
    'key_constants_validation': report['keyConstantsValidation'],
    'key_constants_resolver': {
      'has_key_constants': keyConstantsResolver['hasKeyConstants'],
      'file_path': keyConstantsResolver['keyConstantsFilePath'],
      'constants_count': keyConstantsResolver['constantsCount'],
      'dynamic_methods_count': keyConstantsResolver['dynamicMethodsCount'],
      'available_constants': keyConstantsResolver['constants'],
      'available_dynamic_methods': keyConstantsResolver['dynamicMethods'],
    },
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
