import 'dart:io';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/diff_result.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';

/// Diff command - compare snapshots
class DiffCommand extends BaseCommandV3 {
  @override
  final name = 'diff';

  @override
  final description = 'Compare key snapshots to identify changes';

  DiffCommand() {
    argParser
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

      // Load baseline
      final baseline = await _loadSnapshot(
        argResults!['baseline'] as String,
        'baseline',
        config,
      );

      if (baseline == null) {
        logError('Failed to load baseline snapshot');
        return ExitCode.ioError;
      }

      // Load current
      final current = await _loadSnapshot(
        argResults!['current'] as String,
        'current',
        config,
      );

      if (current == null) {
        logError('Failed to load current snapshot');
        return ExitCode.ioError;
      }

      // Perform diff
      final diff = _performDiff(baseline, current);

      // Display results
      _displayDiff(diff);

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
      final scanner = AstScannerV3(
        projectPath: Directory.current.path,
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
      if (argResults!['verbose'] as bool ||
          !(argResults!['only-changes'] as bool)) {
        for (final key in diff.added) {
          logInfo('    + $key');
          if (argResults!['show-locations'] as bool) {
            final usage = diff.current.keyUsages[key];
            for (final location in usage!.locations) {
              logVerbose('      ${location.file}:${location.line}');
            }
          }
        }
      }
    }

    if (diff.removed.isNotEmpty) {
      logWarning('  • Removed: ${diff.removed.length}');
      if (argResults!['verbose'] as bool ||
          !(argResults!['only-changes'] as bool)) {
        for (final key in diff.removed) {
          logWarning('    - $key');
          if (argResults!['show-locations'] as bool) {
            final usage = diff.baseline.keyUsages[key];
            for (final location in usage!.locations) {
              logVerbose('      ${location.file}:${location.line}');
            }
          }
        }
      }
    }

    if (diff.renamed.isNotEmpty) {
      logInfo('  • Renamed: ${diff.renamed.length}');
      if (argResults!['verbose'] as bool ||
          !(argResults!['only-changes'] as bool)) {
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
}
