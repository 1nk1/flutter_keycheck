import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/config/config.dart';
import 'package:flutter_keycheck/src/registry/registry.dart';
import 'package:flutter_keycheck/src/reporter/reporter.dart';

/// Base command class with common functionality
abstract class BaseCommand extends Command<int> {
  BaseCommand() {
    argParser
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to configuration file',
        defaultsTo: '.flutter_keycheck.yaml',
      )
      ..addMultiOption(
        'packages',
        help: 'Package scanning mode',
        allowed: ['workspace', 'resolve'],
        defaultsTo: ['workspace'],
      )
      ..addOption(
        'tags-include',
        help: 'Include only keys with these tags (comma-separated)',
      )
      ..addOption(
        'tags-exclude',
        help: 'Exclude keys with these tags (comma-separated)',
      )
      ..addFlag(
        'strict',
        help: 'Enable strict mode for CI',
        defaultsTo: false,
      )
      ..addOption(
        'registry',
        help: 'Registry backend type',
        allowed: ['path', 'git', 'pkg'],
        defaultsTo: 'git',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false,
      )
      ..addOption(
        'project-root',
        help: 'Override project root for workspace resolution',
      );
  }

  /// Load configuration from file and merge with CLI args
  Future<Config> loadConfig() async {
    final configPath = argResults!['config'] as String;
    final config = await Config.load(configPath);

    // Override with CLI arguments
    if (argResults!.wasParsed('packages')) {
      config.packages = argResults!['packages'] as List<String>;
    }
    if (argResults!.wasParsed('tags-include')) {
      config.tagsInclude = (argResults!['tags-include'] as String)
          .split(',')
          .map((t) => t.trim())
          .toList();
    }
    if (argResults!.wasParsed('tags-exclude')) {
      config.tagsExclude = (argResults!['tags-exclude'] as String)
          .split(',')
          .map((t) => t.trim())
          .toList();
    }
    if (argResults!.wasParsed('strict')) {
      config.strict = argResults!['strict'] as bool;
    }
    if (argResults!.wasParsed('registry')) {
      config.registryType = argResults!['registry'] as String;
    }
    config.verbose = argResults!['verbose'] as bool;

    return config;
  }

  /// Get registry instance based on configuration
  Future<Registry> getRegistry(Config config) async {
    return Config.create(config);
  }

  /// Get reporter instance based on configuration
  Reporter getReporter(Config config, String? format) {
    return Reporter.create(format ?? config.reportFormat);
  }

  /// Standard exit codes
  static const int exitOk = 0;
  static const int exitPolicyViolation = 1;
  static const int exitInvalidConfig = 2;
  static const int exitIoError = 3;
  static const int exitInternalError = 254;

  /// Handle errors consistently
  int handleError(dynamic error) {
    if (error is ConfigException) {
      stderr.writeln('Configuration error: ${error.message}');
      return exitInvalidConfig;
    } else if (error is IOException) {
      stderr.writeln('I/O error: $error');
      return exitIoError;
    } else if (error is PolicyViolation) {
      stderr.writeln('Policy violation: ${error.message}');
      return exitPolicyViolation;
    } else {
      stderr.writeln('Internal error: $error');
      return exitInternalError;
    }
  }
}

/// Custom exceptions
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);
}

class PolicyViolation implements Exception {
  final String message;
  PolicyViolation(this.message);
}
