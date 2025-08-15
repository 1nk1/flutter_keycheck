#!/usr/bin/env dart

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/commands/scan_command_v3_proper.dart';
import 'package:flutter_keycheck/src/commands/baseline_command.dart';
import 'package:flutter_keycheck/src/commands/diff_command.dart';
import 'package:flutter_keycheck/src/commands/validate_command_v3.dart';
import 'package:flutter_keycheck/src/commands/sync_command.dart';
import 'package:flutter_keycheck/src/commands/report_command.dart';
import 'package:ansicolor/ansicolor.dart';

const String version = '3.0.0-rc.1';

void main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'flutter_keycheck',
    'Flutter Widget Key Coverage Analyzer v$version',
  );

  // Add global flags
  runner.argParser
    ..addFlag('version', abbr: 'V', help: 'Show version', negatable: false)
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false)
    ..addFlag('no-color', help: 'Disable colored output', negatable: false);

  // Add commands
  runner
    ..addCommand(ScanCommandV3Proper())
    ..addCommand(BaselineCommand())
    ..addCommand(DiffCommand())
    ..addCommand(ValidateCommandV3())
    ..addCommand(SyncCommand())
    ..addCommand(ReportCommand());

  // Add ci-validate alias for validate command
  runner.addCommand(CiValidateCommand());

  try {
    // Handle version flag specially
    if (arguments.contains('-V') || arguments.contains('--version')) {
      stdout.writeln('flutter_keycheck v$version');
      exit(0);
    }

    // Handle no-color flag
    if (arguments.contains('--no-color')) {
      ansiColorDisabled = true;
    }

    await runner.run(arguments);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln(e.message);
      stderr.writeln();
      stderr.writeln(e.usage);
      exit(2); // Config error
    } else {
      stderr.writeln('Error: $e');
      exit(4); // Internal error
    }
  }
}

/// Alias for validate command used in CI/CD pipelines
class CiValidateCommand extends ValidateCommandV3 {
  @override
  final name = 'ci-validate';

  @override
  final description = 'Alias for validate command (for CI/CD pipelines)';
}