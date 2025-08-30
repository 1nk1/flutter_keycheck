/// Adapter to use premium HtmlReporter with ReporterV3 interface
///
/// This adapter bridges the gap between the V3 command infrastructure
/// and the premium HTML reporter that uses BaseReporter interface.
library;

import 'dart:io';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';
import 'package:flutter_keycheck/src/reporter/base_reporter.dart';
import 'package:flutter_keycheck/src/reporter/html_reporter.dart';

/// Adapter class to use HtmlReporter with ReporterV3 interface
class HtmlReporterAdapter extends ReporterV3 {
  final HtmlReporter _htmlReporter;

  HtmlReporterAdapter({bool darkTheme = false})
      : _htmlReporter = HtmlReporter(darkTheme: darkTheme);

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    // Convert ScanResult to ReportData for premium reporter
    final reportData = _convertToReportData(result);

    // Generate premium HTML report
    final html = _htmlReporter.generate(reportData);

    // Write to file
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(html);
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // Convert ValidationResult to ReportData
    // Extract keys from ValidationResult structure
    final extraKeyNames = result.extraKeys.map((info) => info.id).toSet();
    final lostKeyNames = result.lostKeys.map((info) => info.id).toSet();

    final reportData = ReportData(
      expectedKeys: <String>{}, // Not available in ValidationResult
      foundKeys: <String>{}, // Not available in ValidationResult
      missingKeys: lostKeyNames,
      extraKeys: extraKeyNames,
      projectPath: Directory.current.path,
      timestamp: result.timestamp,
      scanDuration: Duration(milliseconds: 100), // Not available
      metrics: {
        'passed': result.passed,
        'totalViolations': result.totalViolations,
        'driftPercentage': result.driftPercentage,
      },
    );

    // Generate premium HTML report
    final html = _htmlReporter.generate(reportData);

    // Write to file
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(html);
  }

  /// Convert ScanResult to ReportData for compatibility
  ReportData _convertToReportData(ScanResult result) {
    // Extract found keys from keyUsages map
    final foundKeys = result.keyUsages.keys.toSet();

    // Create key usage counts
    final keyUsageCounts = <String, int>{};
    for (final entry in result.keyUsages.entries) {
      final key = entry.key;
      final usage = entry.value;
      keyUsageCounts[key] = usage.locations.length;
    }

    // Create key locations
    final keyLocations = <String, List<dynamic>>{};
    for (final entry in result.keyUsages.entries) {
      final key = entry.key;
      final usage = entry.value;
      final locations = <dynamic>[];
      for (final location in usage.locations) {
        locations.add({
          'file': location.file,
          'line': location.line,
          'column': location.column,
          'type': location.detector, // Use detector field instead of type
        });
      }
      keyLocations[key] = locations;
    }

    // Extract scanned files
    final scannedFiles = <String>[];
    final fileSet = <String>{};
    for (final fileAnalysis in result.fileAnalyses.values) {
      fileSet.add(fileAnalysis.path);
    }
    scannedFiles.addAll(fileSet);

    // Create metrics
    final metrics = {
      'totalFiles': result.metrics.totalFiles,
      'scannedFiles': result.metrics.scannedFiles,
      'fileCoverage': result.metrics.fileCoverage,
      'widgetCoverage': result.metrics.widgetCoverage,
      'handlerCoverage': result.metrics.handlerCoverage,
      'incrementalScan': result.metrics.incrementalScan,
      'incrementalBase': result.metrics.incrementalBase,
    };

    return ReportData(
      expectedKeys: <String>{}, // Will be filled from expected_keys.yaml if needed
      foundKeys: foundKeys,
      missingKeys: <String>{}, // Will be computed if expected keys provided
      extraKeys: foundKeys, // All found keys are extra if no expected keys
      keyUsageCounts: keyUsageCounts,
      keyLocations: keyLocations,
      scanDuration: Duration(milliseconds: 200), // Approximate scan time
      scannedFiles: scannedFiles,
      metrics: metrics,
      projectPath: Directory.current.path,
      timestamp: DateTime.now(),
    );
  }
}
