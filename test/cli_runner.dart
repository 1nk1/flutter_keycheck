import 'package:args/command_runner.dart';

import '../lib/src/commands/diff.command.dart';
import '../lib/src/commands/report.command.dart';
import '../lib/src/commands/sync.command.dart';

/// A test CLI runner that registers the available commands for integration testing.
class CliRunner {
  /// The command runner instance with all commands registered.
  static CommandRunner get runner {
    return CommandRunner('flutter_keycheck_test', 'Test runner for Flutter Keycheck CLI')
      ..addCommand(DiffCommand())
      ..addCommand(ReportCommand())
      ..addCommand(SyncCommand());
  }
}