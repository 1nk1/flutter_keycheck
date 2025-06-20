import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:flutter_keycheck/flutter_keycheck.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) {
  runChecks(args);
}

/// Loads configuration from a custom config file
FlutterKeycheckConfig? loadCustomConfigFile(File configFile) {
  try {
    final content = configFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;

    if (yaml == null) {
      return null;
    }

    // Show success message
    final green = AnsiPen()..green(bold: true);
    print('${green('📄 Loaded config from ${configFile.path}')} ✅');

    return FlutterKeycheckConfig(
      keys: yaml['keys']?.toString(),
      path: yaml['path']?.toString(),
      strict: yaml['strict'] as bool?,
      verbose: yaml['verbose'] as bool?,
      failOnExtra: yaml['fail_on_extra'] as bool?,
    );
  } catch (e) {
    final red = AnsiPen()..red(bold: true);
    print('${red('⚠️  Error reading ${configFile.path}:')} $e');
    return null;
  }
}

/// Generates expected_keys.yaml from current project
void _generateKeysFile(String sourcePath) {
  print(ConsoleColors.info('🔍 Scanning project for ValueKeys...'));

  // Directly scan for keys without loading expected keys file
  final foundKeys = KeyChecker.findKeysInProject(sourcePath);

  if (foundKeys.isEmpty) {
    print(ConsoleColors.warning('⚠️  No ValueKeys found in project.'));
    return;
  }

  // Generate YAML content
  final buffer = StringBuffer();
  buffer.writeln('# Generated expected keys for flutter_keycheck');
  buffer.writeln(
      '# Run: flutter_keycheck --generate-keys > keys/expected_keys.yaml');
  buffer.writeln('');
  buffer.writeln('keys:');

  final sortedKeys = foundKeys.keys.toList()..sort();
  for (final key in sortedKeys) {
    buffer.writeln('  - $key');
  }

  print(buffer.toString());

  final green = AnsiPen()..green(bold: true);
  print(green('✅ Generated ${sortedKeys.length} keys'));
  print(ConsoleColors.info(
      '💡 Save to file: flutter_keycheck --generate-keys > keys/expected_keys.yaml'));
}

