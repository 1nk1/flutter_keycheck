#!/usr/bin/env dart

import 'dart:io';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';

void main(List<String> arguments) async {
  final runner = CliRunner();

  try {
    final exitCode = await runner.run(arguments);
    exit(exitCode);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
