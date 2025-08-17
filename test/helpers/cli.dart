import 'dart:io';
import 'package:test/test.dart';

/// Find repo root by looking for bin/flutter_keycheck.dart
String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final bin = File('${dir.path}/bin/flutter_keycheck.dart');
    final pub = File('${dir.path}/pubspec.yaml');
    if (bin.existsSync() && pub.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // fallback to current directory
  return Directory.current.absolute.path;
}

Future<ProcessResult> runCli(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
  String? projectRoot,
}) async {
  final repoRoot = _findRepoRoot();
  final binPath = '$repoRoot/bin/flutter_keycheck.dart';

  // Add --project-root if provided
  final fullArgs = [...args];
  if (projectRoot != null) {
    fullArgs.addAll(['--project-root', projectRoot]);
  }

  return Process.run(
    'dart',
    ['run', binPath, ...fullArgs],
    workingDirectory: repoRoot, // Always run from repo root
    environment: environment,
  );
}

/// Helper function to test exit codes
Future<void> expectExit(
  List<String> args, {
  required int code,
  String? stderrContains,
  String? stdoutContains,
  String? projectRoot,
}) async {
  final result = await runCli(args, projectRoot: projectRoot);
  expect(result.exitCode, equals(code),
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}');
  if (stderrContains != null) {
    expect(result.stderr.toString(), contains(stderrContains),
        reason: 'stderr:\n${result.stderr}');
  }
  if (stdoutContains != null) {
    expect(result.stdout.toString(), contains(stdoutContains),
        reason: 'stdout:\n${result.stdout}');
  }
}