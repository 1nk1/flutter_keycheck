import 'dart:io';
import '../models/scan_result.dart';
import '../models/validation_result.dart';
import 'reporter_v3.dart';
import 'html_reporter.dart' as html; // Use prefix to avoid naming conflict

/// Adapter for executive/dashboard reporting - delegates to enhanced HTML reporter
/// This provides a consistent interface for premium/executive formats
class ExecutiveDashboardReporterAdapter extends ReporterV3 {
  final bool isPremium;

  ExecutiveDashboardReporterAdapter({this.isPremium = false});

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    // Delegate to HtmlReporter with premium flag for enhanced features
    final reporter = html.HtmlReporter(isPremium: isPremium);
    await reporter.generateScanReport(result, outputFile, includeMetrics: includeMetrics, includeLocations: includeLocations);
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // Delegate to HtmlReporter for validation as well
    final reporter = html.HtmlReporter(isPremium: isPremium);
    await reporter.generateValidationReport(result, outputFile, includeMetrics: includeMetrics);
  }
}
