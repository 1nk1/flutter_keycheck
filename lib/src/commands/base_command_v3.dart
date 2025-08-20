import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/registry/key_registry_v3.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';
import 'package:path/path.dart' as path;

/// Base command class with common v3 functionality
abstract class BaseCommandV3 extends Command<int> {
  BaseCommandV3() {
    // Common flags for all commands
    argParser
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
      )
      ..addOption(
        'project-root',
        help: 'Override project root for workspace resolution',
      );
  }

  /// Load configuration from file and merge with CLI args
  Future<ConfigV3> loadConfig() async {
    var configPath = argResults!['config'] as String;
    // Get verbose flag from global arguments (CLI runner level)
    // For now, assume verbose is false since we can't access global args easily
    final verbose = false;

    // If project-root is specified and config path is relative, resolve it relative to project root
    final projectRoot = argResults!['project-root'] as String?;
    if (projectRoot != null && !path.isAbsolute(configPath)) {
      configPath = path.join(projectRoot, configPath);
    }

    // Check if config file exists
    final configFile = File(configPath);
    final configExists = await configFile.exists();

    // Only fail if user explicitly provided --config flag with non-existent file
    if (!configExists) {
      // Check if the user explicitly provided --config flag
      // Default value is '.flutter_keycheck.yaml'
      if (argResults!.wasParsed('config')) {
        stderr.writeln('[flutter_keycheck] Config file not found: $configPath');
        // Return exit code 2 for missing config when explicitly specified
        exit(2);
      }
      // If using default config path and it doesn't exist, return default config
      final config = ConfigV3.defaults();
      config.verbose = verbose;
      return config;
    }

    try {
      final config = await ConfigV3.load(configPath);
      config.verbose = verbose;
      return config;
    } on FileSystemException catch (e) {
      throw ConfigException('Failed to load config from $configPath: $e');
    } on FormatException catch (e) {
      throw ConfigException('Invalid config format in $configPath: $e');
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
    var outDir = argResults!['out-dir'] as String;

    // If project-root is specified and out-dir is relative, resolve it relative to project root
    final projectRoot = argResults!['project-root'] as String?;
    if (projectRoot != null && !path.isAbsolute(outDir)) {
      outDir = path.join(projectRoot, outDir);
    }

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
    // For now, always output verbose when called
    // Verbose flag is handled by global arguments in CLI runner
    stderr.writeln('[VERBOSE] $message');
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
