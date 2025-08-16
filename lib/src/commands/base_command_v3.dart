import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/registry/key_registry_v3.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';

/// Base command class with common v3 functionality
abstract class BaseCommandV3 extends Command<int> {
  BaseCommandV3() {
    // Common flags for all commands
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false,
      )
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to configuration file',
        defaultsTo: '.flutter_keycheck.yaml',
      )
      ..addOption(
        'out-dir',
        help: 'Output directory for reports',
        defaultsTo: 'reports',
      );
  }

  /// Load configuration from file and merge with CLI args
  Future<ConfigV3> loadConfig() async {
    final configPath = argResults!['config'] as String;
    final verbose = argResults!['verbose'] as bool;

    try {
      final config = await ConfigV3.load(configPath);
      config.verbose = verbose;
      return config;
    } on FileSystemException catch (e) {
      throw ConfigException(
          'Failed to load config from $configPath: ${e.message}');
    } on FormatException catch (e) {
      throw ConfigException(
          'Invalid config format in $configPath: ${e.message}');
    }
  }

  /// Get registry instance based on configuration
  Future<KeyRegistry> getRegistry(ConfigV3 config) async {
    return KeyRegistry.create(config.registry);
  }

  /// Get reporter instance based on format
  ReporterV3 getReporter(String? format) {
    return ReporterV3.create(format ?? 'json');
  }

  /// Create output directory if needed
  Future<Directory> ensureOutputDir() async {
    final outDir = argResults!['out-dir'] as String;
    final dir = Directory(outDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Handle errors consistently
  int handleError(dynamic error) {
    if (error is ConfigException) {
      stderr.writeln('Configuration error: ${error.message}');
      return ExitCode.invalidConfig;
    } else if (error is FileSystemException) {
      stderr.writeln('IO error: ${error.message}');
      return ExitCode.ioError;
    } else if (error is PolicyViolation) {
      stderr.writeln('Policy violation: ${error.message}');
      return ExitCode.policyViolation;
    } else {
      stderr.writeln('Internal error: $error');
      return ExitCode.internalError;
    }
  }

  /// Log verbose output if enabled
  void logVerbose(String message) {
    if (argResults!['verbose'] as bool) {
      stdout.writeln('[VERBOSE] $message');
    }
  }

  /// Log info message
  void logInfo(String message) {
    stdout.writeln(message);
  }

  /// Log warning message
  void logWarning(String message) {
    stdout.writeln('[WARNING] $message');
  }

  /// Log error message
  void logError(String message) {
    stderr.writeln('[ERROR] $message');
  }
}

/// Custom exceptions
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);

  @override
  String toString() => message;
}

class PolicyViolation implements Exception {
  final String message;
  final String? policy;
  final dynamic violation;

  PolicyViolation(this.message, {this.policy, this.violation});

  @override
  String toString() => message;
}
