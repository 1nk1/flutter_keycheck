import 'dart:convert';
import 'dart:io';

import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';

/// Base reporter class for v3
abstract class ReporterV3 {
  /// Create reporter based on format
  static ReporterV3 create(String format) {
    switch (format) {
      case 'json':
        return JsonReporter();
      case 'junit':
        return JUnitReporter();
      case 'md':
      case 'markdown':
        return MarkdownReporter();
      case 'html':
        // HTML reporter uses premium implementation in html_reporter.dart
        throw UnsupportedError(
            'HTML reporter should use HtmlReporter from html_reporter.dart');
      case 'text':
        return TextReporter();
      case 'ci':
      case 'gitlab':
        return CIReporter();
      default:
        return TextReporter();
    }
  }

  /// Generate scan report
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  });

  /// Generate validation report
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  });
}

/// JSON reporter
class JsonReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final Map<String, dynamic> report = {
      'schema_version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'scan_type': result.metrics.incrementalScan ? 'incremental' : 'full',
    };

    if (result.metrics.incrementalScan) {
      report['incremental_base'] = result.metrics.incrementalBase ?? '';
    }

    // Add summary
    report['summary'] = {
      'total_files': result.metrics.totalFiles,
      'scanned_files': result.metrics.scannedFiles,
      'total_keys': result.keyUsages.length,
      'file_coverage': result.metrics.fileCoverage,
      'widget_coverage': result.metrics.widgetCoverage,
      'handler_coverage': result.metrics.handlerCoverage,
    };

    // Add metrics if requested
    if (includeMetrics) {
      report['metrics'] = result.metrics.toMap();
    }

    // Add keys
    final keys = <Map<String, dynamic>>[];
    for (final entry in result.keyUsages.entries) {
      final keyData = <String, dynamic>{
        'id': entry.key,
        'tags': entry.value.tags.toList(),
        'status': entry.value.status,
        'location_count': entry.value.locations.length,
      };

      if (includeLocations) {
        keyData['locations'] = entry.value.locations
            .map((loc) => {
                  'file': loc.file,
                  'line': loc.line,
                  'column': loc.column,
                  'detector': loc.detector,
                  'context': loc.context,
                })
            .toList();
      }

      keys.add(keyData);
    }
    report['keys'] = keys;

    // Add blind spots
    if (result.blindSpots.isNotEmpty) {
      report['blind_spots'] =
          result.blindSpots.map((spot) => spot.toMap()).toList();
    }

    // Add errors if any
    if (result.metrics.errors.isNotEmpty) {
      report['errors'] =
          result.metrics.errors.map((err) => err.toMap()).toList();
    }

    // Write to file
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final report = result.toMap();

    // Write to file
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  }
}

