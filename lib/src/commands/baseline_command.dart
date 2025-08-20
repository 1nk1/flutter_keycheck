import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:path/path.dart' as path;

/// Baseline command - create/update baseline
class BaselineCommand extends BaseCommandV3 {
  @override
  final name = 'baseline';

  @override
  final description = 'Create or update key baseline';

  BaselineCommand() {
    // Add subcommands with their own options
    final createCommand = ArgParser()
      ..addOption(
        'scan',
        help: 'Path to scan snapshot file',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file path for baseline',
        defaultsTo: 'baseline.json',
      )
      ..addFlag(
        'auto-tags',
        help: 'Automatically assign tags based on patterns',
        defaultsTo: false,
      )
      ..addFlag(
        'include-deps',
        help: 'Include keys from dependencies in baseline',
        defaultsTo: true,
      )
      ..addFlag(
        'exclude-deps',
        help: 'Exclude keys from dependencies in baseline',
        defaultsTo: false,
      );

    final updateCommand = ArgParser()
      ..addOption(
        'scan',
        help: 'Path to scan snapshot file',
      )
      ..addFlag(
        'auto-tags',
        help: 'Automatically assign tags based on patterns',
        defaultsTo: false,
      );

    argParser
      ..addCommand('create', createCommand)
      ..addCommand('update', updateCommand);
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
      final projectRoot =
          argResults!['project-root'] as String? ?? Directory.current.path;
      final scanner = AstScannerV3(
        projectPath: projectRoot,
        config: config,
      );
      scanResult = await scanner.scan();
    }

    // Apply auto-tags if requested
    if (argResults!.command!['auto-tags'] as bool) {
      _applyAutoTags(scanResult, config);
    }

    // Generate enhanced baseline structure
    final excludeDeps = argResults!.command!['exclude-deps'] as bool? ?? false;
    final baselineData = _generateBaselineJson(
      scanResult,
      projectRoot:
          argResults!['project-root'] as String? ?? Directory.current.path,
      includeDeps: !excludeDeps,
    );

    // Save baseline to registry
    final registry = await getRegistry(config);
    await registry.saveBaseline(scanResult);

    logInfo('✅ Baseline created with ${scanResult.keyUsages.length} keys');

    // Save enhanced baseline format
    final outputPath =
        argResults!.command!['output'] as String? ?? 'baseline.json';
    final baselineFile = File(path.isAbsolute(outputPath)
        ? outputPath
        : path.join(outDir.path, outputPath));

    // Ensure directory exists
    await baselineFile.parent.create(recursive: true);

    // Write formatted JSON
    final encoder = const JsonEncoder.withIndent('  ');
    await baselineFile.writeAsString(encoder.convert(baselineData));
    logInfo('📄 Baseline saved to: ${baselineFile.path}');

    // Log statistics
    final workspaceKeys = scanResult.keyUsages.values
        .where((u) => u.source == 'workspace')
        .length;
    final packageKeys =
        scanResult.keyUsages.values.where((u) => u.source == 'package').length;

    logInfo('  • Workspace keys: $workspaceKeys');
    if (packageKeys > 0) {
      logInfo('  • Package keys: $packageKeys');
    }

    // Count dependencies scanned
    final uniquePackages = <String>{};
    for (final usage in scanResult.keyUsages.values) {
      if (usage.package != null) {
        uniquePackages.add(usage.package!.split('@').first);
      }
    }
    if (uniquePackages.isNotEmpty) {
      logInfo('  • Dependencies scanned: ${uniquePackages.length}');
    }

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
    final projectRoot =
        argResults!['project-root'] as String? ?? Directory.current.path;
    final scanner = AstScannerV3(
      projectPath: projectRoot,
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

  Map<String, dynamic> _generateBaselineJson(
    ScanResult scanResult, {
    required String projectRoot,
    bool includeDeps = true,
  }) {
    // Count dependencies scanned
    final uniquePackages = <String>{};
    for (final usage in scanResult.keyUsages.values) {
      if (usage.package != null) {
        uniquePackages.add(usage.package!.split('@').first);
      }
    }

    // Build keys array
    final keys = <Map<String, dynamic>>[];
    for (final entry in scanResult.keyUsages.entries) {
      final keyId = entry.key;
      final usage = entry.value;

      // Skip dependency keys if exclude-deps is set
      if (!includeDeps && usage.source == 'package') {
        continue;
      }

      for (final location in usage.locations) {
        keys.add({
          'key': keyId,
          'type': _extractKeyType(location.context),
          'file': location.file,
          'line': location.line,
          'package': usage.package ?? 'my_app',
          'dependency_level':
              usage.source == 'package' ? 'transitive' : 'direct',
          if (usage.tags.isNotEmpty) 'tags': usage.tags.toList(),
          if (usage.status != 'active') 'status': usage.status,
        });
      }
    }

    return {
      'metadata': {
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'project_root': projectRoot,
        'total_keys': keys.length,
        'dependencies_scanned': uniquePackages.length,
        'schema_version': '2.0',
        'flutter_keycheck_version': '3.0.0',
      },
      'keys': keys,
    };
  }

  String _extractKeyType(String context) {
    // Extract key type from context (e.g., "Key('...')" -> "Key", "ValueKey('...')" -> "ValueKey")
    if (context.contains('ValueKey')) return 'ValueKey';
    if (context.contains('ObjectKey')) return 'ObjectKey';
    if (context.contains('UniqueKey')) return 'UniqueKey';
    if (context.contains('GlobalKey')) return 'GlobalKey';
    return 'Key';
  }
}
