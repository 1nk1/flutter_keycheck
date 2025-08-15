#!/usr/bin/env dart

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/commands/scan_command.dart';
import 'package:flutter_keycheck/src/commands/baseline_command.dart';
import 'package:flutter_keycheck/src/commands/diff_command.dart';
import 'package:flutter_keycheck/src/commands/validate_command.dart';
import 'package:flutter_keycheck/src/commands/sync_command.dart';
import 'package:flutter_keycheck/src/commands/report_command.dart';

void main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'flutter_keycheck',
    'Flutter automation key validation and tracking tool',
  )
    ..argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print version',
    )
    ..argParser.addFlag(
      'verbose',
      negatable: false,
      help: 'Enable verbose output',
    );

  // Add commands
  runner
    ..addCommand(ScanCommand())
    ..addCommand(BaselineCommand())
    ..addCommand(DiffCommand())
    ..addCommand(ValidateCommand())
    ..addCommand(SyncCommand())
    ..addCommand(ReportCommand());

  try {
    // Handle version flag
    if (arguments.contains('--version') || arguments.contains('-v')) {
      stdout.writeln('flutter_keycheck version 3.0.0');
      exit(0);
    }

    // Run command
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(2); // Invalid config
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(4); // Internal error
  }
}