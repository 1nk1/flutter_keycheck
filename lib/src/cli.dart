import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_keycheck/src/checker.dart';

/// Run the key checker with provided arguments
void runChecks(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'keys',
      abbr: 'k',
      help: 'Path to keys file (.yaml)',
      mandatory: true,
    )
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Project source root',
      defaultsTo: '.',
    )
    ..addFlag(
      'strict',
      abbr: 's',
      help: 'Fail if integration_test/appium_test.dart is missing',
      defaultsTo: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed output',
      defaultsTo: false,
    )
    ..addFlag(
      'key-constants-report',
      help: 'Generate KeyConstants usage analysis report',
      defaultsTo: false,
    )
    ..addFlag(
      'validate-key-constants',
      help: 'Validate KeyConstants class structure and usage',
      defaultsTo: false,
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
      print('Options:');
      print(parser.usage);
      exit(0);
    }

    final keysPath = results['keys'] as String;
    final sourcePath = results['path'] as String;
    final strict = results['strict'] as bool;
    final verbose = results['verbose'] as bool;
    final keyConstantsReport = results['key-constants-report'] as bool;
    final validateKeyConstants = results['validate-key-constants'] as bool;

    print(
        '\n🎯 [flutter_keycheck] 🔍 Scanning project for ValueKeys & integration setup...\n');

    // Handle KeyConstants specific operations
    if (keyConstantsReport) {
      print(ConsoleColors.section('🔑  KeyConstants Analysis Report'));
      final report = KeyChecker.generateKeyReport(sourcePath);

      print('📊 Total keys found: ${report['totalKeysFound']}');

      final traditionalKeys = report['traditionalKeys'] as List<String>;
      final constantKeys = report['constantKeys'] as List<String>;
      final dynamicKeys = report['dynamicKeys'] as List<String>;

      if (traditionalKeys.isNotEmpty) {
        print(
            '\n📝 Traditional string-based keys (${traditionalKeys.length}):');
        for (final key in traditionalKeys) {
          print(ConsoleColors.warning('   • $key'));
        }
      }

      if (constantKeys.isNotEmpty) {
        print('\n🏗️  KeyConstants static keys (${constantKeys.length}):');
        for (final key in constantKeys) {
          print(ConsoleColors.success('   • $key'));
        }
      }

      if (dynamicKeys.isNotEmpty) {
        print('\n⚡ KeyConstants dynamic methods (${dynamicKeys.length}):');
        for (final key in dynamicKeys) {
          print(ConsoleColors.info('   • $key'));
        }
      }

      final recommendations = report['recommendations'] as List<String>;
      if (recommendations.isNotEmpty) {
        print('\n💡 Recommendations:');
        for (final recommendation in recommendations) {
          print(ConsoleColors.blue('   • $recommendation'));
        }
      }

      print('');
    }

    if (validateKeyConstants) {
      print(ConsoleColors.section('🔍  KeyConstants Validation'));
      final validation = KeyChecker.validateKeyConstants(sourcePath);

      if (validation['hasKeyConstants'] as bool) {
        print(ConsoleColors.success('✅ KeyConstants class found'));
        print(ConsoleColors.info('   📁 Location: ${validation['filePath']}'));

        final constants = validation['constantsFound'] as List<String>;
        final methods = validation['methodsFound'] as List<String>;

        if (constants.isNotEmpty) {
          print('\n📋 Static constants (${constants.length}):');
          for (final constant in constants) {
            print(ConsoleColors.success('   • $constant'));
          }
        }

        if (methods.isNotEmpty) {
          print('\n⚙️  Dynamic methods (${methods.length}):');
          for (final method in methods) {
            print(ConsoleColors.info('   • $method'));
          }
        }

        if (constants.isEmpty && methods.isEmpty) {
          print(ConsoleColors.warning('⚠️ KeyConstants class is empty'));
        }
      } else {
        print(ConsoleColors.error('❌ KeyConstants class not found'));
        print(ConsoleColors.warning(
            '💡 Consider creating a KeyConstants class for better key management'));
      }

      print('');
    }

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
    print(
        'DEBUG: hasIntegrationTest=${result.dependencyStatus.hasIntegrationTest}, hasAppiumServer=${result.dependencyStatus.hasAppiumServer}');
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
