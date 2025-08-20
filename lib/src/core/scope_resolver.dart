import 'dart:convert';
import 'dart:io';

class ScanSet {
  final Set<String> workspace;
  final Set<String> deps;
  ScanSet(this.workspace, this.deps);
}

String _guessRepoRoot() {
  try {
    final r = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } catch (_) {}
  return Directory.current.absolute.path;
}

bool _isUnder(String path, String root) =>
    path.startsWith(root) ||
    Directory(root)
        .uri
        .resolveUri(Uri.file(path))
        .toFilePath()
        .startsWith(root);

bool _looksLikePubCache(String path) =>
    path.contains(
        '${Platform.pathSeparator}.pub-cache${Platform.pathSeparator}') ||
    path.contains(
        '${Platform.pathSeparator}Pub${Platform.pathSeparator}Cache${Platform.pathSeparator}') ||
    path.contains('hosted${Platform.pathSeparator}pub.dev') ||
    path.contains('hosted${Platform.pathSeparator}pub.dartlang.org') ||
    path.contains('git${Platform.pathSeparator}cache');

ScanSet resolveScanSet({String? overrideRoot}) {
  final repoRoot = overrideRoot ??
      Platform.environment['FKC_PROJECT_ROOT'] ??
      _guessRepoRoot();
  final pkgCfg = File('.dart_tool/package_config.json');
  final ws = <String>{};
  final dp = <String>{};

  if (!pkgCfg.existsSync()) return ScanSet(ws, dp);

  final json = jsonDecode(pkgCfg.readAsStringSync()) as Map<String, dynamic>;
  final pkgs = (json['packages'] as List).cast<Map<String, dynamic>>();

  for (final p in pkgs) {
    final rootUri = p['rootUri'] as String;

    // Resolve the actual path
    String path;
    if (rootUri.startsWith('file://')) {
      path = Uri.parse(rootUri).toFilePath();
    } else if (rootUri.startsWith('../') || rootUri.startsWith('./')) {
      path = Directory.current.uri.resolve(rootUri).toFilePath();
    } else {
      path = rootUri;
    }

    // Normalize path
    path = Directory(path).absolute.path;

    if (_looksLikePubCache(path)) {
      dp.add(path);
    } else if (_isUnder(path, repoRoot)) {
      ws.add(path);
    } else {
      // Outside repo but not pub-cache (e.g. git submodules) - consider deps
      dp.add(path);
    }
  }

  return ScanSet(ws, dp);
}