void runChecks(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'keys',
      abbr: 'k',
      help: 'Path to keys file (.yaml)',
      mandatory: false,
    )
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to config file (default: .flutter_keycheck.yaml)',
    )
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Project source root',
      defaultsTo: null,
    )
    ..addFlag(
      'strict',
      abbr: 's',
      help: 'Fail if integration_test/appium_test.dart is missing',
      defaultsTo: null,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed output',
      defaultsTo: null,
    )
    ..addFlag(
      'fail-on-extra',
      help: 'Fail if extra keys (not in expected list) are found',
      defaultsTo: false,
    )
    ..addFlag(
      'generate-keys',
      abbr: 'g',
      help: 'Generate expected_keys.yaml from current project',
      defaultsTo: false,
    )
    ..addOption(
      'report',
      help: 'Generate report in specified format (json, markdown)',
      allowed: ['json', 'markdown'],
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      print('Flutter Key Integration Validator\n');
      print('Usage: flutter_keycheck --keys <path> [options]\n');
      print('       flutter_keycheck --config <config-file> [options]\n');
      print('       flutter_keycheck --generate-keys [options]\n');
      print('Options:');
      print(parser.usage);
      print('\nConfiguration file:');
      print(
          '  You can create a .flutter_keycheck.yaml file in your project root:');
      print('  keys: keys/expected_keys.yaml');
      print('  path: .');
      print('  strict: true');
      print('  verbose: false');
      print('  fail_on_extra: false');
      print('\n  CLI arguments take priority over config file settings.');
      print('\nExamples:');
      print('  flutter_keycheck --keys keys/expected_keys.yaml');
      print('  flutter_keycheck --config my_config.yaml');
      print('  flutter_keycheck --keys keys/test.yaml --strict --verbose');
      print('  flutter_keycheck --generate-keys > keys/generated_keys.yaml');
      print('  flutter_keycheck --fail-on-extra --report json');
      print('\nCI Integration:');
      print(
          '  flutter_keycheck                    # Uses .flutter_keycheck.yaml');
      print(
          '  flutter_keycheck --strict           # Fails on missing integration tests');
      print('  flutter_keycheck --fail-on-extra    # Fails on unexpected keys');
      exit(0);
    }

    // Handle key generation
    if (results['generate-keys'] as bool) {
      final sourcePath = results['path'] as String? ?? '.';
      _generateKeysFile(sourcePath);
      return;
    }

    // Load configuration from file
    final configPath = results['config'] as String?;
    final FlutterKeycheckConfig? fileConfig;

    if (configPath != null) {
      // Custom config file specified
      final configFile = File(configPath);
      if (!configFile.existsSync()) {
        print(
            ConsoleColors.error('❌ Config file "$configPath" does not exist.'));
        exit(1);
      }
      fileConfig = loadCustomConfigFile(configFile);
    } else {
      // Default config file
      fileConfig = FlutterKeycheckConfig.loadFromFile();
    }

    // Get CLI arguments (null if not provided)
    final cliKeys = results['keys'] as String?;
    final cliPath = results['path'] as String?;
    final cliStrict =
        results.wasParsed('strict') ? results['strict'] as bool : null;
    final cliVerbose =
        results.wasParsed('verbose') ? results['verbose'] as bool : null;
    final cliFailOnExtra = results['fail-on-extra'] as bool;

    // Merge CLI args with config file (CLI takes priority)
    final finalConfig = (fileConfig ?? const FlutterKeycheckConfig()).mergeWith(
      keys: cliKeys,
      path: cliPath,
      strict: cliStrict,
      verbose: cliVerbose,
      failOnExtra: cliFailOnExtra,
    );

    // Get resolved configuration with defaults
    final Map<String, dynamic> config;
    try {
      config = finalConfig.getResolvedConfig();
    } catch (e) {
      print(ConsoleColors.error('Error: ${e.toString()}'));
      if (fileConfig == null && cliKeys == null) {
        print(ConsoleColors.error(
            'Either provide --keys argument or create .flutter_keycheck.yaml config file'));
      }
      exit(1);
    }

    final keysPath = config['keys'] as String;
    final sourcePath = config['path'] as String;
    final strict = config['strict'] as bool;
    final verbose = config['verbose'] as bool;
    final failOnExtra = config['fail_on_extra'] as bool;

    // Validate keys file exists
    if (!File(keysPath).existsSync()) {
      print(ConsoleColors.error('❌ Keys file "$keysPath" does not exist.'));
      print(ConsoleColors.error(
          '   Please check the path and make sure the file exists.'));
      exit(1);
    }

    // Validate source path exists
    if (!Directory(sourcePath).existsSync()) {
      print(ConsoleColors.error('❌ Source path "$sourcePath" does not exist.'));
      print(ConsoleColors.error(
          '   Please check the path and make sure the directory exists.'));
      exit(1);
    }

    if (verbose) {
      print(ConsoleColors.info('📋 Configuration:'));
      print(ConsoleColors.info('   Keys file: $keysPath'));
      print(ConsoleColors.info('   Source path: $sourcePath'));
      print(ConsoleColors.info('   Strict mode: $strict'));
      print(ConsoleColors.info('   Verbose: $verbose'));
      if (configPath != null) {
        print(ConsoleColors.info('   Config file: $configPath'));
      } else if (fileConfig != null) {
        print(ConsoleColors.info('   Config file: .flutter_keycheck.yaml'));
      } else {
        print(ConsoleColors.info(
            '   Config file: none (using CLI args/defaults)'));
      }
      print('');
    }

    print(
        '\n🎯 [flutter_keycheck] 🔍 Scanning project for ValueKeys & integration setup...\n');

    final result = KeyChecker.validateKeys(
      keysPath: keysPath,
      sourcePath: sourcePath,
      strict: strict,
    );

    // Print missing keys
    print(ConsoleColors.section('🧩  Keys Check'));
    if (result.missingKeys.isNotEmpty) {
      print('❌  Missing Keys:');
      for (final key in result.missingKeys) {
        print(ConsoleColors.error('   ⛔️  $key'));
      }
      print('');
    }

    // Print extra keys
    if (result.extraKeys.isNotEmpty) {
      print('🧼  Extra Keys (not in list):');
      for (final key in result.extraKeys) {
        print(ConsoleColors.warning('   💡  $key'));
      }
      print('');
    }

    // Print matched keys
    print('🔎  Found Keys:');
    if (result.matchedKeys.isEmpty) {
      print(ConsoleColors.error('   ❌  No ValueKey/Key found in project.'));
    } else {
      for (final entry in result.matchedKeys.entries) {
        print(ConsoleColors.success('   ✔️  ${entry.key}'));
        for (final file in entry.value) {
          print(ConsoleColors.info('       └── $file'));
        }
      }
    }

    // Print dependency status
    print('\n${ConsoleColors.section('📦  Dependencies')}');
    if (result.dependencyStatus.hasIntegrationTest) {
      print(ConsoleColors.success(
          '✔️  integration_test found in pubspec.yaml ✅'));
    } else {
      print(
          ConsoleColors.error('❌  integration_test not found in pubspec.yaml'));
    }

    if (result.dependencyStatus.hasAppiumServer) {
      print(ConsoleColors.success(
          '✔️  appium_flutter_server found in pubspec.yaml ✅'));
    } else {
      print(ConsoleColors.error(
          '❌  appium_flutter_server not found in pubspec.yaml'));
    }

    // Print integration test status
    print('\n${ConsoleColors.section('🧪  Integration Test Setup')}');
    if (result.hasIntegrationTests) {
      print(ConsoleColors.success(
          '✔️  Found integration_test/appium_test.dart ✅'));
      if (verbose) {
        print(ConsoleColors.success('✔️  Required imports:'));
        print(ConsoleColors.success('     • appium_flutter_server.dart ✅'));
        print(ConsoleColors.success('     • flutter_test.dart ✅'));
      }
    } else {
      print(
          ConsoleColors.error('❌  Missing or invalid integration test setup:'));
      print(
          ConsoleColors.error('   • Create integration_test/appium_test.dart'));
      print(
          ConsoleColors.error('   • Add Appium Flutter Driver initialization'));
    }

    // Print final status
    print('\n${ConsoleColors.section('🚨  Final Verdict')}');

    // Check if we should fail in strict mode
    bool shouldFail = false;
    if (result.missingKeys.isNotEmpty || !result.hasDependencies) {
      shouldFail = true;
    }
    if (strict && !result.hasIntegrationTests) {
      shouldFail = true;
    }
    if (failOnExtra && result.extraKeys.isNotEmpty) {
      shouldFail = true;
    }

    if (!shouldFail) {
      print(
          ConsoleColors.success('🎉  Project is ready for automation build!'));
    } else {
      print(
          ConsoleColors.error('❌  Project is NOT ready for automation build.'));
      print(ConsoleColors.error('    Please fix the issues above.'));
      if (strict && !result.hasIntegrationTests) {
        print(ConsoleColors.error(
            '    (Strict mode: integration_test/appium_test.dart is required)'));
      }
      exit(1);
    }
  } on FormatException catch (e) {
    print(ConsoleColors.error('Error: ${e.message}\n'));
    print('Usage: flutter_keycheck --keys <path> [options]\n');
    print('Options:');
    print(parser.usage);
    exit(1);
  } catch (e) {
    print(ConsoleColors.error('Error: $e'));
    exit(1);
  }
}
