import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/scan_result.dart';
import '../reporter/coverage_reporter.dart';

/// Helper functions for safe type casting
double _asDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return defaultValue;
}

bool _asBool(dynamic value, bool defaultValue) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  return defaultValue;
}

/// CI integration with metrics and threshold checks
class CiIntegration {
  final Map<String, dynamic> config;
  final String outputDir;
  final bool strictMode;

  CiIntegration({
    required this.config,
    this.outputDir = './reports',
    this.strictMode = false,
  });

  /// Run CI validation with threshold checks
  Future<CiResult> validate(ScanResult scanResult) async {
    final result = CiResult();

    // Check coverage thresholds
    result.coverageChecks = _checkCoverageThresholds(scanResult);

    // Check blind spots
    result.blindSpotChecks = _checkBlindSpots(scanResult);

    // Check detector effectiveness
    result.detectorChecks = _checkDetectorEffectiveness(scanResult);

    // Check for regressions
    result.regressionChecks = await _checkRegressions(scanResult);

    // Generate CI-specific reports
    await _generateCiReports(scanResult, result);

    // Set exit code
    result.exitCode = _determineExitCode(result);

    // Print CI summary
    _printCiSummary(result);

    return result;
  }

  /// Check coverage thresholds
  List<ThresholdCheck> _checkCoverageThresholds(ScanResult scanResult) {
    final checks = <ThresholdCheck>[];

    // File coverage
    checks.add(ThresholdCheck(
      name: 'file_coverage',
      metric: 'File Coverage',
      actual: scanResult.metrics.fileCoverage,
      threshold: _asDouble(config['thresholds']?['file_coverage'], 80.0),
      required: _asBool(config['thresholds']?['file_coverage_required'], true),
    ));

    // Widget coverage
    checks.add(ThresholdCheck(
      name: 'widget_coverage',
      metric: 'Widget Coverage',
      actual: scanResult.metrics.widgetCoverage,
      threshold: _asDouble(config['thresholds']?['widget_coverage'], 70.0),
      required:
          _asBool(config['thresholds']?['widget_coverage_required'], true),
    ));

    // Handler coverage
    checks.add(ThresholdCheck(
      name: 'handler_coverage',
      metric: 'Handler Coverage',
      actual: scanResult.metrics.handlerCoverage,
      threshold: _asDouble(config['thresholds']?['handler_coverage'], 60.0),
      required:
          _asBool(config['thresholds']?['handler_coverage_required'], false),
    ));

    // Line coverage (approximate)
    final lineCoverage = _calculateLineCoverage(scanResult);
    checks.add(ThresholdCheck(
      name: 'line_coverage',
      metric: 'Line Coverage',
      actual: lineCoverage,
      threshold: _asDouble(config['thresholds']?['line_coverage'], 50.0),
      required: _asBool(config['thresholds']?['line_coverage_required'], false),
    ));

    return checks;
  }

  /// Check for blind spots
  List<BlindSpotCheck> _checkBlindSpots(ScanResult scanResult) {
    final checks = <BlindSpotCheck>[];

    for (final blindSpot in scanResult.blindSpots) {
      final isBlocked = _isBlindSpotBlocked(blindSpot);

      checks.add(BlindSpotCheck(
        type: blindSpot.type,
        severity: blindSpot.severity,
        location: blindSpot.location,
        message: blindSpot.message,
        blocked: isBlocked,
      ));
    }

    return checks;
  }

  /// Check detector effectiveness
  List<DetectorCheck> _checkDetectorEffectiveness(ScanResult scanResult) {
    final checks = <DetectorCheck>[];

    for (final entry in scanResult.metrics.detectorHits.entries) {
      final effectiveness = _calculateEffectiveness(
        entry.key,
        entry.value,
        scanResult,
      );

      final minEffectiveness = _asDouble(
          config['detectors']?[entry.key]?['min_effectiveness'], 25.0);

      checks.add(DetectorCheck(
        name: entry.key,
        hits: entry.value,
        effectiveness: effectiveness,
        threshold: minEffectiveness,
        passed: effectiveness >= minEffectiveness,
      ));
    }

    return checks;
  }

