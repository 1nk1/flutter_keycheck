import 'dart:io';

import 'package:flutter_keycheck/src/commands/base_command.dart';
import 'package:flutter_keycheck/src/scanner/workspace_scanner.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/models/key_snapshot.dart';

/// Scan command to build a current snapshot of keys
class ScanCommand extends BaseCommand {
  @override
  final String name = 'scan';

  @override
  final String description =
      'Build a current snapshot of keys across the workspace';

  ScanCommand() {
    argParser
      ..addOption(
        'scope',
        help: 'Scope of packages to scan',
        allowed: ['workspace-only', 'deps-only', 'all'],
        defaultsTo: 'workspace-only',
      )
      ..addOption(
        'since',
        help: 'Git ref for incremental scan (optional speedup)',
      )
      ..addOption(
        'report',
        help: 'Output format',
        allowed: ['json', 'junit', 'md', 'text', 'html'],
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
      
      // Use project-root if specified, otherwise current directory
      String projectRoot;
      if (argResults!.wasParsed('project-root')) {
        final specifiedRoot = argResults!['project-root'] as String;
        // Convert to absolute path
        projectRoot = Directory(specifiedRoot).absolute.path;
      } else {
        projectRoot = Directory.current.path;
      }
      
      final scanner = AstScannerV3(
        projectPath: projectRoot,
        includeTests: argResults!['include-tests'] as bool,
        includeGenerated: argResults!['include-generated'] as bool,
        gitDiffBase: argResults!.wasParsed('since')
            ? argResults!['since'] as String
            : null,
        config: config,
      );

      if (config.verbose) {
        stdout.writeln('🔍 Scanning workspace...');
        stdout.writeln('  Packages mode: ${config.packages.join(', ')}');
        if (scanner.gitDiffBase != null) {
          stdout.writeln('  Incremental since: ${scanner.gitDiffBase}');
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

      stdout
          .writeln('✅ Scan complete. Found ${snapshot.keyUsages.length} keys');
      stdout.writeln('📄 Reports saved to $outDir/');

      return BaseCommand.exitOk;
    } catch (e) {
      return handleError(e);
    }
  }
}
