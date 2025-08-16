import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter_keycheck/src/models/scan_result.dart';

/// Coverage reporter with full metrics and evidence
class CoverageReporter {
  final ScanResult scanResult;
  final String projectPath;
  final Map<String, dynamic> thresholds;

  CoverageReporter({
    required this.scanResult,
    required this.projectPath,
    this.thresholds = const {},
  });

  /// Generate comprehensive coverage report
  String generateReport({
    required String format,
    bool includeDetails = true,
    bool includeEvidence = true,
  }) {
    switch (format) {
      case 'json':
        return _generateJsonReport(includeDetails, includeEvidence);
      case 'html':
        return _generateHtmlReport(includeDetails, includeEvidence);
      case 'markdown':
        return _generateMarkdownReport(includeDetails, includeEvidence);
      case 'junit':
        return _generateJUnitReport();
      case 'lcov':
        return _generateLcovReport();
      default:
        return _generateTextReport(includeDetails, includeEvidence);
    }
  }

  /// Generate JSON report with full metrics
  String _generateJsonReport(bool includeDetails, bool includeEvidence) {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'project_path': projectPath,
      'scan_duration_ms': scanResult.duration.inMilliseconds,
      'incremental': scanResult.metrics.incrementalScan,

      // Coverage metrics
      'coverage': {
        'files': {
          'total': scanResult.metrics.totalFiles,
          'scanned': scanResult.metrics.scannedFiles,
          'percentage': scanResult.metrics.fileCoverage,
        },
        'widgets': {
          'total': _getTotalWidgets(),
          'with_keys': _getWidgetsWithKeys(),
          'percentage': scanResult.metrics.widgetCoverage,
        },
        'handlers': {
          'total': _getTotalHandlers(),
          'linked': _getLinkedHandlers(),
          'percentage': scanResult.metrics.handlerCoverage,
        },
        'lines': {
          'total': scanResult.metrics.totalLines,
          'covered': _getCoveredLines(),
          'percentage': _getLineCoverage(),
        },
        'nodes': {
          'total': scanResult.metrics.analyzedNodes,
          'with_keys': _getNodesWithKeys(),
        },
      },

      // Detector metrics
      'detectors': _getDetectorMetrics(),

      // Key statistics
      'keys': {
        'total': scanResult.keyUsages.length,
        'by_detector': _getKeysByDetector(),
        'by_file': _getKeysByFile(),
        'orphaned': _getOrphanedKeys(),
        'duplicates': _getDuplicateKeys(),
      },

      // Blind spots
      'blind_spots': scanResult.blindSpots
          .map((bs) => {
                'type': bs.type,
                'location': bs.location,
                'severity': bs.severity,
                'message': bs.message,
              })
          .toList(),

      // Errors
      'errors': scanResult.metrics.errors
          .map((e) => {
                'file': e.file,
                'type': e.type,
                'error': e.error,
              })
          .toList(),
    };

    // Add file details if requested
    if (includeDetails) {
      report['files'] = _getFileDetails(includeEvidence);
    }

    // Add evidence if requested
    if (includeEvidence) {
      report['evidence'] = _getEvidence();
    }

