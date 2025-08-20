import 'dart:convert';
import 'dart:io';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/diff_result.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:path/path.dart' as path;

/// Diff command - compare snapshots
class DiffCommand extends BaseCommandV3 {
  @override
  final name = 'diff';

  @override
  final description = 'Compare key snapshots to identify changes';

  DiffCommand() {
    argParser
      ..addOption(
        'baseline-old',
        help: 'Old baseline file path',
      )
      ..addOption(
        'baseline-new',
        help: 'New baseline file path',
      )
      ..addOption(
        'baseline',
        help: 'Baseline source (registry, file path)',
        defaultsTo: 'registry',
      )
      ..addOption(
        'current',
        help: 'Current source (scan, file path)',
        defaultsTo: 'scan',
      )
      ..addOption(
        'left',
        help: 'Left file for comparison (alternative to baseline)',
      )
      ..addOption(
        'right',
        help: 'Right file for comparison (alternative to current)',
      )
      ..addOption(
        'rule',
        help: 'Diff rule to apply',
        allowed: ['default', 'missing-in-app'],
        defaultsTo: 'default',
      )
      ..addMultiOption(
        'report',
        help: 'Report formats to generate',
        allowed: ['text', 'json', 'html', 'markdown', 'md'],
        defaultsTo: ['text'],
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file for reports',
      )
      ..addFlag(
        'show-locations',
        help: 'Show file locations for keys',
        defaultsTo: false,
      )
      ..addFlag(
        'only-changes',
        help: 'Show only changed keys',
        defaultsTo: true,
      );
  }

  @override
  Future<int> run() async {
    try {
      logInfo('🔍 Comparing key snapshots...');

      final config = await loadConfig();
      final outDir = await ensureOutputDir();

      // Check for new baseline-old/baseline-new pattern
      final baselineOldPath = argResults!['baseline-old'] as String?;
      final baselineNewPath = argResults!['baseline-new'] as String?;

      // Check if using left/right pattern (for package comparison)
      final leftPath = argResults!['left'] as String?;
      final rightPath = argResults!['right'] as String?;
      final rule = argResults!['rule'] as String;

      ScanResult? baseline;
      ScanResult? current;

      if (baselineOldPath != null && baselineNewPath != null) {
        // Using baseline-old/baseline-new pattern
        baseline = await _loadFromBaselineFile(baselineOldPath);
        current = await _loadFromBaselineFile(baselineNewPath);

        if (baseline == null) {
          logError('Failed to load old baseline: $baselineOldPath');
          return ExitCode.ioError;
        }
        if (current == null) {
          logError('Failed to load new baseline: $baselineNewPath');
          return ExitCode.ioError;
        }
      } else if (leftPath != null && rightPath != null) {
        // Using left/right comparison pattern
        baseline = await _loadFromFile(leftPath);
        current = await _loadFromFile(rightPath);

        if (baseline == null) {
          logError('Failed to load left file: $leftPath');
          return ExitCode.ioError;
        }
        if (current == null) {
          logError('Failed to load right file: $rightPath');
          return ExitCode.ioError;
        }
      } else {
        // Using traditional baseline/current pattern
        baseline = await _loadSnapshot(
          argResults!['baseline'] as String,
          'baseline',
          config,
        );

        if (baseline == null) {
          logError('Failed to load baseline snapshot');
          return ExitCode.ioError;
        }

        current = await _loadSnapshot(
          argResults!['current'] as String,
          'current',
          config,
        );

        if (current == null) {
          logError('Failed to load current snapshot');
          return ExitCode.ioError;
        }
      }

      // Perform diff based on rule
      final diff = rule == 'missing-in-app'
          ? _performPackageDiff(baseline, current)
          : _performDiff(baseline, current);

      // Display results to console
      _displayDiff(diff);

      // Generate reports in requested formats
      final formats = argResults!['report'] as List<String>;
      final outputPath = argResults!['output'] as String?;

      for (final format in formats) {
        await _generateReport(diff, format, outputPath, outDir);
      }

      // Return exit code based on changes
      if (diff.hasChanges) {
        return ExitCode.policyViolation; // Exit 1 when changes found
      } else {
        return ExitCode.ok;
      }
    } catch (e) {
      return handleError(e);
    }
  }

