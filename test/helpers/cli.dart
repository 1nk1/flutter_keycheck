import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Find repo root by looking for bin/flutter_keycheck.dart
String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final bin = File(path.join(dir.path, 'bin', 'flutter_keycheck.dart'));
    final pub = File(path.join(dir.path, 'pubspec.yaml'));
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
  final binPath = path.join(repoRoot, 'bin', 'flutter_keycheck.dart');

  // Build full arguments list
  final fullArgs = <String>[];

  // Add memory limit for Windows to prevent crashes
  if (Platform.isWindows) {
    fullArgs.addAll(['--old_gen_heap_size=512']);
  }

  fullArgs.add('run');
  fullArgs.add(binPath);

  // Add --project-root if provided
  if (projectRoot != null) {
    // Ensure project root is absolute and normalized for Windows
    final absoluteProjectRoot = path.normalize(path.isAbsolute(projectRoot)
        ? projectRoot
        : path.absolute(projectRoot));
    fullArgs.addAll(['--project-root', absoluteProjectRoot]);
  }

  // Add remaining args
  fullArgs.addAll(args);

  // Use Process.run with timeout to prevent hanging
  try {
    return await Process.run(
      'dart',
      fullArgs,
      workingDirectory: repoRoot, // Always run from repo root
      environment: environment,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        // Return a failed result on timeout
        return ProcessResult(
          -1,
          255,
          '',
          'Command timed out after 30 seconds',
        );
      },
    );
  } catch (e) {
    // Return a failed result on exception
    return ProcessResult(
      -1,
      255,
      '',
      'Command failed with error: $e',
    );
  }
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
