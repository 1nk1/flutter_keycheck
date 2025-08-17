import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

class CliResult {
  final int code;
  final String out;
  final String err;
  CliResult(this.code, this.out, this.err);
}

Future<CliResult> runCli(List<String> args, {String? cwd}) async {
  // Find the project root (where bin/flutter_keycheck.dart is)
  final projectRoot = _findProjectRoot();
  final scriptPath = path.join(projectRoot, 'bin', 'flutter_keycheck.dart');

  final p = await Process.run(
    'dart',
    ['run', scriptPath, ...args],
    workingDirectory: cwd,
    runInShell: true,
  );
  return CliResult(p.exitCode, '${p.stdout}', '${p.stderr}');
}

String _findProjectRoot() {
  // Start from the test file location and walk up
  var dir = Directory.current.path;
  while (dir != '/' && dir != '') {
    if (File(path.join(dir, 'bin', 'flutter_keycheck.dart')).existsSync()) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  // Fallback to environment variable or known path
  return Platform.environment['PROJECT_ROOT'] ??
      '/home/adj/projects/flutter_keycheck';
}

Future<void> expectExit(List<String> args,
    {required int code,
    String? stderrContains,
    String? stdoutContains,
    String? cwd}) async {
  final r = await runCli(args, cwd: cwd);
  expect(r.code, code, reason: 'stdout:\n${r.out}\nstderr:\n${r.err}');
  if (stderrContains != null) {
    expect(r.err, contains(stderrContains), reason: 'stderr:\n${r.err}');
  }
  if (stdoutContains != null) {
    expect(r.out, contains(stdoutContains), reason: 'stdout:\n${r.out}');
  }
}
