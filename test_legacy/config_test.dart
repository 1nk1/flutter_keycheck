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
  group('FlutterKeycheckConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_keycheck_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('defaults', () {
      test('should create default configuration', () {
        final config = FlutterKeycheckConfig.defaults();

        expect(config.keys, equals('keys/expected_keys.yaml'));
        expect(config.projectPath, equals('.'));
        expect(config.strict, equals(false));
        expect(config.verbose, equals(false));
        expect(config.failOnExtra, equals(false));
        expect(config.includeOnly, isNull);
        expect(config.exclude, isNull);
        expect(config.trackedKeys, isNull);
        expect(config.report, equals('human'));
      });
    });

    group('loadFromFile', () {
      test('should return null for non-existent file', () {
        final configPath = path.join(tempDir.path, 'non_existent.yaml');
        final config = FlutterKeycheckConfig.loadFromFile(configPath);
        expect(config, isNull);
      });

      test('should load basic config from file', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('''
keys: custom_keys.yaml
path: ./custom_path
strict: true
verbose: true
fail_on_extra: true
report: json
''');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNotNull);
        expect(config!.keys, equals('custom_keys.yaml'));
        expect(config.projectPath, equals('./custom_path'));
        expect(config.strict, equals(true));
        expect(config.verbose, equals(true));
        expect(config.failOnExtra, equals(true));
        expect(config.report, equals('json'));
      });

      test('should load config with include_only list', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('''
include_only:
  - qa_
  - e2e_
  - _field
''');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNotNull);
        expect(config!.includeOnly, equals(['qa_', 'e2e_', '_field']));
      });

      test('should load config with exclude list', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('''
exclude:
  - token
  - user.id
  - status
''');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNotNull);
        expect(config!.exclude, equals(['token', 'user.id', 'status']));
      });

      test('should load config with tracked_keys list', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('''
tracked_keys:
  - login_submit_button
  - signup_email_field
  - card_dropdown
''');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNotNull);
        expect(
            config!.trackedKeys,
            equals([
              'login_submit_button',
              'signup_email_field',
              'card_dropdown'
            ]));
      });

      test('should handle invalid YAML gracefully', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('invalid: yaml: content: [');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNull);
      });

      test('should handle empty file gracefully', () {
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        configFile.writeAsStringSync('');

        final config = FlutterKeycheckConfig.loadFromFile(configFile.path);
        expect(config, isNull);
      });
    });

    group('mergeWith', () {
      test('should merge CLI arguments with config', () {
        final baseConfig = const FlutterKeycheckConfig(
          keys: 'base_keys.yaml',
          projectPath: './base_path',
          strict: false,
        );

        final merged = baseConfig.mergeWith(
          keys: 'cli_keys.yaml',
          strict: true,
          verbose: true,
        );

        expect(merged.keys, equals('cli_keys.yaml')); // CLI overrides
        expect(merged.projectPath, equals('./base_path')); // Base preserved
        expect(merged.strict, equals(true)); // CLI overrides
        expect(merged.verbose, equals(true)); // CLI adds
      });

      test('should handle null values correctly', () {
        final baseConfig = const FlutterKeycheckConfig(
          keys: 'base_keys.yaml',
          verbose: true,
        );

        final merged = baseConfig.mergeWith(
          projectPath: './new_path',
        );

        expect(merged.keys, equals('base_keys.yaml')); // Preserved
        expect(merged.projectPath, equals('./new_path')); // Added
        expect(merged.verbose, equals(true)); // Preserved
      });

      test('should merge filtering options', () {
        final baseConfig = const FlutterKeycheckConfig(
          includeOnly: ['base_'],
          exclude: ['base_exclude'],
        );

        final merged = baseConfig.mergeWith(
          includeOnly: ['cli_'],
          exclude: ['cli_exclude'],
          trackedKeys: ['tracked_key'],
        );

        expect(merged.includeOnly, equals(['cli_'])); // CLI overrides
        expect(merged.exclude, equals(['cli_exclude'])); // CLI overrides
        expect(merged.trackedKeys, equals(['tracked_key'])); // CLI adds
      });
    });

    group('getter methods', () {
      test('getKeysPath should handle relative paths', () {
        final config = const FlutterKeycheckConfig(
          keys: 'keys/test.yaml',
          projectPath: './project',
        );

        final keysPath = config.getKeysPath();
        expect(keysPath, equals('./project/keys/test.yaml'));
      });

      test('getKeysPath should handle absolute paths', () {
        final config = const FlutterKeycheckConfig(
          keys: '/absolute/path/keys.yaml',
          projectPath: './project',
        );

        final keysPath = config.getKeysPath();
        expect(keysPath, equals('/absolute/path/keys.yaml'));
      });

      test('getKeysPath should use defaults when keys is null', () {
        final config = const FlutterKeycheckConfig(
          projectPath: './project',
        );

        final keysPath = config.getKeysPath();
        expect(keysPath, equals('./project/keys/expected_keys.yaml'));
      });

      test('boolean getters should return correct defaults', () {
        const config = FlutterKeycheckConfig();

        expect(config.isStrict(), equals(false));
        expect(config.isVerbose(), equals(false));
        expect(config.shouldFailOnExtra(), equals(false));
        expect(config.hasTrackedKeys(), equals(false));
      });

      test('boolean getters should return configured values', () {
        const config = FlutterKeycheckConfig(
          strict: true,
          verbose: true,
          failOnExtra: true,
          trackedKeys: ['key1', 'key2'],
        );

        expect(config.isStrict(), equals(true));
        expect(config.isVerbose(), equals(true));
        expect(config.shouldFailOnExtra(), equals(true));
        expect(config.hasTrackedKeys(), equals(true));
      });

      test('list getters should return empty lists for null values', () {
        const config = FlutterKeycheckConfig();

        expect(config.getIncludeOnly(), equals([]));
        expect(config.getExclude(), equals([]));
        expect(config.getTrackedKeys(), isNull);
      });

      test('list getters should return configured values', () {
        const config = FlutterKeycheckConfig(
          includeOnly: ['qa_', 'e2e_'],
          exclude: ['token', 'user.id'],
          trackedKeys: ['login_button', 'signup_field'],
        );

        expect(config.getIncludeOnly(), equals(['qa_', 'e2e_']));
        expect(config.getExclude(), equals(['token', 'user.id']));
        expect(
            config.getTrackedKeys(), equals(['login_button', 'signup_field']));
      });

      test('getReportFormat should return default and configured values', () {
        const defaultConfig = FlutterKeycheckConfig();
        const jsonConfig = FlutterKeycheckConfig(report: 'json');

        expect(defaultConfig.getReportFormat(), equals('human'));
        expect(jsonConfig.getReportFormat(), equals('json'));
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        const config = FlutterKeycheckConfig(
          keys: 'test_keys.yaml',
          projectPath: './test_path',
          strict: true,
          trackedKeys: ['key1', 'key2'],
        );

        final str = config.toString();
        expect(str, contains('test_keys.yaml'));
        expect(str, contains('./test_path'));
        expect(str, contains('true'));
        expect(str, contains('[key1, key2]'));
      });
    });
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
