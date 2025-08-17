import 'dart:io';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:path/path.dart' as path;

/// Report command - generate reports in multiple formats
class ReportCommand extends BaseCommandV3 {
  @override
  final name = 'report';

  @override
  final description = 'Generate reports in various formats';

  ReportCommand() {
    argParser
      ..addMultiOption(
        'format',
        help: 'Report formats to generate',
        allowed: ['json', 'junit', 'md'],
        defaultsTo: ['json'],
      )
      ..addOption(
        'source',
        help: 'Data source (scan, validation, file path)',
        defaultsTo: 'scan',
      )
      ..addFlag(
        'include-metrics',
        help: 'Include detailed metrics in report',
        defaultsTo: true,
      )
      ..addFlag(
        'include-locations',
        help: 'Include file locations for keys',
        defaultsTo: false,
      );
  }

  @override
  Future<int> run() async {
    try {
      logInfo('📊 Generating reports...');

      final config = await loadConfig();
      final outDir = await ensureOutputDir();
      final formats = argResults!['format'] as List<String>;

      // Load or generate data
      final source = argResults!['source'] as String;
      dynamic data;

      if (source == 'scan') {
        // Perform scan
        logInfo('Scanning project...');
        final projectRoot =
            argResults!['project-root'] as String? ?? Directory.current.path;
        final scanner = AstScannerV3(
          projectPath: projectRoot,
          config: config,
        );
        data = await scanner.scan();
      } else if (source == 'validation') {
        // Load latest validation result
        final validationFile =
            File(path.join(outDir.path, 'validation-result.json'));
        if (!await validationFile.exists()) {
          logError('No validation result found. Run "validate" command first.');
          return ExitCode.ioError;
        }
        data = ValidationResult.fromJson(await validationFile.readAsString());
      } else {
        // Load from file
        final file = File(source);
        if (!await file.exists()) {
          logError('Source file not found: $source');
          return ExitCode.ioError;
        }
        // Try to detect data type
        final content = await file.readAsString();
        if (content.contains('"scan_metrics"')) {
          data = ScanResult.fromJson(content);
        } else if (content.contains('"violations"')) {
          data = ValidationResult.fromJson(content);
        } else {
          logError('Unknown data format in file: $source');
          return ExitCode.invalidConfig;
        }
      }

      // Generate reports
      for (final format in formats) {
        final reporter = getReporter(format);
        final reportFile = File(path.join(
          outDir.path,
          'report.${_getExtension(format)}',
        ));

        if (data is ScanResult) {
          await reporter.generateScanReport(
            data,
            reportFile,
            includeMetrics: argResults!['include-metrics'] as bool,
            includeLocations: argResults!['include-locations'] as bool,
          );
        } else if (data is ValidationResult) {
          await reporter.generateValidationReport(
            data,
            reportFile,
            includeMetrics: argResults!['include-metrics'] as bool,
          );
        }

        logInfo(
            '✅ ${format.toUpperCase()} report saved to: ${reportFile.path}');
      }

      return ExitCode.ok;
    } catch (e) {
      return handleError(e);
    }
  }

  String _getExtension(String format) {
    switch (format) {
      case 'json':
        return 'json';
      case 'junit':
        return 'xml';
      case 'md':
        return 'md';
      default:
        return format;
    }
  }
}
