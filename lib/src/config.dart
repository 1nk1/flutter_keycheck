import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:yaml/yaml.dart';

/// Configuration class for flutter_keycheck
class FlutterKeycheckConfig {
  /// Path to keys file (.yaml)
  final String? keys;

  /// Project source root
  final String? path;

  /// Fail if integration_test/appium_test.dart is missing
  final bool? strict;

  /// Show detailed output
  final bool? verbose;

  /// Fail if extra keys (not in expected list) are found
  final bool? failOnExtra;

  /// Constructor
  const FlutterKeycheckConfig({
    this.keys,
    this.path,
    this.strict,
    this.verbose,
    this.failOnExtra,
  });

  /// Default config file name
  static const String configFileName = '.flutter_keycheck.yaml';

  /// Loads configuration from .flutter_keycheck.yaml file
  static FlutterKeycheckConfig? loadFromFile([String? directory]) {
    directory ??= Directory.current.path;
    final configFile = File('$directory/$configFileName');

    if (!configFile.existsSync()) {
      return null;
    }

    try {
      final content = configFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;

      if (yaml == null) {
        return null;
      }

      // Show success message
      final green = AnsiPen()..green(bold: true);
      print('${green('📄 Loaded config from $configFileName')} ✅');

      return FlutterKeycheckConfig(
        keys: yaml['keys']?.toString(),
        path: yaml['path']?.toString(),
        strict: yaml['strict'] as bool?,
        verbose: yaml['verbose'] as bool?,
        failOnExtra: yaml['fail_on_extra'] as bool?,
      );
    } catch (e) {
      final red = AnsiPen()..red(bold: true);
      print('${red('⚠️  Error reading $configFileName:')} $e');
      return null;
    }
  }

  /// Merges CLI arguments with config file values
  /// CLI arguments take priority over config file
  FlutterKeycheckConfig mergeWith({
    String? keys,
    String? path,
    bool? strict,
    bool? verbose,
    bool? failOnExtra,
  }) {
    return FlutterKeycheckConfig(
      keys: keys ?? this.keys,
      path: path ?? this.path,
      strict: strict ?? this.strict,
      verbose: verbose ?? this.verbose,
      failOnExtra: failOnExtra ?? this.failOnExtra,
    );
  }

  /// Gets the final configuration with defaults applied
  Map<String, dynamic> getResolvedConfig() {
    if (keys == null) {
      throw ArgumentError('keys parameter is required');
    }

    return {
      'keys': keys!,
      'path': path ?? '.',
      'strict': strict ?? false,
      'verbose': verbose ?? false,
      'fail_on_extra': failOnExtra ?? false,
    };
  }

  @override
  String toString() {
    return 'FlutterKeycheckConfig(keys: $keys, path: $path, strict: $strict, verbose: $verbose, failOnExtra: $failOnExtra)';
  }
}