/// JUnit XML reporter
class JUnitReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<testsuites name="Flutter KeyCheck Scan" tests="${result.keyUsages.length}">');

    // Group by package
    final keysByPackage = <String, List<MapEntry<String, KeyUsage>>>{};
    for (final entry in result.keyUsages.entries) {
      final package = _getPackageFromPath(entry.value.locations.first.file);
      keysByPackage.putIfAbsent(package, () => []).add(entry);
    }

    for (final packageEntry in keysByPackage.entries) {
      buffer.writeln(
          '  <testsuite name="${packageEntry.key}" tests="${packageEntry.value.length}">');

      for (final keyEntry in packageEntry.value) {
        buffer.writeln(
            '    <testcase name="Key: ${keyEntry.key}" classname="Found">');
        if (includeLocations) {
          buffer.writeln('      <system-out>');
          for (final loc in keyEntry.value.locations) {
            buffer.writeln('        ${loc.file}:${loc.line}:${loc.column}');
          }
          buffer.writeln('      </system-out>');
        }
        buffer.writeln('    </testcase>');
      }

      buffer.writeln('  </testsuite>');
    }

    buffer.writeln('</testsuites>');

    await outputFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<testsuites name="Flutter KeyCheck Validation" '
        'tests="${result.summary.totalKeys}" '
        'failures="${result.violations.length}">');

    // Group violations by package
    final violationsByPackage = <String, List<Violation>>{};
    for (final violation in result.violations) {
      if (violation.key != null) {
        final package = violation.key!.package;
        violationsByPackage.putIfAbsent(package, () => []).add(violation);
      }
    }

    // Add test suites
    for (final entry in violationsByPackage.entries) {
      buffer.writeln('  <testsuite name="${entry.key}" '
          'tests="${entry.value.length}" '
          'failures="${entry.value.length}">');

      for (final violation in entry.value) {
        buffer.writeln(
            '    <testcase name="Key: ${violation.key?.id ?? 'policy'}" '
            'classname="${violation.type}">');
        buffer.writeln(
            '      <failure message="${_escapeXml(violation.message)}">');
        buffer.writeln('        ${_escapeXml(violation.message)}');
        if (violation.key != null) {
          buffer.writeln('        Key: ${violation.key!.id}');
          buffer.writeln('        Tags: ${violation.key!.tags.join(', ')}');
          if (violation.key!.lastSeen != null) {
            buffer.writeln('        Last seen: ${violation.key!.lastSeen}');
          }
        }
        buffer.writeln(
            '        Remediation: ${_escapeXml(violation.remediation)}');
        buffer.writeln('      </failure>');
        buffer.writeln('    </testcase>');
      }

      buffer.writeln('  </testsuite>');
    }

    // Add summary as properties
    buffer.writeln('  <properties>');
    buffer.writeln(
        '    <property name="total_keys" value="${result.summary.totalKeys}"/>');
    buffer.writeln(
        '    <property name="lost_keys" value="${result.summary.lostKeys}"/>');
    buffer.writeln(
        '    <property name="added_keys" value="${result.summary.addedKeys}"/>');
    buffer.writeln(
        '    <property name="renamed_keys" value="${result.summary.renamedKeys}"/>');
    buffer.writeln(
        '    <property name="drift_percentage" value="${result.summary.driftPercentage.toStringAsFixed(1)}"/>');
    buffer.writeln('  </properties>');

    buffer.writeln('</testsuites>');

    await outputFile.writeAsString(buffer.toString());
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _getPackageFromPath(String filePath) {
    if (filePath.contains('packages/')) {
      final parts = filePath.split('/');
      final packagesIndex = parts.indexOf('packages');
      if (packagesIndex >= 0 && packagesIndex < parts.length - 1) {
        return parts[packagesIndex + 1];
      }
    }
    return 'app_main';
  }
}

