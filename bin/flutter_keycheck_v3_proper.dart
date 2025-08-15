#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:flutter_keycheck/src/commands/scan_command_v3.dart';
import 'package:flutter_keycheck/src/commands/validate_command_v3.dart';

const String version = '3.0.0-rc1';

void main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'flutter_keycheck',
    'Flutter Widget Key Coverage Analyzer v$version',
  );

  // Add global flags
  runner.argParser
    ..addFlag('version', abbr: 'V', help: 'Show version', negatable: false)
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false);

  // Add commands
  runner
    ..addCommand(ScanCommandV3())
    ..addCommand(ValidateCommandV3());

  try {
    // Handle version flag specially
    if (arguments.contains('-V') || arguments.contains('--version')) {
      print('flutter_keycheck v$version');
      exit(0);
    }

    await runner.run(arguments);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln(e.message);
      stderr.writeln();
      stderr.writeln(e.usage);
      exit(64); // EX_USAGE
    } else {
      stderr.writeln('Error: $e');
      exit(1);
    }
  }
}