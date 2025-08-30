import 'dart:io';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';
import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';

/// Adapter to bridge PremiumDashboardReporter with ReporterV3 interface
class PremiumDashboardAdapter extends ReporterV3 {
  final PremiumDashboardReporter _reporter = PremiumDashboardReporter();

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final content = _reporter.generateReport(result);
    await outputFile.writeAsString(content);
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // For now, validation reports are not supported by premium dashboard
    throw UnimplementedError(
        'Premium dashboard does not support validation reports yet');
  }
}
