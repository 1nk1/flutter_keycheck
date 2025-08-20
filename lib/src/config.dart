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

  /// Output report format (human, json, html, markdown, junit)
  final String? report;

  /// Export configuration for reports
  final String? exportPath;
  
  /// Quality thresholds (v3 features)
  final Map<String, dynamic>? qualityThresholds;
  
  /// Enable AST-based scanning (v3 feature)
  final bool? useAstScanning;
  
  /// Include test files in AST scanning
  final bool? includeTestsInAst;
  
  /// Cache directory for performance optimization
  final String? cacheDir;
  
  /// Enable performance metrics
  final bool? enableMetrics;

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
    this.exportPath,
    this.qualityThresholds,
    this.useAstScanning,
    this.includeTestsInAst,
    this.cacheDir,
    this.enableMetrics,
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
      exportPath: null,
      qualityThresholds: null,
      useAstScanning: false, // Default to false for backward compatibility
      includeTestsInAst: false,
      cacheDir: '.flutter_keycheck_cache',
      enableMetrics: false,
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
        exportPath: yaml['export_path']?.toString(),
        qualityThresholds: yaml['quality_thresholds'] as Map<String, dynamic>?,
        useAstScanning: yaml['use_ast_scanning'] as bool?,
        includeTestsInAst: yaml['include_tests_in_ast'] as bool?,
        cacheDir: yaml['cache_dir']?.toString(),
        enableMetrics: yaml['enable_metrics'] as bool?,
      );
    } catch (e) {
      print('⚠️ Error reading $configPath: $e');
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
    String? exportPath,
    Map<String, dynamic>? qualityThresholds,
    bool? useAstScanning,
    bool? includeTestsInAst,
    String? cacheDir,
    bool? enableMetrics,
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
      exportPath: exportPath ?? this.exportPath,
      qualityThresholds: qualityThresholds ?? this.qualityThresholds,
      useAstScanning: useAstScanning ?? this.useAstScanning,
      includeTestsInAst: includeTestsInAst ?? this.includeTestsInAst,
      cacheDir: cacheDir ?? this.cacheDir,
      enableMetrics: enableMetrics ?? this.enableMetrics,
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

  /// Returns the export path for reports
  String? getExportPath() {
    return exportPath;
  }

  /// Returns quality thresholds configuration
  Map<String, dynamic> getQualityThresholds() {
    return qualityThresholds ?? {};
  }

  /// Returns whether AST scanning is enabled
  bool isAstScanningEnabled() {
    return useAstScanning ?? false;
  }

  /// Returns whether to include tests in AST scanning
  bool shouldIncludeTestsInAst() {
    return includeTestsInAst ?? false;
  }

  /// Returns the cache directory path
  String getCacheDir() {
    return cacheDir ?? '.flutter_keycheck_cache';
  }

  /// Returns whether metrics are enabled
  bool areMetricsEnabled() {
    return enableMetrics ?? false;
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
        'report: $report, '
        'exportPath: $exportPath, '
        'qualityThresholds: $qualityThresholds, '
        'useAstScanning: $useAstScanning, '
        'includeTestsInAst: $includeTestsInAst, '
        'cacheDir: $cacheDir, '
        'enableMetrics: $enableMetrics'
        '}';
  }
}
