import 'dart:io';

import 'package:flutter_keycheck/src/commands/base_command.dart';
import 'package:flutter_keycheck/src/scanner/workspace_scanner.dart';
import 'package:flutter_keycheck/src/models/key_snapshot.dart';

/// Scan command to build a current snapshot of keys
class ScanCommand extends BaseCommand {
  @override
  final String name = 'scan';

  @override
  final String description = 'Build a current snapshot of keys across the workspace';

  ScanCommand() {
    argParser
      ..addOption(
        'since',
        help: 'Git ref for incremental scan (optional speedup)',
      )
      ..addOption(
        'report',
        help: 'Output format',
        allowed: ['json', 'junit', 'md', 'text'],
        defaultsTo: 'text',
      )
      ..addOption(
        'out-dir',
        help: 'Output directory for reports',
        defaultsTo: './reports',
      )
      ..addFlag(
        'include-tests',
        help: 'Include test files in scan',
        defaultsTo: false,
      )
      ..addFlag(
        'include-generated',
        help: 'Include generated code in scan',
        defaultsTo: false,
      );
  }

  @override
  Future<int> run() async {
    try {
      final config = await loadConfig();
      final scanner = WorkspaceScanner(config);
      
      // Configure scanner options
      scanner.includeTests = argResults!['include-tests'] as bool;
      scanner.includeGenerated = argResults!['include-generated'] as bool;
      
      // Perform incremental scan if requested
      if (argResults!.wasParsed('since')) {
        scanner.since = argResults!['since'] as String;
      }
      
      if (config.verbose) {
        stdout.writeln('🔍 Scanning workspace...');
        stdout.writeln('  Packages mode: ${config.packages.join(', ')}');
        if (scanner.since != null) {
          stdout.writeln('  Incremental since: ${scanner.since}');
        }
      }
      
      // Perform the scan
      final snapshot = await scanner.scan();
      
      // Generate report
      final reporter = getReporter(config, argResults!['report'] as String);
      final outDir = argResults!['out-dir'] as String;
      
      // Ensure output directory exists
      final dir = Directory(outDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Save snapshot
      final snapshotFile = File('$outDir/key-snapshot.json');
      await snapshotFile.writeAsString(snapshot.toJson());
      
      // Generate report
      final report = reporter.generateScanReport(snapshot);
      final reportFile = File('$outDir/scan-report.${reporter.extension}');
      await reportFile.writeAsString(report);
      
      // Print summary to stdout
      if (config.verbose || reporter.format == 'text') {
        stdout.writeln(reporter.generateSummary(snapshot));
      }
      
      stdout.writeln('✅ Scan complete. Found ${snapshot.totalKeys} keys across ${snapshot.packages.length} packages');
      stdout.writeln('📄 Reports saved to $outDir/');
      
      return BaseCommand.exitOk;
    } catch (e) {
      return handleError(e);
    }
  }
}