/// Markdown reporter
class MarkdownReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('# 🔍 Key Scan Report');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // Summary section
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('- **Total Files**: ${result.metrics.totalFiles}');
    buffer.writeln('- **Scanned Files**: ${result.metrics.scannedFiles}');
    buffer.writeln('- **Total Keys**: ${result.keyUsages.length}');
    buffer.writeln(
        '- **File Coverage**: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');
    buffer.writeln(
        '- **Widget Coverage**: ${result.metrics.widgetCoverage.toStringAsFixed(1)}%');
    buffer.writeln(
        '- **Handler Coverage**: ${result.metrics.handlerCoverage.toStringAsFixed(1)}%');
    buffer.writeln();

    // Keys by status
    final keysByStatus = <String, List<String>>{};
    for (final entry in result.keyUsages.entries) {
      final status = entry.value.status;
      keysByStatus.putIfAbsent(status, () => []).add(entry.key);
    }

    buffer.writeln('## Keys by Status');
    buffer.writeln();
    for (final entry in keysByStatus.entries) {
      buffer.writeln('### ${_capitalize(entry.key)} (${entry.value.length})');
      buffer.writeln();
      for (final key in entry.value..sort()) {
        buffer.write('- `$key`');
        final usage = result.keyUsages[key]!;
        if (usage.tags.isNotEmpty) {
          buffer.write(' ${usage.tags.map((t) => '`$t`').join(' ')}');
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    // Blind spots
    if (result.blindSpots.isNotEmpty) {
      buffer.writeln('## ⚠️ Blind Spots');
      buffer.writeln();
      for (final spot in result.blindSpots) {
        final icon = spot.severity == 'error'
            ? '🔴'
            : spot.severity == 'warning'
                ? '🟡'
                : 'ℹ️';
        buffer.writeln('- $icon ${spot.message}');
      }
      buffer.writeln();
    }

    // Metrics
    if (includeMetrics) {
      buffer.writeln('## 📊 Metrics');
      buffer.writeln();
      buffer.writeln('### Detector Effectiveness');
      buffer.writeln();
      buffer.writeln('| Detector | Hits |');
      buffer.writeln('|----------|------|');
      for (final entry in result.metrics.detectorHits.entries) {
        buffer.writeln('| ${entry.key} | ${entry.value} |');
      }
      buffer.writeln();
    }

    await outputFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('# 🔑 Key Validation Report');
    buffer.writeln();
    buffer.writeln('Generated: ${result.timestamp.toIso8601String()}');
    buffer.writeln();

    // Summary
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('- **Total Keys**: ${result.summary.totalKeys}');
    buffer.writeln('- **Lost**: ${result.summary.lostKeys} 🔥');
    buffer.writeln('- **Added**: ${result.summary.addedKeys} ➕');
    buffer.writeln('- **Renamed**: ${result.summary.renamedKeys} ♻️');
    buffer.writeln(
        '- **Drift**: ${result.summary.driftPercentage.toStringAsFixed(1)}% 📈');
    buffer.writeln();

    // Status
    if (result.hasViolations) {
      buffer.writeln('## ❌ Validation Failed');
    } else {
      buffer.writeln('## ✅ Validation Passed');
    }
    buffer.writeln();

    // Violations
    if (result.violations.isNotEmpty) {
      buffer.writeln('## Critical Issues');
      buffer.writeln();
      buffer.writeln('| Type | Key | Package | Tags | Action |');
      buffer.writeln('|------|-----|---------|------|--------|');

      for (final violation in result.violations) {
        final icon = violation.type == 'lost'
            ? '🔥'
            : violation.type == 'renamed'
                ? '♻️'
                : violation.type == 'extra'
                    ? '➕'
                    : '⚠️';

        buffer.write('| $icon ${violation.type} ');
        buffer.write('| ${violation.key?.id ?? 'N/A'} ');
        buffer.write('| ${violation.key?.package ?? 'N/A'} ');
        buffer.write('| ${violation.key?.tags.join(', ') ?? ''} ');
        buffer.writeln('| ${violation.remediation} |');
      }
      buffer.writeln();
    }

    // Warnings
    if (result.warnings.isNotEmpty) {
      buffer.writeln('## Warnings');
      buffer.writeln();
      for (final warning in result.warnings) {
        buffer.writeln('- ⚠️ $warning');
      }
      buffer.writeln();
    }

    // Scanned packages
    buffer.writeln('## Scanned Packages');
    buffer.writeln();
    for (final package in result.summary.scannedPackages) {
      buffer.writeln('- `$package`');
    }

    await outputFile.writeAsString(buffer.toString());
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// HTML reporter has been moved to a separate file: html_reporter.dart

/// Text reporter for human-readable output
class TextReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('Flutter KeyCheck Scan Report');
    buffer.writeln('=' * 40);
    buffer.writeln();
    buffer.writeln('Summary:');
    buffer.writeln('  Total Keys: ${result.keyUsages.length}');
    buffer.writeln(
        '  Files Scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}');
    buffer.writeln(
        '  Coverage: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');
    buffer.writeln();

    if (result.keyUsages.isNotEmpty) {
      buffer.writeln('Keys Found:');
      for (final entry in result.keyUsages.entries.take(20)) {
        buffer.writeln(
            '  - ${entry.key} (${entry.value.locations.length} locations)');
      }
      if (result.keyUsages.length > 20) {
        buffer.writeln('  ... and ${result.keyUsages.length - 20} more');
      }
    }

    await outputFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('Flutter KeyCheck Validation Report');
    buffer.writeln('=' * 40);
    buffer.writeln();
    buffer.writeln('Status: ${result.hasViolations ? 'FAILED' : 'PASSED'}');
    buffer.writeln();

    if (result.hasViolations) {
      buffer.writeln('Violations:');
      if (result.lostKeys.isNotEmpty) {
        buffer.writeln('  Lost Keys: ${result.lostKeys.length}');
      }
      if (result.renamedKeys.isNotEmpty) {
        buffer.writeln('  Renamed Keys: ${result.renamedKeys.length}');
      }
    }

    await outputFile.writeAsString(buffer.toString());
  }
}

/// CI/CD reporter with beautiful terminal output
class CIReporter extends ReporterV3 {
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';
  static const String _boldValidation = '\x1B[1m🔍';
  static const String _boldBuild = '\x1B[1m🔨';

  final bool useColors;
  final bool isGitLabCI;

  CIReporter({this.useColors = true})
      : isGitLabCI = Platform.environment['GITLAB_CI'] == 'true';

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();

    // Header with beautiful CI branding
    buffer.writeln(_formatHeader());

    // Build status badge
    buffer.writeln(_formatStatus(result));

    // Key metrics in a clean table format
    buffer.writeln(_formatMetrics(result));

    // Quality gates status
    buffer.writeln(_formatQualityGates(result));

    // Summary for CI logs
    buffer.writeln(_formatSummary(result));

    // GitLab-specific collapsible sections
    if (isGitLabCI) {
      buffer.writeln(_formatGitLabSections(result));
    }

    await outputFile.writeAsString(buffer.toString());

    // Also output to stdout for CI visibility
    stdout.write(buffer.toString());
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln(_formatHeader());

    final hasViolations = result.hasViolations;
    final status = hasViolations ? 'FAILED' : 'PASSED';
    final color = hasViolations ? _red : _green;

    if (useColors) {
      buffer.writeln(
          '$_boldValidation Result:$_reset $color$_bold● $status$_reset');
    } else {
      buffer.writeln('Validation Result: $status');
    }

    if (hasViolations && result.violations.isNotEmpty) {
      buffer.writeln(
          '\n${useColors ? '$_red$_bold❌ Critical Issues$_reset' : 'Critical Issues:'}');

      for (final violation in result.violations.take(10)) {
        final type = violation.type;
        final key = violation.key?.id ?? 'unknown';
        if (useColors) {
          buffer.writeln(
              '$_red• $type: $_white$key$_reset $_dim- ${violation.message}$_reset');
        } else {
          buffer.writeln('• $type: $key - ${violation.message}');
        }
      }

      if (result.violations.length > 10) {
        buffer.writeln(
            '${useColors ? _dim : ''}... and ${result.violations.length - 10} more violations${useColors ? _reset : ''}');
      }
    }

    await outputFile.writeAsString(buffer.toString());
    stdout.write(buffer.toString());
  }

  String _formatHeader() {
    if (!useColors) return '=== Flutter KeyCheck CI Report ===\n';

    return '''
$_cyan╔═══════════════════════════════════════════════════════════╗
║$_bold$_white                 🔑 FLUTTER KEYCHECK                    $_reset$_cyan║
║$_dim                  CI/CD Analysis Report                   $_reset$_cyan║
╚═══════════════════════════════════════════════════════════╝$_reset
''';
  }

  String _formatStatus(ScanResult result) {
    final hasIssues = result.blindSpots.isNotEmpty;
    final status = hasIssues ? 'WARNING' : 'PASSED';
    final color = hasIssues ? _yellow : _green;

    if (!useColors) return 'Status: $status\n';

    return '''
$_boldBuild Status:$_reset $color$_bold● $status$_reset
''';
  }

  String _formatMetrics(ScanResult result) {
    if (!useColors) {
      return '''
Metrics:
  Keys Found: ${result.keyUsages.length}
  Files Scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}
  Coverage: ${result.metrics.fileCoverage.toStringAsFixed(1)}%
  Scan Time: ${result.metrics.totalScanTime.inMilliseconds}ms
''';
    }

    return '''
$_bold📊 Key Metrics$_reset
$_cyan┌─────────────────┬────────────────────────────────┐
│$_bold Metric          $_reset$_cyan│$_bold Value                          $_reset$_cyan│
├─────────────────┼────────────────────────────────┤
│ Keys Found      │$_green$_bold ${result.keyUsages.length.toString().padLeft(29)} $_reset$_cyan│
│ Files Scanned   │$_blue$_bold ${'${result.metrics.scannedFiles}/${result.metrics.totalFiles}'.padLeft(29)} $_reset$_cyan│
│ Coverage        │$_yellow$_bold ${'${result.metrics.fileCoverage.toStringAsFixed(1)}%'.padLeft(29)} $_reset$_cyan│
│ Scan Duration   │$_magenta$_bold ${'${result.metrics.totalScanTime.inMilliseconds}ms'.padLeft(29)} $_reset$_cyan│
└─────────────────┴────────────────────────────────┘$_reset
''';
  }

  String _formatQualityGates(ScanResult result) {
    final gates = _analyzeQualityGates(result);

    if (!useColors) {
      return '''
Quality Gates:
${gates.map((gate) => '  ${gate['status'] == 'PASS' ? '✓' : '✗'} ${gate['name']}: ${gate['status']}').join('\n')}
''';
    }

    final buffer = StringBuffer();
    buffer.writeln('$_bold🎯 Quality Gates$_reset');

    for (final gate in gates) {
      final icon = gate['status'] == 'PASS' ? '✓' : '✗';
      final color = gate['status'] == 'PASS' ? _green : _red;
      final status = gate['status'] == 'PASS' ? 'PASS' : 'FAIL';

      buffer.writeln(
          '$color$_bold$icon ${gate['name']}: $status$_reset $_dim- ${gate['description']}$_reset');
    }

    return buffer.toString();
  }

  List<Map<String, String>> _analyzeQualityGates(ScanResult result) {
    return [
      {
        'name': 'Coverage Gate',
        'status': result.metrics.fileCoverage >= 80.0 ? 'PASS' : 'FAIL',
        'description': 'Minimum 80% file coverage required'
      },
      {
        'name': 'Blind Spot Check',
        'status': result.blindSpots.length <= 5 ? 'PASS' : 'WARN',
        'description': 'Maximum 5 blind spots allowed'
      },
      {
        'name': 'Performance Gate',
        'status': result.metrics.totalScanTime.inSeconds < 30 ? 'PASS' : 'WARN',
        'description': 'Scan completed under 30 seconds'
      }
    ];
  }

  String _formatSummary(ScanResult result) {
    final hasWarnings = result.blindSpots.isNotEmpty;

    if (!hasWarnings) {
      return useColors
          ? '$_green$_bold🎉 All checks passed! Your Flutter app is ready for automation testing.$_reset\n'
          : '✓ All checks passed! Your Flutter app is ready for automation testing.\n';
    }

    final buffer = StringBuffer();
    if (useColors) buffer.writeln('$_yellow$_bold⚠️ Action Required$_reset');

    if (hasWarnings) {
      buffer.writeln(useColors
          ? '$_yellow• ${result.blindSpots.length} blind spots detected$_reset'
          : '• ${result.blindSpots.length} blind spots detected');
    }

    return buffer.toString();
  }

  String _formatGitLabSections(ScanResult result) {
    final buffer = StringBuffer();

    // Collapsible section for detailed results
    if (result.keyUsages.isNotEmpty) {
      buffer.writeln(
          '\ndetail<summary><b>📋 Key Details (${result.keyUsages.length} total)</b></summary>');

      final keysByCategory = <String, List<String>>{};
      for (final entry in result.keyUsages.entries) {
        final category = _categorizeKey(entry.key);
        keysByCategory.putIfAbsent(category, () => []).add(entry.key);
      }

      for (final entry in keysByCategory.entries) {
        buffer.writeln(
            '\n**${entry.key.toUpperCase()} (${entry.value.length})**');
        for (final key in entry.value) {
          buffer.writeln('- `$key`');
        }
      }

      buffer.writeln('detail');
    }

    // Collapsible section for blind spots
    if (result.blindSpots.isNotEmpty) {
      buffer.writeln(
          '\ndetail<summary><b>⚠️ Blind Spots (${result.blindSpots.length} found)</b></summary>');

      for (final spot in result.blindSpots) {
        buffer.writeln('- **${spot.location}**: ${spot.message}');
        buffer.writeln('  *Type: ${spot.type}* | *Severity: ${spot.severity}*');
      }

      buffer.writeln('detail');
    }

    return buffer.toString();
  }

  String _categorizeKey(String keyName) {
    final name = keyName.toLowerCase();
    if (name.contains('btn') || name.contains('button')) return 'Actions';
    if (name.contains('field') || name.contains('input')) return 'Forms';
    if (name.contains('nav') || name.contains('menu')) return 'Navigation';
    if (name.contains('text') || name.contains('label')) return 'Content';
    return 'Other';
  }

  String _buildKeyDistribution(ScanResult result) {
    final categories = <String, int>{};
    for (final usage in result.keyUsages.values) {
      final category = _categorizeKeyName(usage.id);
      categories[category] = (categories[category] ?? 0) + 1;
    }

    final buffer = StringBuffer();
    buffer.writeln('<div class="distribution-items">');

    for (final entry in categories.entries) {
      final percentage = (entry.value / result.keyUsages.length * 100).round();
      buffer.writeln('''
        <div class="distribution-item">
            <div class="category-info">
                <span class="category-name">${entry.key}</span>
                <span class="category-count">${entry.value} keys</span>
            </div>
            <div class="category-bar">
                <div class="bar-fill" style="width: $percentage%"></div>
            </div>
            <div class="category-percentage">$percentage%</div>
        </div>
      ''');
    }

    buffer.writeln('</div>');
    return buffer.toString();
  }

  String _categorizeKeyName(String keyName) {
    final name = keyName.toLowerCase();
    if (name.contains('button') || name.contains('btn')) return 'Buttons';
    if (name.contains('field') ||
        name.contains('input') ||
        name.contains('text')) {
      return 'Input Fields';
    }
    if (name.contains('menu') || name.contains('nav')) return 'Navigation';
    if (name.contains('modal') || name.contains('dialog')) return 'Modals';
    if (name.contains('list') || name.contains('item')) return 'Lists';
    return 'Other';
  }

  String _buildDuplicateKeysTable(ScanResult result) {
    final duplicateKeysList = result.keyUsages.entries
        .where((entry) => entry.value.locations.length > 1)
        .toList();

    if (duplicateKeysList.isEmpty) return '';

    return '''
        <div class="duplicate-keys-section glass-card">
            <div class="section-header">
                <i class="fa-solid fa-copy text-orange-400"></i>
                <h3>Duplicate Keys Analysis</h3>
                <span class="duplicate-count">${duplicateKeysList.length} keys with multiple references</span>
            </div>
            
            <div class="duplicate-keys-table-container">
                <table class="duplicate-keys-table">
                    <thead>
                        <tr>
                            <th>Key Name</th>
                            <th>References</th>
                            <th>Locations</th>
                            <th>Impact</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${duplicateKeysList.map((entry) => _buildDuplicateKeyRow(entry.key, entry.value)).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    ''';
  }

  String _buildDuplicateKeyRow(String keyName, KeyUsage keyData) {
    final refCount = keyData.locations.length;
    final impact = refCount > 5
        ? 'High'
        : refCount > 3
            ? 'Medium'
            : 'Low';
    final impactClass = refCount > 5
        ? 'high'
        : refCount > 3
            ? 'medium'
            : 'low';

    return '''
        <tr class="duplicate-row" data-key="$keyName">
            <td>
                <div class="key-name-cell">
                    <span class="key-name">$keyName</span>
                    <span class="key-category">${_inferCategory(keyName, keyData.tags)}</span>
                </div>
            </td>
            <td>
                <span class="reference-count $impactClass">$refCount</span>
            </td>
            <td>
                <div class="locations-summary">
                    ${keyData.locations.take(2).map((loc) => '<div class="location-item">${loc.file}:${loc.line}</div>').join('')}
                    ${keyData.locations.length > 2 ? '<div class="more-locations">+${keyData.locations.length - 2} more</div>' : ''}
                </div>
            </td>
            <td>
                <span class="impact-badge $impactClass">$impact</span>
            </td>
            <td>
                <div class="duplicate-actions">
                    <button class="action-btn" title="View all locations" onclick="openLocationsModal('$keyName')">
                        <i class="fa-solid fa-map-pin"></i>
                    </button>
                    <button class="action-btn" title="Analyze duplicates" onclick="analyzeDuplicates('$keyName')">
                        <i class="fa-solid fa-magnifying-glass"></i>
                    </button>
                </div>
            </td>
        </tr>
    ''';
  }

  String _inferCategory(String keyName, Set<String> tags) {
    if (keyName.toLowerCase().contains('button') ||
        keyName.toLowerCase().contains('widget')) {
      return 'widget';
    }
    if (keyName.toLowerCase().contains('test')) return 'test';
    if (keyName.toLowerCase().contains('navigate') ||
        keyName.toLowerCase().contains('route')) {
      return 'navigation';
    }
    if (keyName.toLowerCase().contains('handle') ||
        keyName.toLowerCase().contains('on')) {
      return 'handler';
    }
    if (tags.contains('widget')) return 'widget';
    if (tags.contains('test')) return 'test';
    if (tags.contains('navigation')) return 'navigation';
    if (tags.contains('handler')) return 'handler';
    return 'widget'; // default
  }

  // Enhanced helper methods for advanced statistics
  String _getPerformanceTrend(int milliseconds) {
    if (milliseconds < 2000) return 'excellent';
    if (milliseconds < 5000) return 'good';
    if (milliseconds < 10000) return 'average';
    return 'poor';
  }

  String _getPerformanceTrendIcon(int milliseconds) {
    if (milliseconds < 2000) return 'fa-rocket';
    if (milliseconds < 5000) return 'fa-arrow-up';
    if (milliseconds < 10000) return 'fa-minus';
    return 'fa-arrow-down';
  }

  int _calculateEfficiency(ScanResult result) {
    final keysPerSecond =
        result.keyUsages.length / (result.duration.inMilliseconds / 1000.0);
    if (keysPerSecond > 20) return 95;
    if (keysPerSecond > 10) return 85;
    if (keysPerSecond > 5) return 75;
    return 60;
  }

  String _getEfficiencyTrend(ScanResult result) {
    final efficiency = _calculateEfficiency(result);
    if (efficiency > 90) return 'excellent';
    if (efficiency > 80) return 'good';
    if (efficiency > 70) return 'average';
    return 'poor';
  }

  String _getEfficiencyTrendIcon(ScanResult result) {
    final efficiency = _calculateEfficiency(result);
    if (efficiency > 90) return 'fa-star';
    if (efficiency > 80) return 'fa-arrow-up';
    if (efficiency > 70) return 'fa-minus';
    return 'fa-arrow-down';
  }

  int _calculateQualityScore(ScanResult result) {
    var score = 0;

    // Coverage score (40% of total)
    score += (result.metrics.fileCoverage * 0.4).round();

    // Key organization score (30% of total)
    final organizationScore = _calculateOrganization(result);
    score += (organizationScore * 0.3).round();

    // Consistency score (30% of total)
    final consistencyScore = _calculateConsistency(result);
    score += (consistencyScore * 0.3).round();

    return score.clamp(0, 100);
  }

  int _calculateConsistency(ScanResult result) {
    final keyNames = result.keyUsages.keys;
    var consistencyScore = 90;

    // Check naming conventions
    var hasUnderscore = false;
    var hasCamelCase = false;

    for (final name in keyNames) {
      if (name.contains('_')) hasUnderscore = true;
      if (RegExp(r'[a-z][A-Z]').hasMatch(name)) hasCamelCase = true;
    }

    if (hasUnderscore && hasCamelCase) {
      consistencyScore -= 20;
    }

    // Check for duplicate patterns
    final duplicates =
        result.keyUsages.values.where((k) => k.locations.length > 1).length;
    if (duplicates > result.keyUsages.length * 0.1) {
      consistencyScore -= 15;
    }

    return consistencyScore.clamp(0, 100);
  }

  int _calculateOrganization(ScanResult result) {
    final keyNames = result.keyUsages.keys;
    var organizationScore = 85;

    // Check for clear categorization
    final categories =
        keyNames.map((name) => _inferCategory(name, <String>{})).toSet();
    final categoryRatio = categories.length / keyNames.length;

    if (categoryRatio > 0.8) {
      organizationScore += 10; // Very diverse, good organization
    } else if (categoryRatio < 0.3) {
      organizationScore -= 10; // Too homogeneous, might lack structure
    }

    // Check for descriptive naming
    final descriptiveKeys = keyNames
        .where((name) => name.length > 3 && !name.startsWith('key'))
        .length;
    final descriptiveRatio = descriptiveKeys / keyNames.length;

    if (descriptiveRatio > 0.8) {
      organizationScore += 5;
    } else if (descriptiveRatio < 0.5) {
      organizationScore -= 10;
    }

    return organizationScore.clamp(0, 100);
  }

  String _buildDistributionLegend(ScanResult result) {
    final categories = <String, int>{};

    for (final keyName in result.keyUsages.keys) {
      final category = _inferCategory(keyName, <String>{});
      categories[category] = (categories[category] ?? 0) + 1;
    }

    final legendItems = categories.entries.map((entry) => '''
      <div class="legend-item">
        <div class="legend-color" style="background-color: ${_getCategoryColor(entry.key)}"></div>
        <span class="legend-label">${entry.key}</span>
        <span class="legend-count">${entry.value}</span>
      </div>
    ''').join('');

    return legendItems;
  }

  String _getCategoryColor(String category) {
    switch (category) {
      case 'Buttons':
        return '#3b82f6';
      case 'Input Fields':
        return '#10b981';
      case 'Navigation':
        return '#f59e0b';
      case 'Modals':
        return '#8b5cf6';
      case 'Lists':
        return '#ef4444';
      default:
        return '#6b7280';
    }
  }

  String _buildEnhancedInsights(ScanResult result) {
    final insights = <String>[];
    final coverage = result.metrics.fileCoverage;
    final totalKeys = result.keyUsages.length;
    final qualityScore = _calculateQualityScore(result);
    final duplicates =
        result.keyUsages.values.where((k) => k.locations.length > 1).length;

    // Priority insights with actionable recommendations
    if (coverage < 50) {
      insights.add('''
        <div class="insight critical">
          <i class="fa-solid fa-triangle-exclamation"></i>
          <div class="insight-content">
            <h4>Low Key Coverage</h4>
            <p>Only ${coverage.toStringAsFixed(1)}% of files have keys. Consider adding keys to critical UI components for better test automation.</p>
            <div class="action-items">
              <span class="action-item">• Focus on user interaction elements first</span>
              <span class="action-item">• Add keys to forms, buttons, and navigation elements</span>
              <span class="action-item">• Target 70%+ coverage for production apps</span>
            </div>
          </div>
        </div>
      ''');
    } else if (coverage > 90) {
      insights.add('''
        <div class="insight success">
          <i class="fa-solid fa-trophy"></i>
          <div class="insight-content">
            <h4>Outstanding Coverage!</h4>
            <p>${coverage.toStringAsFixed(1)}% file coverage indicates excellent test automation readiness.</p>
            <div class="action-items">
              <span class="action-item">✓ Maintain current coverage levels</span>
              <span class="action-item">✓ Document key naming conventions</span>
              <span class="action-item">✓ Consider implementing key usage guidelines</span>
            </div>
          </div>
        </div>
      ''');
    }

    if (qualityScore < 70) {
      insights.add('''
        <div class="insight warning">
          <i class="fa-solid fa-exclamation-triangle"></i>
          <div class="insight-content">
            <h4>Quality Improvement Needed</h4>
            <p>Quality score: $qualityScore%. Focus on consistency and organization.</p>
            <div class="action-items">
              <span class="action-item">• Establish consistent naming conventions</span>
              <span class="action-item">• Organize keys by feature or screen</span>
              <span class="action-item">• Review and eliminate duplicate keys</span>
            </div>
          </div>
        </div>
      ''');
    }

    if (duplicates > 5) {
      insights.add('''
        <div class="insight warning">
          <i class="fa-solid fa-copy"></i>
          <div class="insight-content">
            <h4>Duplicate Key Management</h4>
            <p>$duplicates keys have multiple references. Consider consolidating or documenting intentional duplicates.</p>
            <div class="action-items">
              <span class="action-item">• Review duplicate keys in Analysis section</span>
              <span class="action-item">• Consolidate unintentional duplicates</span>
              <span class="action-item">• Document legitimate duplicate usage</span>
            </div>
          </div>
        </div>
      ''');
    }

    if (totalKeys > 100) {
      insights.add('''
        <div class="insight info">
          <i class="fa-solid fa-layer-group"></i>
          <div class="insight-content">
            <h4>Large Scale Project</h4>
            <p>$totalKeys keys detected. Consider advanced organization strategies.</p>
            <div class="action-items">
              <span class="action-item">• Group keys by feature modules</span>
              <span class="action-item">• Implement key prefixing strategy</span>
              <span class="action-item">• Consider automated key generation tools</span>
            </div>
          </div>
        </div>
      ''');
    }

    // Performance insights
    final scanTimeSeconds = result.duration.inMilliseconds / 1000.0;
    if (scanTimeSeconds > 10) {
      insights.add('''
        <div class="insight warning">
          <i class="fa-solid fa-clock"></i>
          <div class="insight-content">
            <h4>Performance Optimization</h4>
            <p>Scan time: ${scanTimeSeconds.toStringAsFixed(2)}s. Consider performance optimizations.</p>
            <div class="action-items">
              <span class="action-item">• Exclude unnecessary directories from scanning</span>
              <span class="action-item">• Use .flutter_keycheck_ignore for large assets</span>
              <span class="action-item">• Consider incremental scanning for large projects</span>
            </div>
          </div>
        </div>
      ''');
    }

    if (insights.isEmpty) {
      insights.add('''
        <div class="insight success">
          <i class="fa-solid fa-star"></i>
          <div class="insight-content">
            <h4>Excellent Key Management</h4>
            <p>Your project demonstrates best practices in Flutter key usage.</p>
            <div class="action-items">
              <span class="action-item">✓ Continue monitoring key coverage</span>
              <span class="action-item">✓ Share best practices with your team</span>
              <span class="action-item">✓ Consider automated key validation in CI/CD</span>
            </div>
          </div>
        </div>
      ''');
    }

    return insights.join('\n');
  }
}
