import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Configuration class for flutter_keycheck CLI tool
///
/// Supports loading configuration from YAML files and merging with CLI arguments.
/// The configuration hierarchy is: CLI arguments > Config file > Defaults
class FlutterKeycheckConfig {
  /// Path to the YAML file containing expected keys
  final String? keys;

  /// Path to the Flutter project to scan
  final String? projectPath;

  /// Whether to enable strict mode (fail if integration test setup incomplete)
  final bool? strict;

  /// Whether to enable verbose output
  final bool? verbose;

  /// Whether to fail if extra keys are found
  final bool? failOnExtra;

  /// List of patterns to include only matching keys
  final List<String>? includeOnly;

  /// List of patterns to exclude matching keys
  final List<String>? exclude;

  /// Subset of keys to track/validate (when present, only these keys are checked)
  final List<String>? trackedKeys;

  /// Output report format (human, json)
  final String? report;

  const FlutterKeycheckConfig({
    this.keys,
    this.projectPath,
    this.strict,
    this.verbose,
    this.failOnExtra,
    this.includeOnly,
    this.exclude,
    this.trackedKeys,
    this.report,
  });

  /// Creates a default configuration with sensible defaults
  factory FlutterKeycheckConfig.defaults() {
    return const FlutterKeycheckConfig(
      keys: 'keys/expected_keys.yaml',
      projectPath: '.',
      strict: false,
      verbose: false,
      failOnExtra: false,
      includeOnly: null,
      exclude: null,
      trackedKeys: null,
      report: 'human',
    );
  }

  /// Loads configuration from a YAML file
  ///
  /// Returns null if file doesn't exist or has invalid format.
  /// Prints appropriate messages for user feedback.
  static FlutterKeycheckConfig? loadFromFile(String configPath) {
    final file = File(configPath);

    if (!file.existsSync()) {
      return null;
    }

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;

      if (yaml == null) {
        return null;
      }

      print('📄 Loaded config from $configPath ✅');

      return FlutterKeycheckConfig(
        keys: yaml['keys']?.toString(),
        projectPath: yaml['path']?.toString(),
        strict: yaml['strict'] as bool?,
        verbose: yaml['verbose'] as bool?,
        failOnExtra: yaml['fail_on_extra'] as bool?,
        includeOnly: (yaml['include_only'] as YamlList?)
            ?.map((e) => e.toString())
            .toList(),
        exclude:
            (yaml['exclude'] as YamlList?)?.map((e) => e.toString()).toList(),
        trackedKeys: (yaml['tracked_keys'] as YamlList?)
            ?.map((e) => e.toString())
            .toList(),
        report: yaml['report']?.toString(),
      );
    } catch (e) {
      print('⚠️  Error reading $configPath: $e');
      return null;
    }
  }

  /// Merges this configuration with CLI arguments
  ///
  /// CLI arguments take priority over configuration file values.
  FlutterKeycheckConfig mergeWith({
    String? keys,
    String? projectPath,
    bool? strict,
    bool? verbose,
    bool? failOnExtra,
    List<String>? includeOnly,
    List<String>? exclude,
    List<String>? trackedKeys,
    String? report,
  }) {
    return FlutterKeycheckConfig(
      keys: keys ?? this.keys,
      projectPath: projectPath ?? this.projectPath,
      strict: strict ?? this.strict,
      verbose: verbose ?? this.verbose,
      failOnExtra: failOnExtra ?? this.failOnExtra,
      includeOnly: includeOnly ?? this.includeOnly,
      exclude: exclude ?? this.exclude,
      trackedKeys: trackedKeys ?? this.trackedKeys,
      report: report ?? this.report,
    );
  }

  /// Returns the effective keys file path, resolving relative paths
  String getKeysPath() {
    final keysPath = keys ?? 'keys/expected_keys.yaml';
    if (path.isAbsolute(keysPath)) {
      return keysPath;
    }
    return path.join(projectPath ?? '.', keysPath);
  }

  /// Returns the effective project path
  String getProjectPath() {
    return projectPath ?? '.';
  }

  /// Returns whether strict mode is enabled
  bool isStrict() {
    return strict ?? false;
  }

  /// Returns whether verbose mode is enabled
  bool isVerbose() {
    return verbose ?? false;
  }

  /// Returns whether to fail on extra keys
  bool shouldFailOnExtra() {
    return failOnExtra ?? false;
  }

  /// Returns the effective include-only patterns
  List<String> getIncludeOnly() {
    return includeOnly ?? [];
  }

  /// Returns the effective exclude patterns
  List<String> getExclude() {
    return exclude ?? [];
  }

  /// Returns the tracked keys list (subset of keys to validate)
  ///
  /// When present, only these keys are validated against the project.
  /// If null or empty, all keys from the expected keys file are validated.
  List<String>? getTrackedKeys() {
    return trackedKeys;
  }

  /// Returns the effective report format
  String getReportFormat() {
    return report ?? 'human';
  }

  /// Returns true if tracked keys feature is enabled
  bool hasTrackedKeys() {
    return trackedKeys != null && trackedKeys!.isNotEmpty;
  }

  @override
  String toString() {
    return 'FlutterKeycheckConfig{'
        'keys: $keys, '
        'projectPath: $projectPath, '
        'strict: $strict, '
        'verbose: $verbose, '
        'failOnExtra: $failOnExtra, '
        'includeOnly: $includeOnly, '
        'exclude: $exclude, '
        'trackedKeys: $trackedKeys, '
        'report: $report'
        '}';
  }
}
