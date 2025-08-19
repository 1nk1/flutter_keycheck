import 'dart:io';
import 'dart:convert';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:path/path.dart' as path;

/// Scan command - builds current snapshot of keys
class ScanCommandV3 extends BaseCommandV3 {
  @override
  final name = 'scan';

  @override
  final description = 'Build current snapshot of keys in the project';

  ScanCommandV3() {
    argParser
      ..addOption(
        'scope',
        help: 'Package scanning scope',
        allowed: ['workspace-only', 'deps-only', 'all'],
        defaultsTo: 'workspace-only',
      )
      ..addOption(
        'report',
        help: 'Report format (json, junit, md, html, text, ci, gitlab)',
        allowed: ['json', 'junit', 'md', 'html', 'text', 'ci', 'gitlab'],
        defaultsTo: 'json',
      )
      ..addFlag(
        'include-tests',
        help: 'Include test files in scan',
        defaultsTo: false,
      )
      ..addFlag(
        'include-generated',
        help: 'Include generated files (.g.dart, .freezed.dart)',
        defaultsTo: false,
      )
      ..addFlag(
        'include-examples',
        help: 'Scan example/* packages as part of workspace',
        defaultsTo: true,
      )
      ..addOption(
        'since',
        help: 'Incremental scan since git commit/branch',
      )
      ..addOption(
        'filter',
        help: 'Filter packages by pattern (for monorepo)',
      );
  }

  @override
  Future<int> run() async {
    try {
      final format = argResults!['report'] as String;
      final isJsonOutput = format == 'json';

      if (!isJsonOutput) {
        logInfo('🔍 Scanning for keys...');
      }

      final config = await loadConfig();
      final outDir = await ensureOutputDir();

      // Configure scanner with absolute path
      String projectRoot;
      final specifiedRoot = argResults!['project-root'] as String?;
      if (specifiedRoot != null) {
        // Convert to absolute path and normalize
        final dir = Directory(specifiedRoot).absolute;
        projectRoot = path.normalize(dir.path);
      } else {
        projectRoot = Directory.current.path;
      }
      
      final scanner = AstScannerV3(
        projectPath: projectRoot,
        includeTests: argResults!['include-tests'] as bool,
        includeGenerated: argResults!['include-generated'] as bool,
        includeExamples: argResults!['include-examples'] as bool,
        gitDiffBase: argResults!['since'] as String?,
        scope: ScanScope.fromString(argResults!['scope'] as String),
        packageFilter: argResults!['filter'] as String?,
        config: config,
      );

      // Perform scan
      logVerbose('Starting scan with scope: ${argResults!['scope']}');
      logVerbose('Project root: $projectRoot');
      final result = await scanner.scan();

      // For JSON output, write directly to stdout
      if (isJsonOutput) {
        logVerbose('Scan completed with ${result.keyUsages.length} keys found');
        final out = <String, dynamic>{
          'schemaVersion': '1.0',
          'summary': {
            'total_files': result.metrics.totalFiles,
            'scanned_files': result.metrics.scannedFiles,
            'total_keys': result.keyUsages.length,
            'file_coverage': result.metrics.fileCoverage,
            'widget_coverage': result.metrics.widgetCoverage,
            'handler_coverage': result.metrics.handlerCoverage,
          },
          ...result.toMap(),
        };
        stdout.writeln(jsonEncode(out));
      } else {
        // Log results for non-JSON formats
        logInfo('✅ Scan complete:');
        logInfo(
            '  • Files scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}');
        logInfo('  • Keys found: ${result.keyUsages.length}');
        logInfo(
            '  • Coverage: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');

        if (result.metrics.incrementalScan) {
          logInfo(
              '  • Incremental scan since: ${result.metrics.incrementalBase}');
        }

        // Log warnings if any
        if (result.blindSpots.isNotEmpty) {
          logWarning('Found ${result.blindSpots.length} blind spots:');
          for (final spot in result.blindSpots) {
            logVerbose('  • ${spot.message}');
          }
        }
      }

      // Generate report file
      final reporter = getReporter(format);
      final reportFile = File(path.join(outDir.path, 'key-snapshot.$format'));
      await reporter.generateScanReport(result, reportFile);

      if (!isJsonOutput) {
        logInfo('📊 Report saved to: ${reportFile.path}');
      }

      // Save snapshot for baseline/diff commands
      final snapshotFile = File(path.join(outDir.path, 'key-snapshot.json'));
      await _saveSnapshot(result, snapshotFile, projectRoot);

      if (!isJsonOutput) {
        logVerbose('Snapshot saved to: ${snapshotFile.path}');
      }

      return ExitCode.ok;
    } catch (e) {
      return handleError(e);
    }
  }

  Future<void> _saveSnapshot(
      ScanResult result, File file, String projectPath) async {
    final snapshot = ScanSnapshot(
      timestamp: DateTime.now(),
      projectPath: projectPath,
      scanResult: result,
    );

    await file.writeAsString(snapshot.toJson());
  }
}
