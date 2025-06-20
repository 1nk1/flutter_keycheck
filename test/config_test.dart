import 'dart:io';

import 'package:flutter_keycheck/src/config.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Comprehensive test suite for FlutterKeycheckConfig
///
/// This test suite demonstrates all the scenarios that can occur when loading
/// and using configuration files in flutter_keycheck CLI tool.
///
/// Key scenarios covered:
/// 1. Config file doesn't exist (graceful handling)
/// 2. Valid config file loading
/// 3. Partial config file (missing some fields)
/// 4. CLI overrides (mergeWith functionality)
/// 5. Default values and validation
/// 6. Error handling (invalid YAML, empty files)
/// 7. Debug output (toString)
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('flutter_keycheck_config_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Test Case 1: Missing config file
  ///
  /// This is the most common scenario - user hasn't created a config file yet.
  /// The CLI should gracefully handle this and rely on CLI arguments.
  test('loadFromFile returns null when config file does not exist', () {
    final config = FlutterKeycheckConfig.loadFromFile(tempDir.path);
    expect(config, isNull);
  });

  /// Test Case 2: Valid configuration file
  ///
  /// Example of a complete .flutter_keycheck.yaml file:
  /// ```yaml
  /// keys: test_keys.yaml
  /// path: ./src
  /// strict: true
  /// verbose: false
  /// ```
  test('loadFromFile loads valid configuration from file', () {
    final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
    configFile.writeAsStringSync('''
keys: test_keys.yaml
path: ./src
strict: true
verbose: false
    ''');

    final config = FlutterKeycheckConfig.loadFromFile(tempDir.path);
    expect(config, isNotNull);
    expect(config!.keys, equals('test_keys.yaml'));
    expect(config.path, equals('./src'));
    expect(config.strict, isTrue);
    expect(config.verbose, isFalse);
  });

  /// Test Case 3: Partial configuration file
  ///
  /// Users often create minimal config files with only the required fields.
  /// Example:
  /// ```yaml
  /// keys: test_keys.yaml
  /// strict: true
  /// ```
  /// Missing fields should be null and get defaults later.
  test('loadFromFile handles partial configuration', () {
    final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
    configFile.writeAsStringSync('''
keys: test_keys.yaml
strict: true
    ''');

    final config = FlutterKeycheckConfig.loadFromFile(tempDir.path);
    expect(config, isNotNull);
    expect(config!.keys, equals('test_keys.yaml'));
    expect(config.path, isNull); // Should be null, will get default later
    expect(config.strict, isTrue);
    expect(config.verbose, isNull); // Should be null, will get default later
  });

  /// Test Case 4: CLI Override Priority
  ///
  /// This demonstrates the merge functionality where CLI arguments
  /// take priority over config file values.
  ///
  /// Example usage:
  /// ```bash
  /// # Config file has keys: config_keys.yaml
  /// # But CLI overrides with different keys file
  /// flutter_keycheck --keys cli_keys.yaml --strict
  /// ```
  test('mergeWith prioritizes provided values over config values', () {
    final config = FlutterKeycheckConfig(
      keys: 'config_keys.yaml',
      path: './config_path',
      strict: false,
      verbose: true,
    );

    final merged = config.mergeWith(
      keys: 'cli_keys.yaml', // CLI override
      strict: true, // CLI override
      // path and verbose remain from config
    );

    expect(merged.keys, equals('cli_keys.yaml')); // CLI overrides
    expect(merged.path, equals('./config_path')); // Config value kept
    expect(merged.strict, isTrue); // CLI overrides
    expect(merged.verbose, isTrue); // Config value kept
  });

  /// Test Case 5: Default Values Application
  ///
  /// This tests the final resolution of configuration with default values.
  /// All configurations eventually get resolved to concrete values.
  test('getResolvedConfig applies defaults and validates required fields', () {
    final config = FlutterKeycheckConfig(
      keys: 'test_keys.yaml',
      // path, strict, verbose not provided - should get defaults
    );

    final resolved = config.getResolvedConfig();
    expect(resolved['keys'], equals('test_keys.yaml'));
    expect(resolved['path'], equals('.')); // Default value
    expect(resolved['strict'], isFalse); // Default value
    expect(resolved['verbose'], isFalse); // Default value
  });

  /// Test Case 6: Required Field Validation
  ///
  /// The 'keys' field is mandatory - if it's missing, the config should fail.
  /// This prevents users from running the tool without specifying what to check.
  test('getResolvedConfig throws when keys is missing', () {
    final config = FlutterKeycheckConfig(
      // keys not provided - this should fail
      path: './src',
      strict: true,
      verbose: false,
    );

    expect(() => config.getResolvedConfig(), throwsArgumentError);
  });

  /// Test Case 7: Invalid YAML Handling
  ///
  /// Real-world scenario: Users might create malformed YAML files.
  /// The tool should gracefully handle this and provide helpful feedback.
  ///
  /// Example of invalid YAML:
  /// ```yaml
  /// invalid: yaml: content:
  ///   - missing
  ///     - proper
  ///   structure
  /// ```
  test('loadFromFile handles invalid YAML gracefully', () {
    final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
    configFile.writeAsStringSync('''
invalid: yaml: content:
  - missing
    - proper
  structure
    ''');

    // Should not throw, but return null and print error
    final config = FlutterKeycheckConfig.loadFromFile(tempDir.path);
    expect(config, isNull);
  });

  /// Test Case 8: Empty File Handling
  ///
  /// Another real-world scenario: Users create empty config files.
  /// Should be handled gracefully.
  test('loadFromFile handles empty file gracefully', () {
    final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
    configFile.writeAsStringSync('');

    final config = FlutterKeycheckConfig.loadFromFile(tempDir.path);
    expect(config, isNull);
  });

  /// Test Case 9: Debug Information
  ///
  /// The toString method should provide useful debug information
  /// for troubleshooting configuration issues.
  test('toString provides useful debug information', () {
    final config = FlutterKeycheckConfig(
      keys: 'test_keys.yaml',
      path: './src',
      strict: true,
      verbose: false,
    );

    final string = config.toString();
    expect(string, contains('test_keys.yaml'));
    expect(string, contains('./src'));
    expect(string, contains('true'));
    expect(string, contains('false'));
  });
}

/// Example configuration files for reference:
///
/// Minimal config (.flutter_keycheck.yaml):
/// ```yaml
/// keys: keys/expected_keys.yaml
/// ```
///
/// Complete config (.flutter_keycheck.yaml):
/// ```yaml
/// keys: keys/expected_keys.yaml
/// path: .
/// strict: true
/// verbose: false
/// ```
///
/// Custom config file (my_config.yaml):
/// ```yaml
/// keys: test_keys/integration_keys.yaml
/// path: ./lib
/// strict: false
/// verbose: true
/// ```
///
/// Usage examples:
/// ```bash
/// # Using default .flutter_keycheck.yaml
/// flutter_keycheck
///
/// # Using custom config file
/// flutter_keycheck --config my_config.yaml
///
/// # Overriding config file values
/// flutter_keycheck --keys different_keys.yaml --strict
///
/// # Pure CLI (no config file)
/// flutter_keycheck --keys keys/test.yaml --path ./src --verbose
/// ```