  /// Check for regressions compared to baseline
  Future<List<RegressionCheck>> _checkRegressions(ScanResult scanResult) async {
    final checks = <RegressionCheck>[];

    // Load baseline if exists
    final baselineFile = File(path.join(outputDir, 'baseline.json'));
    if (!baselineFile.existsSync()) {
      return checks;
    }

    try {
      final baselineContent = await baselineFile.readAsString();
      final baseline = jsonDecode(baselineContent) as Map<String, dynamic>;

      // Compare file coverage
      final baselineFileCoverage = _asDouble(
          baseline['coverage']?['files']?['percentage'], 0.0);
      if (scanResult.metrics.fileCoverage < baselineFileCoverage - 5) {
        checks.add(RegressionCheck(
          metric: 'File Coverage',
          baseline: baselineFileCoverage,
          current: scanResult.metrics.fileCoverage,
          regression: true,
        ));
      }

      // Compare widget coverage
      final baselineWidgetCoverage = _asDouble(
          baseline['coverage']?['widgets']?['percentage'], 0.0);
      if (scanResult.metrics.widgetCoverage < baselineWidgetCoverage - 5) {
        checks.add(RegressionCheck(
          metric: 'Widget Coverage',
          baseline: baselineWidgetCoverage,
          current: scanResult.metrics.widgetCoverage,
          regression: true,
        ));
      }

      // Compare key count
      final baselineKeyCount = (baseline['keys']?['total'] as num?)?.toInt() ?? 0;
      final currentKeyCount = scanResult.keyUsages.length;

      if (currentKeyCount < baselineKeyCount * 0.9) {
        checks.add(RegressionCheck(
          metric: 'Total Keys',
          baseline: baselineKeyCount.toDouble(),
          current: currentKeyCount.toDouble(),
          regression: true,
        ));
      }
    } catch (e) {
      // Invalid baseline, skip regression checks
    }

    return checks;
  }

