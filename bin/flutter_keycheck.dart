import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_keycheck/flutter_keycheck.dart';
import 'package:flutter_keycheck/src/checker.dart';

void main(List<String> args) {
  runChecks(args);
}

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
    if (result.hasDependencies) {
      print(ConsoleColors.success(
          '✔️  integration_test found in pubspec.yaml ✅'));
      print(ConsoleColors.success(
          '✔️  appium_flutter_server found in pubspec.yaml ✅'));
    } else {
      print(ConsoleColors.error('❌  Missing required dependencies:'));
      print(ConsoleColors.error('   • integration_test'));
      print(ConsoleColors.error('   • appium_flutter_server'));
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
