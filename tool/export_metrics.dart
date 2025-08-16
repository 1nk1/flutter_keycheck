#!/usr/bin/env dart

/// Export metrics for GitLab CI metrics collection
/// Used to track scan coverage metrics over time

import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    // Read scan coverage report
    final reportFile = File('reports/scan-coverage.json');
    if (!reportFile.existsSync()) {
      stderr.writeln('Error: scan-coverage.json not found');
      stderr.writeln(
          'Run: flutter_keycheck scan --report json --out-dir reports');
      exit(1);
    }

    final jsonContent = await reportFile.readAsString();
    final report = json.decode(jsonContent) as Map<String, dynamic>;
    final metrics = report['metrics'] as Map<String, dynamic>;

    // Export metrics in GitLab CI format
    final metricsFile = File('metrics.txt');
    final buffer = StringBuffer();

    // Core metrics (fractions, not percentages)
    final parseSuccessRate = metrics['parse_success_rate'] ?? 0.0;
    final widgetCoverage =
        (metrics['widgets_with_keys'] ?? 0) / (metrics['widgets_total'] ?? 1);
    final handlerLinkage =
        (metrics['handlers_linked'] ?? 0) / (metrics['handlers_total'] ?? 1);

    // Write metrics in GitLab format
    buffer.writeln(
        'flutter_keycheck_parse_success_rate{project="${Platform.environment['CI_PROJECT_NAME'] ?? 'local'}"} $parseSuccessRate');
    buffer.writeln(
        'flutter_keycheck_widget_coverage{project="${Platform.environment['CI_PROJECT_NAME'] ?? 'local'}"} $widgetCoverage');
    buffer.writeln(
        'flutter_keycheck_handler_linkage{project="${Platform.environment['CI_PROJECT_NAME'] ?? 'local'}"} $handlerLinkage');
    buffer.writeln(
        'flutter_keycheck_files_scanned{project="${Platform.environment['CI_PROJECT_NAME'] ?? 'local'}"} ${metrics['files_scanned'] ?? 0}');
    buffer.writeln(
        'flutter_keycheck_widgets_with_keys{project="${Platform.environment['CI_PROJECT_NAME'] ?? 'local'}"} ${metrics['widgets_with_keys'] ?? 0}');

    // Detector effectiveness
    if (report['detectors'] != null) {
      final detectors = report['detectors'] as List<dynamic>;
      for (final detector in detectors) {
        final name = detector['name'] as String;
        final effectiveness = detector['effectiveness'] ?? 0.0;
        buffer.writeln(
            'flutter_keycheck_detector_effectiveness{detector="$name"} $effectiveness');
      }
    }

    await metricsFile.writeAsString(buffer.toString());
    print('✅ Metrics exported to metrics.txt');

    // Also output to stdout for CI logs
    print('\n📊 Scan Coverage Metrics:');
    print(
        '  Parse Success Rate: ${(parseSuccessRate * 100).toStringAsFixed(1)}%');
    print('  Widget Coverage: ${(widgetCoverage * 100).toStringAsFixed(1)}%');
    print('  Handler Linkage: ${(handlerLinkage * 100).toStringAsFixed(1)}%');
    print(
        '  Files Scanned: ${metrics['files_scanned']}/${metrics['files_total']}');
    print(
        '  Widgets with Keys: ${metrics['widgets_with_keys']}/${metrics['widgets_total']}');
  } catch (e) {
    stderr.writeln('Error exporting metrics: $e');
    exit(1);
  }
}