  /// Generate CI-specific reports
  Future<void> _generateCiReports(
      ScanResult scanResult, CiResult ciResult) async {
    // Ensure output directory exists
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // Generate metrics JSON
    final metricsFile = File(path.join(outputDir, 'metrics.json'));
    await metricsFile.writeAsString(jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'coverage': {
        'file': scanResult.metrics.fileCoverage,
        'widget': scanResult.metrics.widgetCoverage,
        'handler': scanResult.metrics.handlerCoverage,
      },
      'keys': {
        'total': scanResult.keyUsages.length,
        'orphaned': _getOrphanedKeys(scanResult).length,
        'duplicates': _getDuplicateKeys(scanResult).length,
      },
      'blind_spots': scanResult.blindSpots.length,
      'errors': scanResult.metrics.errors.length,
      'ci_result': ciResult.toJson(),
    }));

    // Generate GitHub Actions summary if in GitHub environment
    if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
      await _generateGitHubSummary(scanResult, ciResult);
    }

    // Generate GitLab CI summary if in GitLab environment
    if (Platform.environment['GITLAB_CI'] == 'true') {
      await _generateGitLabSummary(scanResult, ciResult);
    }

    // Update baseline if all checks pass and not in PR
    if (ciResult.allPassed && !_isInPullRequest()) {
      await _updateBaseline(scanResult);
    }
  }

  /// Generate GitHub Actions summary
  Future<void> _generateGitHubSummary(
      ScanResult scanResult, CiResult ciResult) async {
    final summaryFile = File(
        Platform.environment['GITHUB_STEP_SUMMARY'] ?? 'github-summary.md');

    final buffer = StringBuffer();

    buffer.writeln('# 🔍 Flutter KeyCheck Coverage Report\n');

    // Status badge
    final status = ciResult.allPassed ? '✅ PASSED' : '❌ FAILED';
    buffer.writeln('## Status: $status\n');

    // Coverage table
    buffer.writeln('### Coverage Metrics\n');
    buffer.writeln('| Metric | Coverage | Threshold | Status |');
    buffer.writeln('|--------|----------|-----------|--------|');

    for (final check in ciResult.coverageChecks) {
      final status = check.passed ? '✅' : '❌';
      buffer.writeln(
          '| ${check.metric} | ${check.actual.toStringAsFixed(1)}% | ${check.threshold.toStringAsFixed(1)}% | $status |');
    }

    // Blind spots
    if (ciResult.blindSpotChecks.isNotEmpty) {
      buffer.writeln('\n### ⚠️ Blind Spots\n');
      for (final check in ciResult.blindSpotChecks) {
        final icon = check.severity == 'error' ? '🔴' : '🟡';
        buffer.writeln('$icon **${check.type}** - ${check.message}');
      }
    }

    // Regressions
    if (ciResult.regressionChecks.any((r) => r.regression)) {
      buffer.writeln('\n### 📉 Regressions Detected\n');
      for (final check
          in ciResult.regressionChecks.where((r) => r.regression)) {
        buffer.writeln(
            '- **${check.metric}**: ${check.current.toStringAsFixed(1)}% (was ${check.baseline.toStringAsFixed(1)}%)');
      }
    }

    await summaryFile.writeAsString(buffer.toString());
  }

  /// Generate GitLab CI summary
  Future<void> _generateGitLabSummary(
      ScanResult scanResult, CiResult ciResult) async {
    // GitLab uses artifacts for summary
    final summaryFile = File(path.join(outputDir, 'gitlab-summary.md'));

    final buffer = StringBuffer();

    buffer.writeln('## 🔍 Flutter KeyCheck Coverage Report\n');

    // Create metrics for GitLab's metrics feature
    final metricsFile = File(path.join(outputDir, 'metrics.txt'));
    final metricsBuffer = StringBuffer();

    metricsBuffer.writeln(
        'flutter_keycheck_file_coverage ${scanResult.metrics.fileCoverage}');
    metricsBuffer.writeln(
        'flutter_keycheck_widget_coverage ${scanResult.metrics.widgetCoverage}');
    metricsBuffer.writeln(
        'flutter_keycheck_handler_coverage ${scanResult.metrics.handlerCoverage}');
    metricsBuffer
        .writeln('flutter_keycheck_total_keys ${scanResult.keyUsages.length}');
    metricsBuffer.writeln(
        'flutter_keycheck_blind_spots ${scanResult.blindSpots.length}');

    await metricsFile.writeAsString(metricsBuffer.toString());

    // Generate summary similar to GitHub
    final status = ciResult.allPassed ? '✅ PASSED' : '❌ FAILED';
    buffer.writeln('**Status:** $status\n');

    // Add coverage badges
    for (final check in ciResult.coverageChecks) {
      final color = check.passed ? 'green' : 'red';
      buffer.writeln(
          '![${check.metric}](https://img.shields.io/badge/${check.metric.replaceAll(' ', '_')}-${check.actual.toStringAsFixed(1)}%25-$color)');
    }

    await summaryFile.writeAsString(buffer.toString());
  }

  /// Update baseline
  Future<void> _updateBaseline(ScanResult scanResult) async {
    final reporter = CoverageReporter(
      scanResult: scanResult,
      projectPath: Directory.current.path,
    );

    final baselineFile = File(path.join(outputDir, 'baseline.json'));
    await baselineFile.writeAsString(
      reporter.generateReport(format: 'json', includeDetails: false),
    );
  }

  /// Determine exit code based on results
  int _determineExitCode(CiResult result) {
    // Check for critical failures
    if (result.coverageChecks.any((c) => c.required && !c.passed)) {
      return 1; // Coverage threshold violation
    }

    if (result.blindSpotChecks.any((b) => b.blocked)) {
      return 2; // Blocked blind spot
    }

    if (result.regressionChecks.any((r) => r.regression && strictMode)) {
      return 3; // Regression in strict mode
    }

    return 0; // All passed
  }

  /// Print CI summary to console
  void _printCiSummary(CiResult result) {
    final status = result.allPassed ? '✅ PASSED' : '❌ FAILED';

    print('');
    print('════════════════════════════════════════════');
    print('     FLUTTER KEYCHECK CI VALIDATION         ');
    print('════════════════════════════════════════════');
    print('');
    print('Status: $status');
    print('Exit Code: ${result.exitCode}');
    print('');

    // Coverage summary
    print('Coverage Checks:');
    for (final check in result.coverageChecks) {
      final icon = check.passed ? '✓' : '✗';
      final required = check.required ? ' [REQUIRED]' : '';
      print(
          '  [$icon] ${check.metric}: ${check.actual.toStringAsFixed(1)}% / ${check.threshold.toStringAsFixed(1)}%$required');
    }

    // Blind spots summary
    if (result.blindSpotChecks.isNotEmpty) {
      print('');
      print('Blind Spots: ${result.blindSpotChecks.length} detected');
      final blocked = result.blindSpotChecks.where((b) => b.blocked).length;
      if (blocked > 0) {
        print('  ⚠️  $blocked blocked blind spots!');
      }
    }

    // Regressions summary
    final regressions =
        result.regressionChecks.where((r) => r.regression).length;
    if (regressions > 0) {
      print('');
      print('⚠️  Regressions: $regressions metrics degraded');
    }

    print('');
    print('Reports saved to: $outputDir/');
    print('════════════════════════════════════════════');
    print('');
  }

  // Helper methods

  double _calculateLineCoverage(ScanResult scanResult) {
    // Approximate based on widget coverage
    return scanResult.metrics.widgetCoverage * 0.8;
  }

  double _calculateEffectiveness(
      String detector, int hits, ScanResult scanResult) {
    if (hits == 0) return 0;

    final keys = scanResult.keyUsages.values
        .where(
            (usage) => usage.locations.any((loc) => loc.detector == detector))
        .length;

    return (keys / hits * 100).clamp(0, 100);
  }

  bool _isBlindSpotBlocked(BlindSpot blindSpot) {
    final blockedTypes = config['blind_spots']?['blocked'] as List? ?? [];
    return blockedTypes.contains(blindSpot.type) ||
        (blindSpot.severity == 'error' && strictMode);
  }

  List<String> _getOrphanedKeys(ScanResult scanResult) {
    return scanResult.keyUsages.entries
        .where((e) => e.value.handlers.isEmpty)
        .map((e) => e.key)
        .toList();
  }

  List<String> _getDuplicateKeys(ScanResult scanResult) {
    return scanResult.keyUsages.entries
        .where((e) => e.value.locations.length > 1)
        .map((e) => e.key)
        .toList();
  }

  bool _isInPullRequest() {
    // GitHub
    if (Platform.environment['GITHUB_EVENT_NAME'] == 'pull_request') {
      return true;
    }

    // GitLab
    if (Platform.environment['CI_MERGE_REQUEST_ID'] != null) {
      return true;
    }

    // Bitbucket
    if (Platform.environment['BITBUCKET_PR_ID'] != null) {
      return true;
    }

    return false;
  }
}