    // Add threshold violations
    report['threshold_violations'] = _checkThresholds();

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  /// Generate HTML report with visualizations
  String _generateHtmlReport(bool includeDetails, bool includeEvidence) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html>
<head>
  <title>Flutter KeyCheck Coverage Report</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; }
    h1 { color: #0175C2; }
    h2 { color: #333; border-bottom: 2px solid #0175C2; padding-bottom: 5px; }
    .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
    .metric-card { background: #f5f5f5; padding: 15px; border-radius: 8px; }
    .metric-value { font-size: 36px; font-weight: bold; color: #0175C2; }
    .metric-label { color: #666; margin-top: 5px; }
    .progress { background: #ddd; height: 20px; border-radius: 10px; overflow: hidden; }
    .progress-bar { background: #0175C2; height: 100%; transition: width 0.3s; }
    .good { color: #4CAF50; }
    .warning { color: #FF9800; }
    .error { color: #F44336; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
    th { background: #f5f5f5; }
    .file-link { color: #0175C2; text-decoration: none; }
    .file-link:hover { text-decoration: underline; }
    .blind-spot { background: #FFF3E0; padding: 10px; margin: 10px 0; border-left: 4px solid #FF9800; }
    .evidence { background: #f9f9f9; padding: 10px; margin: 5px 0; font-family: monospace; }
  </style>
</head>
<body>
  <h1>🔍 Flutter KeyCheck Coverage Report</h1>
  <p>Generated: ${DateTime.now().toLocal()}</p>
  <p>Project: ${path.basename(projectPath)}</p>
  <p>Scan Duration: ${scanResult.duration.inMilliseconds}ms</p>
''');

    // Coverage metrics cards
    buffer.writeln('<h2>Coverage Metrics</h2>');
    buffer.writeln('<div class="metrics">');

    _addMetricCard(
        buffer, 'File Coverage', scanResult.metrics.fileCoverage, '%');
    _addMetricCard(
        buffer, 'Widget Coverage', scanResult.metrics.widgetCoverage, '%');
    _addMetricCard(
        buffer, 'Handler Coverage', scanResult.metrics.handlerCoverage, '%');
    _addMetricCard(
        buffer, 'Total Keys', scanResult.keyUsages.length.toDouble(), '');

    buffer.writeln('</div>');

    // Detector performance
    buffer.writeln('<h2>Detector Performance</h2>');
    buffer.writeln('<table>');
    buffer.writeln(
        '<tr><th>Detector</th><th>Hits</th><th>Keys Found</th><th>Effectiveness</th></tr>');

    for (final entry in scanResult.metrics.detectorHits.entries) {
      final effectiveness = _getDetectorEffectiveness(entry.key);
      final cssClass = effectiveness > 75
          ? 'good'
          : effectiveness > 25
              ? 'warning'
              : 'error';
      buffer.writeln('''
        <tr>
          <td>${entry.key}</td>
          <td>${entry.value}</td>
          <td>${_getDetectorKeyCount(entry.key)}</td>
          <td class="$cssClass">${effectiveness.toStringAsFixed(1)}%</td>
        </tr>
      ''');
    }
    buffer.writeln('</table>');

    // File details
    if (includeDetails) {
      buffer.writeln('<h2>File Analysis</h2>');
      buffer.writeln('<table>');
      buffer.writeln(
          '<tr><th>File</th><th>Keys</th><th>Widgets</th><th>Coverage</th><th>Actions</th></tr>');

      for (final entry in scanResult.fileAnalyses.entries) {
        final analysis = entry.value;
        final coverage = analysis.widgetCount > 0
            ? (analysis.widgetsWithKeys / analysis.widgetCount * 100)
            : 100.0;

        buffer.writeln('''
          <tr>
            <td><a href="file://${entry.key}" class="file-link">${analysis.relativePath}</a></td>
            <td>${analysis.keysFound.length}</td>
            <td>${analysis.widgetCount}</td>
            <td>${coverage.toStringAsFixed(1)}%</td>
            <td><a href="#file-${analysis.relativePath.hashCode}">Details</a></td>
          </tr>
        ''');
      }
      buffer.writeln('</table>');
    }

    // Blind spots
    if (scanResult.blindSpots.isNotEmpty) {
      buffer.writeln('<h2>⚠️ Blind Spots Detected</h2>');
      for (final blindSpot in scanResult.blindSpots) {
        buffer.writeln('''
          <div class="blind-spot">
            <strong>${blindSpot.type}</strong> at ${blindSpot.location}<br>
            ${blindSpot.message}
          </div>
        ''');
      }
    }

    // Evidence
    if (includeEvidence) {
      buffer.writeln('<h2>Evidence</h2>');
      buffer.writeln('<details>');
      buffer.writeln('<summary>Click to expand evidence details</summary>');

      for (final entry in scanResult.keyUsages.entries.take(20)) {
        buffer.writeln('<h3>Key: ${entry.key}</h3>');
        buffer.writeln('<div class="evidence">');

        for (final location in entry.value.locations) {
          buffer.writeln('''
            File: ${location.file}:${location.line}:${location.column}<br>
            Detector: ${location.detector}<br>
            Context: ${location.context}<br>
          ''');
        }

        if (entry.value.handlers.isNotEmpty) {
          buffer.writeln('<br><strong>Handlers:</strong><br>');
          for (final handler in entry.value.handlers) {
            buffer.writeln(
                '${handler.type}: ${handler.method ?? "anonymous"}<br>');
          }
        }

        buffer.writeln('</div>');
      }

      buffer.writeln('</details>');
    }

    buffer.writeln('</body></html>');

    return buffer.toString();
  }

  /// Generate Markdown report
  String _generateMarkdownReport(bool includeDetails, bool includeEvidence) {
    final buffer = StringBuffer();

    buffer.writeln('# 🔍 Flutter KeyCheck Coverage Report\n');
    buffer.writeln('**Generated:** ${DateTime.now().toLocal()}');
    buffer.writeln('**Project:** `${path.basename(projectPath)}`');
    buffer.writeln('**Duration:** ${scanResult.duration.inMilliseconds}ms\n');

    // Summary table
    buffer.writeln('## 📊 Coverage Summary\n');
    buffer.writeln('| Metric | Total | Covered | Coverage |');
    buffer.writeln('|--------|-------|---------|----------|');
    buffer.writeln(
        '| Files | ${scanResult.metrics.totalFiles} | ${scanResult.metrics.scannedFiles} | ${scanResult.metrics.fileCoverage.toStringAsFixed(1)}% |');
    buffer.writeln(
        '| Widgets | ${_getTotalWidgets()} | ${_getWidgetsWithKeys()} | ${scanResult.metrics.widgetCoverage.toStringAsFixed(1)}% |');
    buffer.writeln(
        '| Handlers | ${_getTotalHandlers()} | ${_getLinkedHandlers()} | ${scanResult.metrics.handlerCoverage.toStringAsFixed(1)}% |');
    buffer.writeln('| Keys Found | ${scanResult.keyUsages.length} | - | - |\n');

    // Detector metrics
    buffer.writeln('## 🎯 Detector Performance\n');
    buffer.writeln('| Detector | Hits | Keys | Effectiveness |');
    buffer.writeln('|----------|------|------|---------------|');

    for (final entry in scanResult.metrics.detectorHits.entries) {
      final effectiveness = _getDetectorEffectiveness(entry.key);
      final indicator = effectiveness > 75
          ? '✅'
          : effectiveness > 25
              ? '⚠️'
              : '❌';
      buffer.writeln(
          '| ${entry.key} | ${entry.value} | ${_getDetectorKeyCount(entry.key)} | $indicator ${effectiveness.toStringAsFixed(1)}% |');
    }

    // Top files by keys
    if (includeDetails) {
      buffer.writeln('\n## 📁 Top Files by Key Count\n');

      final sortedFiles = scanResult.fileAnalyses.entries.toList()
        ..sort((a, b) =>
            b.value.keysFound.length.compareTo(a.value.keysFound.length));

      buffer.writeln('| File | Keys | Widgets | Coverage |');
      buffer.writeln('|------|------|---------|----------|');

      for (final entry in sortedFiles.take(10)) {
        final analysis = entry.value;
        final coverage = analysis.widgetCount > 0
            ? (analysis.widgetsWithKeys / analysis.widgetCount * 100)
            : 100.0;

        buffer.writeln(
            '| `${analysis.relativePath}` | ${analysis.keysFound.length} | ${analysis.widgetCount} | ${coverage.toStringAsFixed(1)}% |');
      }
    }

    // Blind spots
    if (scanResult.blindSpots.isNotEmpty) {
      buffer.writeln('\n## ⚠️ Blind Spots\n');

      for (final blindSpot in scanResult.blindSpots) {
        final icon = blindSpot.severity == 'error'
            ? '🔴'
            : blindSpot.severity == 'warning'
                ? '🟡'
                : 'ℹ️';
        buffer
            .writeln('$icon **${blindSpot.type}** at `${blindSpot.location}`');
        buffer.writeln('   ${blindSpot.message}\n');
      }
    }

    // Key-Handler links
    if (includeEvidence) {
      buffer.writeln('\n## 🔗 Key-Handler Links\n');

      final linkedKeys = scanResult.keyUsages.entries
          .where((e) => e.value.handlers.isNotEmpty)
          .take(10);

      for (final entry in linkedKeys) {
        buffer.writeln('### Key: `${entry.key}`\n');
        buffer.writeln('**Locations:**');
        for (final loc in entry.value.locations.take(3)) {
          buffer.writeln(
              '- `${path.relative(loc.file, from: projectPath)}:${loc.line}` (${loc.detector})');
        }

        buffer.writeln('\n**Handlers:**');
        for (final handler in entry.value.handlers) {
          buffer
              .writeln('- ${handler.type}: `${handler.method ?? "anonymous"}`');
        }
        buffer.writeln('');
      }
    }

    // Threshold violations
    final violations = _checkThresholds();
    if (violations.isNotEmpty) {
      buffer.writeln('\n## ❌ Threshold Violations\n');

      for (final violation in violations) {
        buffer.writeln(
            '- **${violation['metric']}**: ${violation['actual']}% (threshold: ${violation['threshold']}%)');
      }
    }

    return buffer.toString();
  }

  /// Generate JUnit XML report
  String _generateJUnitReport() {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');

    final totalTests = 4; // Coverage tests
    final failures = _checkThresholds().length;

    buffer.writeln(
        '<testsuites name="Flutter KeyCheck Coverage" tests="$totalTests" failures="$failures">');
    buffer.writeln(
        '  <testsuite name="Coverage" tests="$totalTests" failures="$failures">');

    // File coverage test
    _addJUnitTest(buffer, 'File Coverage', scanResult.metrics.fileCoverage,
        thresholds['file_coverage'] as double? ?? 80.0);

    // Widget coverage test
    _addJUnitTest(buffer, 'Widget Coverage', scanResult.metrics.widgetCoverage,
        thresholds['widget_coverage'] as double? ?? 70.0);

    // Handler coverage test
    _addJUnitTest(
        buffer,
        'Handler Coverage',
        scanResult.metrics.handlerCoverage,
        thresholds['handler_coverage'] as double? ?? 60.0);

    // Blind spots test
    final hasBlindSpots =
        scanResult.blindSpots.any((bs) => bs.severity == 'error');

    buffer.writeln(
        '    <testcase name="No Critical Blind Spots" classname="Coverage">');
    if (hasBlindSpots) {
      buffer.writeln('      <failure message="Critical blind spots detected">');
      for (final bs
          in scanResult.blindSpots.where((b) => b.severity == 'error')) {
        buffer.writeln('        ${bs.type}: ${bs.message}');
      }
      buffer.writeln('      </failure>');
    }
    buffer.writeln('    </testcase>');

    buffer.writeln('  </testsuite>');
    buffer.writeln('</testsuites>');

    return buffer.toString();
  }

  /// Generate LCOV report for code coverage tools
  String _generateLcovReport() {
    final buffer = StringBuffer();

    for (final entry in scanResult.fileAnalyses.entries) {
      final analysis = entry.value;

      buffer.writeln('SF:${analysis.relativePath}');

      // Function coverage (methods/functions found)
      buffer.writeln(
          'FNF:${analysis.functions.length + analysis.methods.length}');
      buffer.writeln(
          'FNH:${analysis.keysFound.length}'); // Keys as "hit" functions

      // Line coverage (approximate based on widgets)
      buffer.writeln('LF:${analysis.widgetCount}');
      buffer.writeln('LH:${analysis.widgetsWithKeys}');

      // Branch coverage (handlers)
      final handlers = _getFileHandlers(entry.key);
      buffer.writeln('BRF:$handlers');
      buffer.writeln('BRH:$handlers');

      buffer.writeln('end_of_record');
    }

    return buffer.toString();
  }

  /// Generate text report
  String _generateTextReport(bool includeDetails, bool includeEvidence) {
    final buffer = StringBuffer();

    buffer.writeln(
        '═══════════════════════════════════════════════════════════════');
    buffer.writeln(
        '                 FLUTTER KEYCHECK COVERAGE REPORT              ');
    buffer.writeln(
        '═══════════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Project: ${path.basename(projectPath)}');
    buffer.writeln('Time: ${DateTime.now().toLocal()}');
    buffer.writeln('Duration: ${scanResult.duration.inMilliseconds}ms');

    if (scanResult.metrics.incrementalScan) {
      buffer.writeln(
          'Mode: Incremental (base: ${scanResult.metrics.incrementalBase})');
    } else {
      buffer.writeln('Mode: Full scan');
    }

    buffer.writeln('');
    buffer.writeln('COVERAGE METRICS');
    buffer.writeln('────────────────');
    _addTextMetric(buffer, 'File Coverage', scanResult.metrics.scannedFiles,
        scanResult.metrics.totalFiles, scanResult.metrics.fileCoverage);
    _addTextMetric(buffer, 'Widget Coverage', _getWidgetsWithKeys(),
        _getTotalWidgets(), scanResult.metrics.widgetCoverage);
    _addTextMetric(buffer, 'Handler Coverage', _getLinkedHandlers(),
        _getTotalHandlers(), scanResult.metrics.handlerCoverage);

    buffer.writeln('');
    buffer.writeln('KEY STATISTICS');
    buffer.writeln('──────────────');
    buffer.writeln('Total Keys Found: ${scanResult.keyUsages.length}');
    buffer.writeln('Orphaned Keys: ${_getOrphanedKeys().length}');
    buffer.writeln('Duplicate Keys: ${_getDuplicateKeys().length}');

    buffer.writeln('');
    buffer.writeln('DETECTOR PERFORMANCE');
    buffer.writeln('────────────────────');

    for (final entry in scanResult.metrics.detectorHits.entries) {
      final effectiveness = _getDetectorEffectiveness(entry.key);
      final status = effectiveness > 75
          ? '✓'
          : effectiveness > 25
              ? '!'
              : '✗';
      buffer.writeln(
          '[$status] ${entry.key.padRight(20)} ${entry.value.toString().padLeft(6)} hits  ${effectiveness.toStringAsFixed(1).padLeft(5)}% effective');
    }

    if (scanResult.blindSpots.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('BLIND SPOTS DETECTED');
      buffer.writeln('────────────────────');

      for (final blindSpot in scanResult.blindSpots) {
        final icon = blindSpot.severity == 'error'
            ? '[ERROR]'
            : blindSpot.severity == 'warning'
                ? '[WARN] '
                : '[INFO] ';
        buffer.writeln('$icon ${blindSpot.type}');
        buffer.writeln('      ${blindSpot.message}');
        buffer.writeln('      Location: ${blindSpot.location}');
      }
    }

    final violations = _checkThresholds();
    if (violations.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('THRESHOLD VIOLATIONS');
      buffer.writeln('────────────────────');

      for (final violation in violations) {
        buffer.writeln(
            '[FAIL] ${violation['metric']}: ${violation['actual']}% < ${violation['threshold']}%');
      }
    }

    if (includeDetails) {
      buffer.writeln('');
      buffer.writeln('FILE DETAILS');
      buffer.writeln('────────────');

      final sortedFiles = scanResult.fileAnalyses.entries.toList()
        ..sort((a, b) =>
            b.value.keysFound.length.compareTo(a.value.keysFound.length));

      for (final entry in sortedFiles.take(10)) {
        final analysis = entry.value;
        buffer.writeln('');
        buffer.writeln('📁 ${analysis.relativePath}');
        buffer.writeln('   Keys: ${analysis.keysFound.length}');
        buffer.writeln(
            '   Widgets: ${analysis.widgetCount} (${analysis.widgetsWithKeys} with keys)');
        buffer.writeln('   Nodes analyzed: ${analysis.nodesAnalyzed}');
      }
    }

    buffer.writeln('');
    buffer.writeln(
        '═══════════════════════════════════════════════════════════════');

    return buffer.toString();
  }

  // Helper methods

  int _getTotalWidgets() {
    return scanResult.fileAnalyses.values
        .fold(0, (sum, analysis) => sum + analysis.widgetCount);
  }

  int _getWidgetsWithKeys() {
    return scanResult.fileAnalyses.values
        .fold(0, (sum, analysis) => sum + analysis.widgetsWithKeys);
  }

  int _getTotalHandlers() {
    return scanResult.keyUsages.length;
  }

  int _getLinkedHandlers() {
    return scanResult.keyUsages.values
        .where((usage) => usage.handlers.isNotEmpty)
        .length;
  }

  double _getLineCoverage() {
    // Approximate line coverage based on widget coverage
    return scanResult.metrics.widgetCoverage;
  }

  int _getCoveredLines() {
    // Approximate covered lines
    return (scanResult.metrics.totalLines * _getLineCoverage() / 100).round();
  }

  int _getNodesWithKeys() {
    return scanResult.keyUsages.values
        .fold(0, (sum, usage) => sum + usage.locations.length);
  }

  Map<String, int> _getDetectorMetrics() {
    final metrics = <String, int>{};
    for (final entry in scanResult.metrics.detectorHits.entries) {
      metrics[entry.key] = entry.value;
    }
    return metrics;
  }

  Map<String, int> _getKeysByDetector() {
    final byDetector = <String, int>{};
    for (final usage in scanResult.keyUsages.values) {
      for (final location in usage.locations) {
        byDetector[location.detector] =
            (byDetector[location.detector] ?? 0) + 1;
      }
    }
    return byDetector;
  }

  Map<String, int> _getKeysByFile() {
    final byFile = <String, int>{};
    for (final analysis in scanResult.fileAnalyses.values) {
      if (analysis.keysFound.isNotEmpty) {
        byFile[analysis.relativePath] = analysis.keysFound.length;
      }
    }
    return byFile;
  }

  List<String> _getOrphanedKeys() {
    return scanResult.keyUsages.entries
        .where((e) => e.value.handlers.isEmpty)
        .map((e) => e.key)
        .toList();
  }

  List<String> _getDuplicateKeys() {
    final duplicates = <String>[];
    for (final entry in scanResult.keyUsages.entries) {
      if (entry.value.locations.length > 1) {
        duplicates.add(entry.key);
      }
    }
    return duplicates;
  }

  double _getDetectorEffectiveness(String detector) {
    final hits = scanResult.metrics.detectorHits[detector] ?? 0;
    if (hits == 0) return 0;

    final keys = _getDetectorKeyCount(detector);
    return (keys / hits * 100).clamp(0, 100);
  }

  int _getDetectorKeyCount(String detector) {
    return scanResult.keyUsages.values
        .where(
            (usage) => usage.locations.any((loc) => loc.detector == detector))
        .length;
  }

  int _getFileHandlers(String filePath) {
    int count = 0;
    for (final usage in scanResult.keyUsages.values) {
      count += usage.handlers.where((h) => h.file == filePath).length;
    }
    return count;
  }

  Map<String, dynamic> _getFileDetails(bool includeEvidence) {
    final details = <String, dynamic>{};

    for (final entry in scanResult.fileAnalyses.entries) {
      final analysis = entry.value;
      details[analysis.relativePath] = {
        'keys': analysis.keysFound.toList(),
        'widgets': analysis.widgetCount,
        'widgets_with_keys': analysis.widgetsWithKeys,
        'functions': analysis.functions,
        'methods': analysis.methods,
        'nodes_analyzed': analysis.nodesAnalyzed,
        'detector_hits': analysis.detectorHits,
      };

      if (includeEvidence) {
        // Add key locations for this file
        final fileKeys = <String, dynamic>{};
        for (final usage in scanResult.keyUsages.entries) {
          final locations = usage.value.locations
              .where((loc) => loc.file == entry.key)
              .toList();

          if (locations.isNotEmpty) {
            fileKeys[usage.key] = locations
                .map((loc) => {
                      'line': loc.line,
                      'column': loc.column,
                      'detector': loc.detector,
                      'context': loc.context,
                    })
                .toList();
          }
        }
        details[analysis.relativePath]['key_locations'] = fileKeys;
      }
    }

    return details;
  }

  Map<String, dynamic> _getEvidence() {
    final evidence = <String, dynamic>{};

    for (final entry in scanResult.keyUsages.entries) {
      evidence[entry.key] = {
        'locations': entry.value.locations
            .map((loc) => {
                  'file': path.relative(loc.file, from: projectPath),
                  'line': loc.line,
                  'column': loc.column,
                  'detector': loc.detector,
                  'context': loc.context,
                })
            .toList(),
        'handlers': entry.value.handlers
            .map((h) => {
                  'type': h.type,
                  'method': h.method,
                  'file': path.relative(h.file, from: projectPath),
                  'line': h.line,
                })
            .toList(),
      };
    }

    return evidence;
  }

  List<Map<String, dynamic>> _checkThresholds() {
    final violations = <Map<String, dynamic>>[];

    // Check file coverage
    final fileCoverageThreshold =
        thresholds['file_coverage'] as double? ?? 80.0;
    if (scanResult.metrics.fileCoverage < fileCoverageThreshold) {
      violations.add({
        'metric': 'File Coverage',
        'actual': scanResult.metrics.fileCoverage.toStringAsFixed(1),
        'threshold': fileCoverageThreshold.toStringAsFixed(1),
      });
    }

    // Check widget coverage
    final widgetCoverageThreshold =
        thresholds['widget_coverage'] as double? ?? 70.0;
    if (scanResult.metrics.widgetCoverage < widgetCoverageThreshold) {
      violations.add({
        'metric': 'Widget Coverage',
        'actual': scanResult.metrics.widgetCoverage.toStringAsFixed(1),
        'threshold': widgetCoverageThreshold.toStringAsFixed(1),
      });
    }

    // Check handler coverage
    final handlerCoverageThreshold =
        thresholds['handler_coverage'] as double? ?? 60.0;
    if (scanResult.metrics.handlerCoverage < handlerCoverageThreshold) {
      violations.add({
        'metric': 'Handler Coverage',
        'actual': scanResult.metrics.handlerCoverage.toStringAsFixed(1),
        'threshold': handlerCoverageThreshold.toStringAsFixed(1),
      });
    }

    // Check for critical blind spots
    if (scanResult.blindSpots.any((bs) => bs.severity == 'error')) {
      violations.add({
        'metric': 'Blind Spots',
        'actual': 'Critical blind spots detected',
        'threshold': 'None allowed',
      });
    }

    return violations;
  }

  void _addMetricCard(
      StringBuffer buffer, String label, double value, String unit) {
    final percentage = value.toStringAsFixed(1);
    buffer.writeln('''
      <div class="metric-card">
        <div class="metric-value">$percentage$unit</div>
        <div class="metric-label">$label</div>
        <div class="progress">
          <div class="progress-bar" style="width: ${value.clamp(0, 100)}%"></div>
        </div>
      </div>
    ''');
  }

  void _addJUnitTest(
      StringBuffer buffer, String name, double actual, double threshold) {
    buffer.writeln('    <testcase name="$name" classname="Coverage">');
    if (actual < threshold) {
      buffer.writeln('      <failure message="Coverage below threshold">');
      buffer.writeln('        Actual: ${actual.toStringAsFixed(1)}%');
      buffer.writeln('        Threshold: ${threshold.toStringAsFixed(1)}%');
      buffer.writeln('      </failure>');
    }
    buffer.writeln('    </testcase>');
  }

  void _addTextMetric(StringBuffer buffer, String label, int covered, int total,
      double percentage) {
    final bar = _generateProgressBar(percentage);
    buffer.writeln(
        '${label.padRight(20)} $bar ${percentage.toStringAsFixed(1).padLeft(5)}% ($covered/$total)');
  }

  String _generateProgressBar(double percentage) {
    final width = 20;
    final filled = (percentage / 100 * width).round();
    final empty = width - filled;
    return '[${'█' * filled}${'░' * empty}]';
  }
}