  Future<ScanResult?> _loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      return ScanResult.fromJson(await file.readAsString());
    } catch (e) {
      logError('Failed to parse file: $path - $e');
      return null;
    }
  }

  Future<ScanResult?> _loadSnapshot(
    String source,
    String type,
    ConfigV3 config,
  ) async {
    if (source == 'registry') {
      logVerbose('Loading $type from registry...');
      final registry = await getRegistry(config);
      return await registry.getBaseline();
    } else if (source == 'scan') {
      logVerbose('Performing scan for $type...');
      final projectRoot =
          argResults!['project-root'] as String? ?? Directory.current.path;
      final scanner = AstScannerV3(
        projectPath: projectRoot,
        config: config,
      );
      return await scanner.scan();
    } else {
      // Load from file
      logVerbose('Loading $type from file: $source');
      final file = File(source);
      if (!await file.exists()) {
        logError('File not found: $source');
        return null;
      }
      return ScanResult.fromJson(await file.readAsString());
    }
  }

  DiffResult _performPackageDiff(ScanResult packageKeys, ScanResult appKeys) {
    // For missing-in-app rule: find keys in packages but not in app
    final packageKeySet = packageKeys.keyUsages.keys.toSet();
    final appKeySet = appKeys.keyUsages.keys.toSet();

    final missingInApp = packageKeySet.difference(appKeySet);

    return DiffResult(
      added: {}, // No additions in this context
      removed: missingInApp, // Keys missing from app
      renamed: {},
      unchanged: appKeySet.intersection(packageKeySet),
      baseline: packageKeys,
      current: appKeys,
    );
  }

  DiffResult _performDiff(ScanResult baseline, ScanResult current) {
    final baselineKeys = baseline.keyUsages.keys.toSet();
    final currentKeys = current.keyUsages.keys.toSet();

    final added = currentKeys.difference(baselineKeys);
    final removed = baselineKeys.difference(currentKeys);
    final unchanged = baselineKeys.intersection(currentKeys);

    // Check for renamed keys (heuristic based on similarity)
    final renamed = <String, String>{};
    for (final removedKey in removed) {
      for (final addedKey in added) {
        if (_isSimilarKey(removedKey, addedKey)) {
          renamed[removedKey] = addedKey;
        }
      }
    }

    // Remove renamed from added/removed
    for (final entry in renamed.entries) {
      removed.remove(entry.key);
      added.remove(entry.value);
    }

    return DiffResult(
      added: added,
      removed: removed,
      renamed: renamed,
      unchanged: unchanged,
      baseline: baseline,
      current: current,
    );
  }

  bool _isSimilarKey(String key1, String key2) {
    // Simple heuristic: check if keys share significant parts
    final parts1 = key1.split(RegExp(r'[._-]'));
    final parts2 = key2.split(RegExp(r'[._-]'));

    final common = parts1.toSet().intersection(parts2.toSet());
    final similarity =
        common.length / (parts1.length + parts2.length - common.length);

    return similarity > 0.6; // 60% similarity threshold
  }

  void _displayDiff(DiffResult diff) {
    logInfo('📊 Diff Summary:');
    logInfo('  • Total keys: ${diff.current.keyUsages.length}');
    logInfo('  • Unchanged: ${diff.unchanged.length}');

    if (diff.added.isNotEmpty) {
      logInfo('  • Added: ${diff.added.length}');
      if (!(argResults!['only-changes'] as bool)) {
        for (final key in diff.added) {
          logInfo('    + $key');
          if (argResults!['show-locations'] as bool) {
            final usage = diff.current.keyUsages[key];
            for (final location in usage!.locations) {
              logInfo('      ${location.file}:${location.line}');
            }
          }
        }
      }
    }

    if (diff.removed.isNotEmpty) {
      logWarning('  • Removed: ${diff.removed.length}');
      if (!(argResults!['only-changes'] as bool)) {
        for (final key in diff.removed) {
          logWarning('    - $key');
          if (argResults!['show-locations'] as bool) {
            final usage = diff.baseline.keyUsages[key];
            for (final location in usage!.locations) {
              logInfo('      ${location.file}:${location.line}');
            }
          }
        }
      }
    }

    if (diff.renamed.isNotEmpty) {
      logInfo('  • Renamed: ${diff.renamed.length}');
      if (!(argResults!['only-changes'] as bool)) {
        for (final entry in diff.renamed.entries) {
          logInfo('    ~ ${entry.key} → ${entry.value}');
        }
      }
    }

    // Calculate drift
    final totalChanges =
        diff.added.length + diff.removed.length + diff.renamed.length;
    final totalKeys = diff.baseline.keyUsages.length;
    final driftPercentage =
        totalKeys > 0 ? (totalChanges / totalKeys * 100) : 0.0;

    logInfo('  • Drift: ${driftPercentage.toStringAsFixed(1)}%');

    if (diff.hasChanges) {
      logWarning('⚠️  Changes detected');
    } else {
      logInfo('✅ No changes detected');
    }
  }

  Future<ScanResult?> _loadFromBaselineFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Check if it's the new baseline format
      if (json.containsKey('metadata') && json.containsKey('keys')) {
        return _convertBaselineToScanResult(json);
      } else {
        // Try to load as regular ScanResult
        return ScanResult.fromJson(content);
      }
    } catch (e) {
      logError('Failed to parse baseline file: $path - $e');
      return null;
    }
  }

  ScanResult _convertBaselineToScanResult(Map<String, dynamic> baseline) {
    final metrics = ScanMetrics();
    final fileAnalyses = <String, FileAnalysis>{};
    final keyUsages = <String, KeyUsage>{};

    // Process keys from baseline
    final keys = baseline['keys'] as List<dynamic>;
    for (final keyData in keys) {
      final key = keyData['key'] as String;
      final file = keyData['file'] as String;
      final line = keyData['line'] as int? ?? 0;
      final package = keyData['package'] as String? ?? 'my_app';
      final type = keyData['type'] as String? ?? 'Key';
      final depLevel = keyData['dependency_level'] as String? ?? 'direct';

      // Create or update key usage
      final usage = keyUsages.putIfAbsent(
          key,
          () => KeyUsage(
                id: key,
                source: depLevel == 'direct' ? 'workspace' : 'package',
                package: package,
              ));

      usage.locations.add(KeyLocation(
        file: file,
        line: line,
        column: 0,
        detector: 'baseline',
        context: '$type(\'$key\')',
      ));

      // Add tags if present
      if (keyData['tags'] != null) {
        usage.tags.addAll((keyData['tags'] as List).cast<String>());
      }

      // Set status if present
      if (keyData['status'] != null) {
        usage.status = keyData['status'] as String;
      }

      // Track file analysis
      final analysis = fileAnalyses.putIfAbsent(
          file,
          () => FileAnalysis(
                path: file,
                relativePath: file,
              ));
      analysis.keysFound.add(key);
    }

    // Update metrics
    metrics.totalFiles = fileAnalyses.length;
    metrics.scannedFiles = fileAnalyses.length;

    return ScanResult(
      metrics: metrics,
      fileAnalyses: fileAnalyses,
      keyUsages: keyUsages,
      blindSpots: [],
      duration: Duration.zero,
    );
  }

  Future<void> _generateReport(
    DiffResult diff,
    String format,
    String? outputPath,
    Directory outDir,
  ) async {
    final buffer = StringBuffer();

    switch (format) {
      case 'json':
        await _generateJsonReport(diff, outputPath, outDir);
        break;
      case 'html':
        await _generateHtmlReport(diff, outputPath, outDir);
        break;
      case 'markdown':
      case 'md':
        await _generateMarkdownReport(diff, outputPath, outDir);
        break;
      case 'text':
      default:
        // Text report is already displayed in console
        if (outputPath != null) {
          await _generateTextReport(diff, outputPath, outDir);
        }
        break;
    }
  }

  Future<void> _generateJsonReport(
    DiffResult diff,
    String? outputPath,
    Directory outDir,
  ) async {
    final report = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'total_keys': diff.current.keyUsages.length,
        'added': diff.added.length,
        'removed': diff.removed.length,
        'renamed': diff.renamed.length,
        'unchanged': diff.unchanged.length,
        'has_changes': diff.hasChanges,
      },
      'changes': {
        'added': diff.added.toList()..sort(),
        'removed': diff.removed.toList()..sort(),
        'renamed': diff.renamed.map((k, v) => MapEntry(k, v)),
        'modified': <String>[], // For future enhancement
      },
    };

    final filePath = outputPath ?? path.join(outDir.path, 'diff-report.json');
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(report));
    logInfo('📊 JSON report saved to: $filePath');
  }

  Future<void> _generateHtmlReport(
    DiffResult diff,
    String? outputPath,
    Directory outDir,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <title>Flutter KeyCheck Diff Report</title>');
    buffer.writeln(_getHtmlStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <div class="container">');
    buffer.writeln('    <h1>🔑 Flutter KeyCheck Diff Report</h1>');
    buffer.writeln(
        '    <div class="timestamp">Generated: ${DateTime.now().toIso8601String()}</div>');

    // Summary
    buffer.writeln('    <div class="summary">');
    buffer.writeln('      <h2>Summary</h2>');
    buffer.writeln('      <div class="stats">');
    buffer.writeln('        <div class="stat added">');
    buffer.writeln('          <div class="label">Added</div>');
    buffer.writeln('          <div class="value">+${diff.added.length}</div>');
    buffer.writeln('        </div>');
    buffer.writeln('        <div class="stat removed">');
    buffer.writeln('          <div class="label">Removed</div>');
    buffer
        .writeln('          <div class="value">-${diff.removed.length}</div>');
    buffer.writeln('        </div>');
    buffer.writeln('        <div class="stat renamed">');
    buffer.writeln('          <div class="label">Renamed</div>');
    buffer
        .writeln('          <div class="value">~${diff.renamed.length}</div>');
    buffer.writeln('        </div>');
    buffer.writeln('        <div class="stat unchanged">');
    buffer.writeln('          <div class="label">Unchanged</div>');
    buffer
        .writeln('          <div class="value">${diff.unchanged.length}</div>');
    buffer.writeln('        </div>');
    buffer.writeln('      </div>');
    buffer.writeln('    </div>');

    // Changes details
    if (diff.added.isNotEmpty) {
      buffer.writeln('    <div class="section added">');
      buffer.writeln('      <h2>✅ Added Keys</h2>');
      buffer.writeln('      <ul>');
      for (final key in diff.added.toList()..sort()) {
        buffer.writeln('        <li><code>$key</code></li>');
      }
      buffer.writeln('      </ul>');
      buffer.writeln('    </div>');
    }

    if (diff.removed.isNotEmpty) {
      buffer.writeln('    <div class="section removed">');
      buffer.writeln('      <h2>❌ Removed Keys</h2>');
      buffer.writeln('      <ul>');
      for (final key in diff.removed.toList()..sort()) {
        buffer.writeln('        <li><code>$key</code></li>');
      }
      buffer.writeln('      </ul>');
      buffer.writeln('    </div>');
    }

    if (diff.renamed.isNotEmpty) {
      buffer.writeln('    <div class="section renamed">');
      buffer.writeln('      <h2>🔄 Renamed Keys</h2>');
      buffer.writeln('      <ul>');
      for (final entry in diff.renamed.entries) {
        buffer.writeln(
            '        <li><code>${entry.key}</code> → <code>${entry.value}</code></li>');
      }
      buffer.writeln('      </ul>');
      buffer.writeln('    </div>');
    }

    buffer.writeln('  </div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    final filePath = outputPath ?? path.join(outDir.path, 'diff-report.html');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
    logInfo('📊 HTML report saved to: $filePath');
  }

  Future<void> _generateMarkdownReport(
    DiffResult diff,
    String? outputPath,
    Directory outDir,
  ) async {
    final buffer = StringBuffer();

    // GitHub PR-friendly markdown
    buffer.writeln('## 🔑 Flutter Keys Report');
    buffer.writeln();
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Keys | ${diff.current.keyUsages.length} |');

    final totalChanges = diff.added.length + diff.removed.length;
    final changeIndicator = totalChanges > 0
        ? totalChanges > 5
            ? '⚠️'
            : '✅'
        : '✅';

    buffer.writeln('| Added | +${diff.added.length} |');
    buffer.writeln('| Removed | -${diff.removed.length} |');
    buffer.writeln('| Renamed | ~${diff.renamed.length} |');
    buffer.writeln(
        '| Status | ${diff.hasChanges ? "$changeIndicator Changes detected" : "✅ No changes"} |');
    buffer.writeln();

    // Details section
    if (diff.hasChanges) {
      buffer.writeln('### Changes Details');
      buffer.writeln();

      if (diff.added.isNotEmpty) {
        buffer.writeln('<details>');
        buffer
            .writeln('<summary>✅ Added Keys (${diff.added.length})</summary>');
        buffer.writeln();
        for (final key in diff.added.toList()..sort()) {
          buffer.writeln('- `$key`');
        }
        buffer.writeln();
        buffer.writeln('</details>');
        buffer.writeln();
      }

      if (diff.removed.isNotEmpty) {
        buffer.writeln('<details>');
        buffer.writeln(
            '<summary>❌ Removed Keys (${diff.removed.length})</summary>');
        buffer.writeln();
        for (final key in diff.removed.toList()..sort()) {
          buffer.writeln('- `$key`');
        }
        buffer.writeln();
        buffer.writeln('</details>');
        buffer.writeln();
      }

      if (diff.renamed.isNotEmpty) {
        buffer.writeln('<details>');
        buffer.writeln(
            '<summary>🔄 Renamed Keys (${diff.renamed.length})</summary>');
        buffer.writeln();
        for (final entry in diff.renamed.entries) {
          buffer.writeln('- `${entry.key}` → `${entry.value}`');
        }
        buffer.writeln();
        buffer.writeln('</details>');
      }
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('_Generated by Flutter KeyCheck v3.0.0_');

    final filePath = outputPath ?? path.join(outDir.path, 'diff-report.md');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
    logInfo('📊 Markdown report saved to: $filePath');
  }

  Future<void> _generateTextReport(
    DiffResult diff,
    String? outputPath,
    Directory outDir,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('Flutter KeyCheck Diff Report');
    buffer.writeln('=' * 50);
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Summary:');
    buffer.writeln('  Total Keys: ${diff.current.keyUsages.length}');
    buffer.writeln('  Added: ${diff.added.length}');
    buffer.writeln('  Removed: ${diff.removed.length}');
    buffer.writeln('  Renamed: ${diff.renamed.length}');
    buffer.writeln('  Unchanged: ${diff.unchanged.length}');
    buffer.writeln();

    if (diff.added.isNotEmpty) {
      buffer.writeln('Added Keys:');
      for (final key in diff.added.toList()..sort()) {
        buffer.writeln('  + $key');
      }
      buffer.writeln();
    }

    if (diff.removed.isNotEmpty) {
      buffer.writeln('Removed Keys:');
      for (final key in diff.removed.toList()..sort()) {
        buffer.writeln('  - $key');
      }
      buffer.writeln();
    }

    if (diff.renamed.isNotEmpty) {
      buffer.writeln('Renamed Keys:');
      for (final entry in diff.renamed.entries) {
        buffer.writeln('  ~ ${entry.key} → ${entry.value}');
      }
      buffer.writeln();
    }

    final filePath = outputPath ?? path.join(outDir.path, 'diff-report.txt');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
    logInfo('📊 Text report saved to: $filePath');
  }

  String _getHtmlStyles() {
    return '''
    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        margin: 0;
        padding: 20px;
        background: #f8f9fa;
      }
      .container {
        max-width: 1200px;
        margin: 0 auto;
        background: white;
        padding: 30px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      h1 {
        color: #333;
        margin-bottom: 10px;
      }
      .timestamp {
        color: #666;
        font-size: 14px;
        margin-bottom: 30px;
      }
      .summary {
        background: #f8f9fa;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 30px;
      }
      .stats {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
        gap: 20px;
        margin-top: 20px;
      }
      .stat {
        text-align: center;
        padding: 15px;
        border-radius: 8px;
        background: white;
      }
      .stat.added { border-left: 4px solid #22c55e; }
      .stat.removed { border-left: 4px solid #ef4444; }
      .stat.renamed { border-left: 4px solid #3b82f6; }
      .stat.unchanged { border-left: 4px solid #6b7280; }
      .stat .label {
        font-size: 12px;
        color: #666;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }
      .stat .value {
        font-size: 28px;
        font-weight: 600;
        margin-top: 5px;
      }
      .stat.added .value { color: #22c55e; }
      .stat.removed .value { color: #ef4444; }
      .stat.renamed .value { color: #3b82f6; }
      .stat.unchanged .value { color: #6b7280; }
      .section {
        margin: 30px 0;
      }
      .section h2 {
        font-size: 18px;
        margin-bottom: 15px;
      }
      .section.added h2 { color: #22c55e; }
      .section.removed h2 { color: #ef4444; }
      .section.renamed h2 { color: #3b82f6; }
      code {
        background: #f3f4f6;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'SF Mono', Monaco, monospace;
        font-size: 14px;
      }
      ul {
        list-style: none;
        padding: 0;
      }
      li {
        padding: 8px 12px;
        margin: 4px 0;
        background: #f8f9fa;
        border-radius: 4px;
        border-left: 3px solid transparent;
      }
      .added li { border-left-color: #22c55e; }
      .removed li { border-left-color: #ef4444; }
      .renamed li { border-left-color: #3b82f6; }
    </style>
    ''';
  }
}