/// CI validation result
class CiResult {
  List<ThresholdCheck> coverageChecks = [];
  List<BlindSpotCheck> blindSpotChecks = [];
  List<DetectorCheck> detectorChecks = [];
  List<RegressionCheck> regressionChecks = [];
  int exitCode = 0;

  bool get allPassed =>
      coverageChecks.every((c) => !c.required || c.passed) &&
      !blindSpotChecks.any((b) => b.blocked) &&
      detectorChecks.every((d) => d.passed) &&
      !regressionChecks.any((r) => r.regression);

  Map<String, dynamic> toJson() => {
        'passed': allPassed,
        'exit_code': exitCode,
        'coverage_checks': coverageChecks.map((c) => c.toJson()).toList(),
        'blind_spot_checks': blindSpotChecks.map((b) => b.toJson()).toList(),
        'detector_checks': detectorChecks.map((d) => d.toJson()).toList(),
        'regression_checks': regressionChecks.map((r) => r.toJson()).toList(),
      };
}

/// Threshold check result
class ThresholdCheck {
  final String name;
  final String metric;
  final double actual;
  final double threshold;
  final bool required;

  ThresholdCheck({
    required this.name,
    required this.metric,
    required this.actual,
    required this.threshold,
    required this.required,
  });

  bool get passed => actual >= threshold;

  Map<String, dynamic> toJson() => {
        'name': name,
        'metric': metric,
        'actual': actual,
        'threshold': threshold,
        'required': required,
        'passed': passed,
      };
}

/// Blind spot check result
class BlindSpotCheck {
  final String type;
  final String severity;
  final String location;
  final String message;
  final bool blocked;

  BlindSpotCheck({
    required this.type,
    required this.severity,
    required this.location,
    required this.message,
    required this.blocked,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'severity': severity,
        'location': location,
        'message': message,
        'blocked': blocked,
      };
}

/// Detector effectiveness check
class DetectorCheck {
  final String name;
  final int hits;
  final double effectiveness;
  final double threshold;
  final bool passed;

  DetectorCheck({
    required this.name,
    required this.hits,
    required this.effectiveness,
    required this.threshold,
    required this.passed,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'hits': hits,
        'effectiveness': effectiveness,
        'threshold': threshold,
        'passed': passed,
      };
}

/// Regression check result
class RegressionCheck {
  final String metric;
  final double baseline;
  final double current;
  final bool regression;

  RegressionCheck({
    required this.metric,
    required this.baseline,
    required this.current,
    required this.regression,
  });

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'baseline': baseline,
        'current': current,
        'regression': regression,
        'delta': current - baseline,
      };
}
