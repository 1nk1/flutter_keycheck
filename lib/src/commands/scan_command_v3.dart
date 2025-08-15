import 'dart:io';

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
      ..addMultiOption(
        'packages',
        help: 'Package scanning mode',
        allowed: ['workspace', 'resolve'],
        defaultsTo: ['workspace'],
      )
      ..addOption(
        'report',
        help: 'Report format (json, junit, md)',
        allowed: ['json', 'junit', 'md'],
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
      logInfo('🔍 Scanning for keys...');
      
      final config = await loadConfig();
      final outDir = await ensureOutputDir();
      
      // Configure scanner
      final scanner = AstScannerV3(
        projectPath: Directory.current.path,
        includeTests: argResults!['include-tests'] as bool,
        includeGenerated: argResults!['include-generated'] as bool,
        gitDiffBase: argResults!['since'] as String?,
        packageMode: (argResults!['packages'] as List<String>).first,
        packageFilter: argResults!['filter'] as String?,
        config: config,
      );

      // Perform scan
      final result = await scanner.scan();
      
      // Log results
      logInfo('✅ Scan complete:');
      logInfo('  • Files scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}');
      logInfo('  • Keys found: ${result.keyUsages.length}');
      logInfo('  • Coverage: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');
      
      if (result.metrics.incrementalScan) {
        logInfo('  • Incremental scan since: ${result.metrics.incrementalBase}');
      }

      // Generate report
      final format = argResults!['report'] as String;
      final reporter = getReporter(format);
      final reportFile = File(path.join(outDir.path, 'key-snapshot.$format'));
      
      await reporter.generateScanReport(result, reportFile);
      logInfo('📊 Report saved to: ${reportFile.path}');

      // Log warnings if any
      if (result.blindSpots.isNotEmpty) {
        logWarning('Found ${result.blindSpots.length} blind spots:');
        for (final spot in result.blindSpots) {
          logVerbose('  • ${spot.message}');
        }
      }

      // Save snapshot for baseline/diff commands
      final snapshotFile = File(path.join(outDir.path, 'key-snapshot.json'));
      await _saveSnapshot(result, snapshotFile);
      logVerbose('Snapshot saved to: ${snapshotFile.path}');

      return ExitCode.ok;
    } catch (e) {
      return handleError(e);
    }
  }

  Future<void> _saveSnapshot(ScanResult result, File file) async {
    final snapshot = ScanSnapshot(
      timestamp: DateTime.now(),
      projectPath: Directory.current.path,
      scanResult: result,
    );
    
    await file.writeAsString(snapshot.toJson());
  }
}