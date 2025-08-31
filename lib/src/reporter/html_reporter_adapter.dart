/// Adapter to use premium HtmlReporter with ReporterV3 interface
///
/// This adapter bridges the gap between the V3 command infrastructure
/// and the premium HTML reporter that uses BaseReporter interface.
library;

import 'dart:io';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart' as v3;
import 'package:flutter_keycheck/src/reporter/base_reporter.dart';

/// Adapter class to use HtmlReporter with ReporterV3 interface
class HtmlReporterAdapter extends v3.ReporterV3 {
  final v3.HtmlReporter _htmlReporter;

  HtmlReporterAdapter({bool darkTheme = false})
      : _htmlReporter = v3.HtmlReporter();

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    // Simply delegate to the HtmlReporter
    await _htmlReporter.generateScanReport(
      result,
      outputFile,
      includeMetrics: includeMetrics,
      includeLocations: includeLocations,
    );
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // Simply delegate to the HtmlReporter
    await _htmlReporter.generateValidationReport(
      result,
      outputFile,
      includeMetrics: includeMetrics,
    );
  }
}
