import 'dart:io';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:path/path.dart' as path;

/// Baseline command - create/update baseline
class BaselineCommand extends BaseCommandV3 {
  @override
  final name = 'baseline';

  @override
  final description = 'Create or update key baseline';

  BaselineCommand() {
    argParser
      ..addCommand('create')
      ..addCommand('update')
      ..addOption(
        'scan',
        help: 'Path to scan snapshot file',
      )
      ..addFlag(
        'auto-tags',
        help: 'Automatically assign tags based on patterns',
        defaultsTo: false,
      );
  }

  @override
  Future<int> run() async {
    try {
      final subcommand = argResults!.command?.name;
      if (subcommand == null) {
        logError('Please specify a subcommand: create or update');
        return ExitCode.invalidConfig;
      }

      final config = await loadConfig();
      final outDir = await ensureOutputDir();

      switch (subcommand) {
        case 'create':
          return await _createBaseline(config, outDir);
        case 'update':
          return await _updateBaseline(config, outDir);
        default:
          logError('Unknown subcommand: $subcommand');
          return ExitCode.invalidConfig;
      }
    } catch (e) {
      return handleError(e);
    }
  }

  Future<int> _createBaseline(ConfigV3 config, Directory outDir) async {
    logInfo('📝 Creating baseline...');

    // Use provided scan or perform new scan
    ScanResult scanResult;
    final scanPath = argResults!.command!['scan'] as String?;

    if (scanPath != null) {
      // Load from existing scan
      final scanFile = File(scanPath);
      if (!await scanFile.exists()) {
        logError('Scan file not found: $scanPath');
        return ExitCode.ioError;
      }
      scanResult = ScanResult.fromJson(await scanFile.readAsString());
      logInfo('Loaded scan from: $scanPath');
    } else {
      // Perform new scan
      logInfo('Performing project scan...');
      final scanner = AstScannerV3(
        projectPath: Directory.current.path,
        config: config,
      );
      scanResult = await scanner.scan();
    }

    // Apply auto-tags if requested
    if (argResults!.command!['auto-tags'] as bool) {
      _applyAutoTags(scanResult, config);
    }

    // Save baseline to registry
    final registry = await getRegistry(config);
    await registry.saveBaseline(scanResult);

    logInfo('✅ Baseline created with ${scanResult.keyUsages.length} keys');

    // Also save local copy
    final baselineFile = File(path.join(outDir.path, 'baseline.json'));
    await baselineFile.writeAsString(scanResult.toJson());
    logVerbose('Local copy saved to: ${baselineFile.path}');

    return ExitCode.ok;
  }

  Future<int> _updateBaseline(ConfigV3 config, Directory outDir) async {
    logInfo('🔄 Updating baseline...');

    // Load current baseline
    final registry = await getRegistry(config);
    final currentBaseline = await registry.getBaseline();

    if (currentBaseline == null) {
      logError('No existing baseline found. Use "baseline create" first.');
      return ExitCode.invalidConfig;
    }

    // Perform new scan
    logInfo('Scanning for changes...');
    final scanner = AstScannerV3(
      projectPath: Directory.current.path,
      config: config,
    );
    final newScan = await scanner.scan();

    // Merge with existing baseline (preserve tags, status, etc.)
    final mergedBaseline = _mergeBaselines(currentBaseline, newScan);

    // Save updated baseline
    await registry.saveBaseline(mergedBaseline);

    logInfo('✅ Baseline updated:');
    logInfo('  • Previous keys: ${currentBaseline.keyUsages.length}');
    logInfo('  • Current keys: ${mergedBaseline.keyUsages.length}');

    // Calculate changes
    final added = mergedBaseline.keyUsages.keys
        .toSet()
        .difference(currentBaseline.keyUsages.keys.toSet());
    final removed = currentBaseline.keyUsages.keys
        .toSet()
        .difference(mergedBaseline.keyUsages.keys.toSet());

    if (added.isNotEmpty) {
      logInfo('  • Added: ${added.length} keys');
    }
    if (removed.isNotEmpty) {
      logWarning('  • Removed: ${removed.length} keys');
    }

    return ExitCode.ok;
  }

  void _applyAutoTags(ScanResult result, ConfigV3 config) {
    logVerbose('Applying auto-tags based on patterns...');

    for (final entry in result.keyUsages.entries) {
      final key = entry.key;
      final usage = entry.value;

      // Apply pattern-based tags
      if (key.contains('auth') || key.contains('login')) {
        usage.tags.add('critical');
      }
      if (key.contains('button') || key.contains('field')) {
        usage.tags.add('aqa');
      }
      if (key.contains('_test') || key.contains('e2e')) {
        usage.tags.add('e2e');
      }
    }
  }

  ScanResult _mergeBaselines(ScanResult current, ScanResult newScan) {
    // Preserve metadata from current baseline while updating locations
    final merged = ScanResult(
      metrics: newScan.metrics,
      fileAnalyses: newScan.fileAnalyses,
      keyUsages: {},
      blindSpots: newScan.blindSpots,
      duration: newScan.duration,
    );

    // Merge key usages
    for (final entry in newScan.keyUsages.entries) {
      final key = entry.key;
      final newUsage = entry.value;
      final currentUsage = current.keyUsages[key];

      if (currentUsage != null) {
        // Preserve tags and status from current
        newUsage.tags.addAll(currentUsage.tags);
        newUsage.status = currentUsage.status;
        newUsage.notes = currentUsage.notes;
      }

      merged.keyUsages[key] = newUsage;
    }

    return merged;
  }
}
