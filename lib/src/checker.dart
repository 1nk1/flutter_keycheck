import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Result of key validation containing found and missing keys.
///
/// This class holds the results of validating Flutter automation keys in a project:
/// - [missingKeys]: Keys that are expected but not found in the code
/// - [extraKeys]: Keys found in code but not in the specification (when strict mode is enabled)
/// - [matchedKeys]: Keys found in code with their file locations
/// - [hasDependencies]: Whether required test dependencies are present
/// - [hasIntegrationTests]: Whether integration test setup is valid
class KeyValidationResult {
  /// Keys that are expected but not found in the code
  final Set<String> missingKeys;

  /// Keys found in code but not in the specification (strict mode)
  final Set<String> extraKeys;

  /// Keys found in code with their file locations
  final Map<String, List<String>> matchedKeys;

  /// Whether required test dependencies are present
  final bool hasDependencies;

  /// Whether integration test setup is valid
  final bool hasIntegrationTests;

  const KeyValidationResult({
    required this.missingKeys,
    required this.extraKeys,
    required this.matchedKeys,
    required this.hasDependencies,
    required this.hasIntegrationTests,
  });

  /// Whether the validation passed all checks
  bool get isValid =>
      missingKeys.isEmpty && hasDependencies && hasIntegrationTests;
}

/// ANSI color pens for console output
class ConsoleColors {
  /// Red color for errors
  static final error = AnsiPen()..red(bold: true);

  /// Green color for success messages
  static final success = AnsiPen()..green();

  /// Yellow color for warnings
  static final warning = AnsiPen()..yellow();

  /// Cyan color for info messages
  static final info = AnsiPen()..cyan();

  /// Blue color for section headers
  static final blue = AnsiPen()..blue(bold: true);

  /// Reset color pen
  static final reset = AnsiPen();

  /// Creates a formatted section header with divider
  static String section(String text) => blue('$text\n${_divider()}');

  /// Creates a horizontal divider line
  static String _divider() => '─' * 44;
}

/// Key checker functionality for validating Flutter automation keys
class KeyChecker {
  /// Find keys in Flutter source code using regex patterns.
  ///
  /// Searches for:
  /// - ValueKey declarations
  /// - Key declarations
  /// - find.byValueKey finders
  /// - find.bySemanticsLabel finders
  /// - find.byTooltip finders
  ///
  /// Returns a map of key names to lists of file paths where they are used.
  static Map<String, List<String>> findKeysInProject(String sourcePath) {
    final result = <String, List<String>>{};

    // Search in lib/ and integration_test/ directories
    final directories = ['lib', 'integration_test']
        .map((dir) => Directory(path.join(sourcePath, dir)))
        .where((dir) => dir.existsSync());

    for (final dir in directories) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path);

      for (final filePath in dartFiles) {
        final content = File(filePath).readAsStringSync();

        // Find ValueKey and Key declarations
        final keyMatches =
            RegExp("(Value)?Key\\(['\"](.*?)['\"]\\)").allMatches(content);
        for (final match in keyMatches) {
          final key = match.group(2)!;
          result.putIfAbsent(key, () => []).add(filePath);
        }

        // Find finder methods (byValueKey, bySemanticsLabel, byTooltip)
        final finderMatches = RegExp(
                "find\\.by(ValueKey|SemanticsLabel|Tooltip)\\(['\"](.*?)['\"]\\)")
            .allMatches(content);
        for (final match in finderMatches) {
          final key = match.group(2)!;
          result.putIfAbsent(key, () => []).add(filePath);
        }
      }
    }

    return result;
  }

  /// Loads expected keys from a YAML file.
  ///
  /// The YAML file should have a 'keys' list containing strings.
  /// Example format:
  /// ```yaml
  /// keys:
  ///   - login_button
  ///   - password_field
  ///   - submit_button
  /// ```
  ///
  /// Throws [FileSystemException] if file not found.
  /// Throws [FormatException] if YAML format is invalid.
  static Set<String> loadExpectedKeys(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Keys file not found', filePath);
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;
    final keys = yaml['keys'] as YamlList?;

    if (keys == null) {
      throw FormatException('Invalid YAML format: missing "keys" list');
    }

    return keys.map((k) => k.toString()).toSet();
  }

  /// Checks if required dependencies are present in pubspec.yaml.
  ///
  /// Required dependencies:
  /// - integration_test (can be in dependencies or dev_dependencies)
  /// - appium_flutter_server (in dev_dependencies)
  static bool checkDependencies(String projectPath) {
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return false;

    final content = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    final deps = content['dependencies'] as YamlMap?;
    final devDeps = content['dev_dependencies'] as YamlMap?;

    bool hasIntegrationTest = false;
    bool hasAppiumServer = false;

    if (deps != null) {
      hasIntegrationTest = deps.containsKey('integration_test');
    }
    if (devDeps != null) {
      hasIntegrationTest |= devDeps.containsKey('integration_test');
      hasAppiumServer = devDeps.containsKey('appium_flutter_server');
    }

    return hasIntegrationTest && hasAppiumServer;
  }

  /// Checks if integration test files are properly set up.
  ///
  /// Verifies:
  /// - integration_test directory exists
  /// - At least one .dart test file exists
  /// - Appium Flutter Driver is initialized
  static bool checkIntegrationTests(String projectPath) {
    final integrationDir =
        Directory(path.join(projectPath, 'integration_test'));
    if (!integrationDir.existsSync()) return false;

    final files = integrationDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    if (files.isEmpty) return false;

    // Check for Appium Flutter Driver initialization
    bool hasAppiumInit = false;
    for (final file in files) {
      final content = file.readAsStringSync();
      if (content.contains(
              'import \'package:appium_flutter_server/appium_flutter_server.dart\'') &&
          content.contains('initializeTest(')) {
        hasAppiumInit = true;
        break;
      }
    }

    return hasAppiumInit;
  }

  /// Main validation function that checks keys in Flutter source code.
  ///
  /// Parameters:
  /// - [keysPath]: Path to YAML file containing expected keys
  /// - [sourcePath]: Root path of Flutter project to scan
  /// - [strict]: Whether to fail if integration_test/appium_test.dart is missing
  ///
  /// Returns a [KeyValidationResult] containing validation results.
  static KeyValidationResult validateKeys({
    required String keysPath,
    String sourcePath = '.',
    bool strict = false,
  }) {
    // Load expected keys
    final expectedKeys = loadExpectedKeys(keysPath);

    // Find keys in project
    final foundKeys = findKeysInProject(sourcePath);

    // Calculate missing and extra keys
    final missingKeys = expectedKeys.difference(foundKeys.keys.toSet());
    final extraKeys = foundKeys.keys.toSet().difference(expectedKeys);

    // Check dependencies and integration tests
    final hasDeps = checkDependencies(sourcePath);
    final hasTests = checkIntegrationTests(sourcePath);

    return KeyValidationResult(
      missingKeys: missingKeys,
      extraKeys: extraKeys,
      matchedKeys: foundKeys,
      hasDependencies: hasDeps,
      hasIntegrationTests: hasTests,
    );
  }
}
