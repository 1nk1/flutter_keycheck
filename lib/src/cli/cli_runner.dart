import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/commands/baseline_command.dart';
import 'package:flutter_keycheck/src/commands/benchmark_command.dart';
import 'package:flutter_keycheck/src/commands/diff_command.dart';
import 'package:flutter_keycheck/src/commands/report_command.dart';
import 'package:flutter_keycheck/src/commands/scan_command_v3.dart';
import 'package:flutter_keycheck/src/commands/sync_command.dart';
import 'package:flutter_keycheck/src/commands/validate_command_v3.dart';

/// Exception for configuration errors
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);

  @override
  String toString() => message;
}

/// Main CLI runner with proper error handling and exit codes
class CliRunner extends CommandRunner<int> {
  CliRunner()
      : super(
          'flutter_keycheck',
          'Track, validate, and synchronize automation keys across Flutter teams.',
        ) {
    // Add global flags
    argParser
      ..addFlag(
        'version',
        abbr: 'V',
        help: 'Show version information',
        negatable: false,
      )
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
      );

    // Add commands
    addCommand(ScanCommandV3());
    addCommand(BaselineCommand());
    addCommand(DiffCommand());
    addCommand(ValidateCommandV3());
    addCommand(SyncCommand());
    addCommand(ReportCommand());
    addCommand(BenchmarkCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      // Handle version flag
      if (args.contains('-V') || args.contains('--version')) {
        await _showVersion();
        return ExitCode.ok;
      }

      return await super.run(args) ?? ExitCode.ok;
    } on UsageException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln();
      stderr.writeln(e.usage);
      return ExitCode.invalidConfig;
    } on ConfigException catch (e) {
      stderr.writeln('Configuration error: $e');
      return ExitCode.invalidConfig;
    } catch (e) {
      stderr.writeln('Error: $e');
      return ExitCode.internalError;
    }
  }

  Future<void> _showVersion() async {
    final packageInfo = await _getPackageVersion();
    stdout.writeln('flutter_keycheck version $packageInfo');
    stdout.writeln('Dart SDK: ${Platform.version}');
  }

  Future<String> _getPackageVersion() async {
    // Read from pubspec.yaml
    final pubspecFile = File('pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      if (versionMatch != null) {
        return versionMatch.group(1)?.trim() ?? '3.0.0';
      }
    }
    return '3.0.0';
  }
}

/// Exit codes for CLI operations
class ExitCode {
  static const int ok = 0;
  static const int policyViolation = 1;
  static const int invalidConfig = 2;
  static const int ioError = 3;
  static const int internalError = 4;
}
