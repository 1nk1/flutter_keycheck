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
        return HtmlReporter();
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

/// HTML reporter for rich web reports
class HtmlReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();
    
    // HTML header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>Flutter KeyCheck - Scan Report</title>');
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('  <script src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/js/all.min.js"></script>');
    buffer.writeln('  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>');
    buffer.writeln('  <link rel="preconnect" href="https://fonts.googleapis.com">');
    buffer.writeln('  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>');
    buffer.writeln('  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">');
    buffer.writeln(_getInlineStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body class="dark">');
    
    // Sidebar
    _addSidebar(buffer);
    
    // Header
    _addHeader(buffer);
    
    // Main Content with Sections
    buffer.writeln('  <div class="main-content">');
    
    // Dashboard Section (Default)
    buffer.writeln('    <div id="dashboard-section" class="content-section active">');
    _addDashboardHeader(buffer);
    _addMetricsCards(buffer, result);
    _addKeysTable(buffer, result);
    buffer.writeln('    </div>');
    
    // Analysis Section
    buffer.writeln('    <div id="analysis-section" class="content-section" style="display: none;">');
    _addAnalysisSection(buffer, result);
    buffer.writeln('    </div>');
    
    // Stats Section
    buffer.writeln('    <div id="stats-section" class="content-section" style="display: none;">');
    _addStatsSection(buffer, result);
    buffer.writeln('    </div>');
    
    // Export Section
    buffer.writeln('    <div id="export-section" class="content-section" style="display: none;">');
    _addExportSectionPage(buffer);
    buffer.writeln('    </div>');
    
    buffer.writeln('  </div>');
    
    // Location Modal
    _addLocationModal(buffer);
    
    // Keyboard shortcuts panel
    _addKeyboardShortcuts(buffer);
    
    // JavaScript
    _addJavaScriptData(buffer, result);
    
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    
    await outputFile.writeAsString(buffer.toString());
  }
  
  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    final buffer = StringBuffer();
    
    // HTML structure with premium dark theme
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <title>Flutter KeyCheck Validation Report</title>');
    buffer.writeln(_getInlineStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    
    final statusClass = result.hasViolations ? 'failed' : 'passed';
    buffer.writeln('<div class="container">');
    buffer.writeln('  <h1 class="$statusClass">Validation ${result.hasViolations ? 'Failed' : 'Passed'}</h1>');
    
    // Summary section with glassmorphism cards
    buffer.writeln('  <div class="summary">');
    buffer.writeln('    <div class="stat">');
    buffer.writeln('      <span class="label">Total Keys:</span>');
    buffer.writeln('      <span class="value">${result.summary.totalKeys}</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="stat">');
    buffer.writeln('      <span class="label">Lost Keys:</span>');
    buffer.writeln('      <span class="value">${result.summary.lostKeys}</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="stat">');
    buffer.writeln('      <span class="label">Added Keys:</span>');
    buffer.writeln('      <span class="value">${result.summary.addedKeys}</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="stat">');
    buffer.writeln('      <span class="label">Drift:</span>');
    buffer.writeln('      <span class="value">${result.summary.driftPercentage.toStringAsFixed(1)}%</span>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');
    
    // Violations section with premium styling
    if (result.hasViolations) {
      buffer.writeln('  <div class="violations">');
      buffer.writeln('    <h2>🚨 Critical Issues Found</h2>');
      
      if (result.violations.isNotEmpty) {
        buffer.writeln('    <table>');
        buffer.writeln('      <thead>');
        buffer.writeln('        <tr>');
        buffer.writeln('          <th>Type</th>');
        buffer.writeln('          <th>Key ID</th>');
        buffer.writeln('          <th>Package</th>');
        buffer.writeln('          <th>Tags</th>');
        buffer.writeln('          <th>Action Required</th>');
        buffer.writeln('        </tr>');
        buffer.writeln('      </thead>');
        buffer.writeln('      <tbody>');
        
        for (final violation in result.violations) {
          final icon = violation.type == 'lost'
              ? '🔥'
              : violation.type == 'renamed'
                  ? '♻️'
                  : violation.type == 'extra'
                      ? '➕'
                      : '⚠️';
          
          buffer.writeln('        <tr>');
          buffer.writeln('          <td>$icon ${violation.type}</td>');
          buffer.writeln('          <td><code>${violation.key?.id ?? 'N/A'}</code></td>');
          buffer.writeln('          <td>${violation.key?.package ?? 'N/A'}</td>');
          buffer.writeln('          <td>${violation.key?.tags.join(', ') ?? ''}</td>');
          buffer.writeln('          <td>${violation.remediation}</td>');
          buffer.writeln('        </tr>');
        }
        
        buffer.writeln('      </tbody>');
        buffer.writeln('    </table>');
      }
      
      // Legacy lost keys display for backward compatibility
      if (result.lostKeys.isNotEmpty) {
        buffer.writeln('    <h2>🔥 Lost Keys (${result.lostKeys.length})</h2>');
        buffer.writeln('    <ul>');
        for (final key in result.lostKeys) {
          buffer.writeln('      <li><code>${key.id}</code> - Package: ${key.package}</li>');
        }
        buffer.writeln('    </ul>');
      }
      
      buffer.writeln('  </div>');
    } else {
      // Success message with green glassmorphism styling
      buffer.writeln('  <div class="stat" style="background: rgba(52, 211, 153, 0.1); border-color: rgba(52, 211, 153, 0.2); margin: 2rem 0;">');
      buffer.writeln('    <span class="label">✅ Validation Status</span>');
      buffer.writeln('    <span class="value" style="color: #34d399;">All Good!</span>');
      buffer.writeln('  </div>');
    }
    
    // Warnings section
    if (result.warnings.isNotEmpty) {
      buffer.writeln('  <h2>⚠️ Warnings</h2>');
      buffer.writeln('  <ul>');
      for (final warning in result.warnings) {
        buffer.writeln('    <li>$warning</li>');
      }
      buffer.writeln('  </ul>');
    }
    
    // Scanned packages section
    if (result.summary.scannedPackages.isNotEmpty) {
      buffer.writeln('  <h2>📦 Scanned Packages</h2>');
      buffer.writeln('  <table>');
      buffer.writeln('    <thead>');
      buffer.writeln('      <tr>');
      buffer.writeln('        <th>Package</th>');
      buffer.writeln('        <th>Status</th>');
      buffer.writeln('      </tr>');
      buffer.writeln('    </thead>');
      buffer.writeln('    <tbody>');
      for (final package in result.summary.scannedPackages) {
        buffer.writeln('      <tr>');
        buffer.writeln('        <td><code>$package</code></td>');
        buffer.writeln('        <td>✅ Scanned</td>');
        buffer.writeln('      </tr>');
      }
      buffer.writeln('    </tbody>');
      buffer.writeln('  </table>');
    }
    
    buffer.writeln('</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    
    await outputFile.writeAsString(buffer.toString());
  }
  
  String _getInlineStyles() {
    return '''
    <style>
      /* Force Dark Theme for Entire Document */
      * {
        color-scheme: dark;
      }
      
      body {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: linear-gradient(135deg, #0c0f1a 0%, #1a1f35 100%);
        color: #e2e8f0;
        margin: 0;
        padding: 0;
        min-height: 100vh;
        overflow-x: hidden;
      }
      
      /* Dark Theme Layout */
      .sidebar {
        position: fixed;
        left: 0;
        top: 0;
        width: 80px;
        height: 100vh;
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(20px);
        border-right: 1px solid rgba(51, 65, 85, 0.3);
        z-index: 1000;
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 20px 12px;
      }
      
      .sidebar-header {
        margin-bottom: 30px;
      }
      
      .sidebar-logo {
        width: 40px;
        height: 40px;
        background: linear-gradient(135deg, #3b82f6, #1e40af);
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      .sidebar-nav {
        display: flex;
        flex-direction: column;
        gap: 15px;
        width: 100%;
        align-items: center;
      }
      
      .sidebar-nav-item {
        width: 50px;
        height: 50px;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(51, 65, 85, 0.3);
        color: #94a3b8;
        cursor: pointer;
        transition: all 0.2s ease;
        border: 1px solid rgba(51, 65, 85, 0.5);
        margin: 8px 0;
      }
      
      .sidebar-nav-item:hover, .sidebar-nav-item.active {
        background: rgba(59, 130, 246, 0.2);
        color: #60a5fa;
        border-color: rgba(59, 130, 246, 0.5);
      }
      
      .header {
        position: fixed;
        top: 0;
        left: 80px;
        right: 0;
        height: 60px;
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(20px);
        border-bottom: 1px solid rgba(51, 65, 85, 0.3);
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 30px;
        z-index: 999;
      }
      
      .header-left {
        display: flex;
        align-items: center;
        gap: 20px;
      }
      
      .brand {
        display: flex;
        align-items: center;
        gap: 4px;
        font-size: 20px;
        font-weight: 700;
      }
      
      .brand-flutter {
        color: #60a5fa;
      }
      
      .brand-keycheck {
        color: #e2e8f0;
      }
      
      .brand-separator {
        color: #475569;
        margin: 0 10px;
      }
      
      .page-title {
        color: #cbd5e1;
        font-size: 18px;
        font-weight: 500;
      }
      
      .header-right {
        display: flex;
        gap: 12px;
      }
      
      .header-btn {
        padding: 8px 16px;
        background: rgba(51, 65, 85, 0.5);
        border: 1px solid rgba(51, 65, 85, 0.7);
        border-radius: 8px;
        color: #cbd5e1;
        cursor: pointer;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 14px;
      }
      
      .header-btn:hover {
        background: rgba(51, 65, 85, 0.8);
        border-color: rgba(59, 130, 246, 0.5);
      }
      
      .main-content {
        margin-left: 80px;
        margin-top: 60px;
        padding: 30px;
        min-height: calc(100vh - 60px);
      }
      
      .content-section {
        max-width: 1400px;
        margin: 0 auto;
        animation: fadeIn 0.3s ease-in-out;
      }
      
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
      }
      
      .dashboard-header {
        background: rgba(30, 41, 59, 0.4);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(51, 65, 85, 0.3);
        border-radius: 16px;
        padding: 30px;
        margin-bottom: 30px;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      
      .dashboard-title-section h2 {
        color: #f1f5f9;
        font-size: 28px;
        font-weight: 700;
        margin: 0 0 8px 0;
      }
      
      .dashboard-subtitle {
        color: #94a3b8;
        font-size: 16px;
        margin: 0;
      }
      
      .last-updated {
        color: #64748b;
        font-size: 14px;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .last-updated-time {
        color: #94a3b8;
        font-weight: 500;
      }
      
      .metrics-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 20px;
        margin-bottom: 30px;
      }
      
      .metric-card, .glass-card {
        background: rgba(30, 41, 59, 0.4);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(51, 65, 85, 0.3);
        border-radius: 16px;
        padding: 24px;
        transition: all 0.2s ease;
      }
      
      .metric-card:hover, .glass-card:hover {
        border-color: rgba(59, 130, 246, 0.4);
        transform: translateY(-2px);
      }
      
      .export-btn {
        position: relative;
        overflow: hidden;
      }
      
      .export-btn:hover {
        background: rgba(30, 41, 59, 0.6);
        transform: translateY(-3px);
        box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
      }
      
      .export-btn:active {
        transform: translateY(-1px);
        transition: all 0.1s ease;
      }
      
      .metric-header {
        display: flex;
        align-items: center;
        gap: 16px;
        margin-bottom: 16px;
      }
      
      .metric-icon {
        width: 48px;
        height: 48px;
        border-radius: 12px;
        background: rgba(59, 130, 246, 0.1);
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      .metric-info h3 {
        color: #cbd5e1;
        font-size: 14px;
        font-weight: 500;
        margin: 0 0 4px 0;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }
      
      .metric-value {
        color: #f1f5f9;
        font-size: 28px;
        font-weight: 700;
        margin: 0;
      }
      
      .metric-footer {
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      
      .metric-label {
        color: #64748b;
        font-size: 12px;
      }
      
      .metric-change {
        font-size: 12px;
        font-weight: 600;
        display: flex;
        align-items: center;
        gap: 4px;
      }
      
      .metric-change.positive { color: #10b981; }
      .metric-change.negative { color: #ef4444; }
      
      .keys-section {
        background: rgba(30, 41, 59, 0.4);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(51, 65, 85, 0.3);
        border-radius: 16px;
        padding: 30px;
        margin-bottom: 30px;
      }
      
      .keys-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 24px;
        flex-wrap: wrap;
        gap: 16px;
      }
      
      .keys-title {
        color: #f1f5f9;
        font-size: 20px;
        font-weight: 600;
        margin: 0;
      }
      
      .keys-controls {
        display: flex;
        gap: 12px;
        align-items: center;
      }
      
      .search-container, .filter-container {
        position: relative;
      }
      
      .search-input, .filter-select {
        background: rgba(51, 65, 85, 0.5);
        border: 1px solid rgba(51, 65, 85, 0.7);
        border-radius: 8px;
        padding: 10px 16px;
        color: #e2e8f0;
        font-size: 14px;
        min-width: 160px;
      }
      
      .search-input {
        padding-left: 40px; /* Make room for search icon */
      }
      
      .search-icon {
        position: absolute;
        left: 12px;
        top: 50%;
        transform: translateY(-50%);
        color: #64748b;
        font-size: 14px;
        pointer-events: none;
      }
      
      .filter-select {
        appearance: none !important; /* Remove default dropdown arrow */
        -webkit-appearance: none !important;
        -moz-appearance: none !important;
        background-image: none !important;
        background-repeat: no-repeat !important;
        background-position: right 12px center !important;
        background-size: 0 !important;
        cursor: pointer;
      }
      
      .filter-select::-ms-expand {
        display: none; /* Remove arrow in IE */
      }
      
      .search-input:focus, .filter-select:focus {
        outline: none;
        border-color: rgba(59, 130, 246, 0.5);
        background: rgba(51, 65, 85, 0.7);
      }
      
      .search-input::placeholder {
        color: #64748b;
      }
      
      .keys-table-container {
        border-radius: 12px;
        overflow: hidden;
        border: 1px solid rgba(51, 65, 85, 0.3);
      }
      
      .keys-table {
        width: 100%;
        border-collapse: collapse;
      }
      
      .keys-table thead {
        background: rgba(15, 23, 42, 0.8);
      }
      
      .keys-table th {
        padding: 16px 20px;
        text-align: left;
        font-weight: 600;
        color: #cbd5e1;
        font-size: 14px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        border-bottom: 1px solid rgba(51, 65, 85, 0.5);
      }
      
      .keys-table tbody tr {
        background: rgba(30, 41, 59, 0.2);
        border-bottom: 1px solid rgba(51, 65, 85, 0.2);
        transition: all 0.2s ease;
      }
      
      .keys-table tbody tr:hover {
        background: rgba(59, 130, 246, 0.05);
        border-color: rgba(59, 130, 246, 0.2);
      }
      
      .keys-table td {
        padding: 16px 20px;
        color: #e2e8f0;
      }
      
      .key-name {
        font-family: 'JetBrains Mono', 'Fira Code', monospace;
        color: #f1f5f9;
        font-weight: 500;
      }
      
      .category-container {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .category-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
      }
      
      .category-dot.widget { background: #3b82f6; }
      .category-dot.handler { background: #f59e0b; }
      .category-dot.test { background: #10b981; }
      .category-dot.navigation { background: #8b5cf6; }
      
      .category-label {
        color: #cbd5e1;
        font-size: 14px;
        font-weight: 500;
      }
      
      .category-icon {
        font-size: 12px;
        margin-left: 4px;
      }
      
      .category-icon.widget { color: #3b82f6; }
      .category-icon.handler { color: #f59e0b; }
      .category-icon.test { color: #10b981; }
      .category-icon.navigation { color: #8b5cf6; }
      
      .status-badge {
        padding: 6px 12px;
        border-radius: 6px;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        border: 1px solid;
      }
      
      .status-badge.active {
        background: rgba(16, 185, 129, 0.1);
        color: #10b981;
        border-color: rgba(16, 185, 129, 0.3);
      }
      
      .status-badge.inactive {
        background: rgba(156, 163, 175, 0.1);
        color: #9ca3af;
        border-color: rgba(156, 163, 175, 0.3);
      }
      
      .locations-btn {
        background: rgba(59, 130, 246, 0.1);
        border: 1px solid rgba(59, 130, 246, 0.3);
        color: #60a5fa;
        padding: 8px 12px;
        border-radius: 6px;
        cursor: pointer;
        font-size: 12px;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 6px;
        transition: all 0.2s ease;
      }
      
      .locations-btn:hover {
        background: rgba(59, 130, 246, 0.2);
        border-color: rgba(59, 130, 246, 0.5);
      }
      
      .no-locations {
        color: #64748b;
        font-style: italic;
        font-size: 14px;
      }
      
      .action-buttons {
        display: flex;
        gap: 8px;
      }
      
      .action-btn {
        width: 32px;
        height: 32px;
        background: rgba(51, 65, 85, 0.5);
        border: 1px solid rgba(51, 65, 85, 0.7);
        border-radius: 6px;
        color: #94a3b8;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
      }
      
      .action-btn:hover {
        background: rgba(59, 130, 246, 0.2);
        border-color: rgba(59, 130, 246, 0.5);
        color: #60a5fa;
      }
      
      .pagination {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-top: 24px;
        padding-top: 24px;
        border-top: 1px solid rgba(51, 65, 85, 0.3);
      }
      
      .pagination-info {
        color: #64748b;
        font-size: 14px;
      }
      
      .pagination-info-highlight {
        color: #e2e8f0;
        font-weight: 600;
      }
      
      .pagination-controls {
        display: flex;
        gap: 8px;
      }
      
      .pagination-btn {
        width: 36px;
        height: 36px;
        background: rgba(51, 65, 85, 0.5);
        border: 1px solid rgba(51, 65, 85, 0.7);
        border-radius: 6px;
        color: #94a3b8;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
        font-size: 14px;
      }
      
      .pagination-btn:hover:not(:disabled) {
        background: rgba(59, 130, 246, 0.2);
        border-color: rgba(59, 130, 246, 0.5);
        color: #60a5fa;
      }
      
      .pagination-btn.active {
        background: rgba(59, 130, 246, 0.3);
        border-color: rgba(59, 130, 246, 0.6);
        color: #f1f5f9;
      }
      
      .pagination-btn:disabled {
        opacity: 0.4;
        cursor: not-allowed;
      }
      
      /* Duplicate Keys Table Styles */
      .duplicate-keys-section {
        margin-top: 32px;
      }
      
      .duplicate-keys-section .section-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 20px;
        padding-bottom: 16px;
        border-bottom: 1px solid rgba(51, 65, 85, 0.3);
      }
      
      .duplicate-keys-section h3 {
        color: #f1f5f9;
        font-size: 18px;
        margin: 0;
      }
      
      .duplicate-count {
        background: rgba(251, 146, 60, 0.2);
        color: #fb923c;
        padding: 4px 8px;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
      }
      
      .duplicate-keys-table-container {
        overflow-x: auto;
      }
      
      .duplicate-keys-table {
        width: 100%;
        border-collapse: collapse;
        background: rgba(30, 41, 59, 0.5);
        border-radius: 8px;
        overflow: hidden;
      }
      
      .duplicate-keys-table thead {
        background: rgba(51, 65, 85, 0.7);
      }
      
      .duplicate-keys-table th {
        padding: 16px 20px;
        text-align: left;
        font-weight: 600;
        color: #f1f5f9;
        font-size: 14px;
        border-bottom: 1px solid rgba(51, 65, 85, 0.5);
      }
      
      .duplicate-keys-table tbody tr {
        border-bottom: 1px solid rgba(51, 65, 85, 0.2);
        transition: background-color 0.2s ease;
      }
      
      .duplicate-keys-table tbody tr:hover {
        background: rgba(51, 65, 85, 0.3);
      }
      
      .duplicate-keys-table td {
        padding: 16px 20px;
        color: #e2e8f0;
        vertical-align: top;
      }
      
      .key-name-cell {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }
      
      .key-name-cell .key-name {
        font-family: 'JetBrains Mono', 'Fira Code', monospace;
        color: #f1f5f9;
        font-weight: 500;
      }
      
      .key-name-cell .key-category {
        font-size: 12px;
        color: #64748b;
      }
      
      .reference-count {
        font-weight: 600;
        padding: 4px 8px;
        border-radius: 4px;
        font-size: 12px;
      }
      
      .reference-count.low {
        background: rgba(34, 197, 94, 0.2);
        color: #22c55e;
      }
      
      .reference-count.medium {
        background: rgba(251, 146, 60, 0.2);
        color: #fb923c;
      }
      
      .reference-count.high {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
      }
      
      .locations-summary {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }
      
      .location-item {
        font-family: 'JetBrains Mono', 'Fira Code', monospace;
        font-size: 12px;
        color: #94a3b8;
        background: rgba(51, 65, 85, 0.3);
        padding: 2px 6px;
        border-radius: 3px;
        display: inline-block;
        max-width: fit-content;
      }
      
      .more-locations {
        font-size: 12px;
        color: #64748b;
        font-style: italic;
        margin-top: 2px;
      }
      
      .impact-badge {
        font-weight: 500;
        padding: 4px 8px;
        border-radius: 4px;
        font-size: 12px;
        text-transform: uppercase;
      }
      
      .impact-badge.low {
        background: rgba(34, 197, 94, 0.2);
        color: #22c55e;
      }
      
      .impact-badge.medium {
        background: rgba(251, 146, 60, 0.2);
        color: #fb923c;
      }
      
      .impact-badge.high {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
      }
      
      .duplicate-actions {
        display: flex;
        gap: 8px;
      }
      
      /* Modal Styles */
      .modal {
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: rgba(0, 0, 0, 0.8);
        backdrop-filter: blur(8px);
        display: none;
        align-items: center;
        justify-content: center;
        z-index: 10000;
      }
      
      .modal-container {
        max-width: 80vw;
        max-height: 80vh;
        width: 900px;
      }
      
      .modal-content {
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(51, 65, 85, 0.5);
        border-radius: 16px;
        overflow: hidden;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        max-width: 90vw;
        width: 900px;
      }
      
      .modal-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 24px 30px;
        border-bottom: 1px solid rgba(51, 65, 85, 0.3);
        background: rgba(30, 41, 59, 0.5);
      }
      
      .modal-title {
        color: #f1f5f9;
        font-size: 16px;
        font-weight: 600;
        margin: 0;
        max-width: 70%;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      
      .close-btn {
        width: 36px;
        height: 36px;
        background: rgba(51, 65, 85, 0.5);
        border: 1px solid rgba(51, 65, 85, 0.7);
        border-radius: 8px;
        color: #94a3b8;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
      }
      
      .close-btn:hover {
        background: rgba(239, 68, 68, 0.2);
        border-color: rgba(239, 68, 68, 0.5);
        color: #f87171;
      }
      
      .modal-body {
        padding: 24px 30px;
        max-height: 60vh;
        overflow-y: auto;
      }
      
      .location-item {
        background: rgba(30, 41, 59, 0.3);
        border: 1px solid rgba(51, 65, 85, 0.3);
        border-radius: 12px;
        margin-bottom: 16px;
        overflow: hidden;
      }
      
      .location-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16px 20px;
        background: rgba(15, 23, 42, 0.6);
        border-bottom: 1px solid rgba(51, 65, 85, 0.2);
      }
      
      .location-info {
        display: flex;
        flex-direction: column;
        gap: 6px;
      }
      
      .file-info {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .file-icon {
        color: #60a5fa;
      }
      
      .file-path {
        font-family: 'JetBrains Mono', 'Fira Code', monospace;
        color: #f1f5f9;
        font-weight: 500;
        font-size: 14px;
      }
      
      .line-info {
        color: #64748b;
        font-size: 12px;
      }
      
      .location-btn {
        background: rgba(59, 130, 246, 0.1);
        border: 1px solid rgba(59, 130, 246, 0.3);
        color: #60a5fa;
        padding: 6px 12px;
        border-radius: 6px;
        cursor: pointer;
        font-size: 12px;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 6px;
        transition: all 0.2s ease;
      }
      
      .location-btn:hover {
        background: rgba(59, 130, 246, 0.2);
        border-color: rgba(59, 130, 246, 0.5);
      }
      
      .code-container {
        background: rgba(7, 10, 18, 0.8);
        border-top: 1px solid rgba(51, 65, 85, 0.2);
        font-family: 'JetBrains Mono', 'Fira Code', monospace;
        font-size: 13px;
        line-height: 1.5;
        overflow-x: auto;
      }
      
      .code-line {
        display: flex;
        padding: 0 16px;
        min-height: 24px;
        align-items: center;
      }
      
      .code-line.highlighted-line {
        background: rgba(59, 130, 246, 0.1);
        border-left: 3px solid #3b82f6;
      }
      
      .code-line-number {
        width: 40px;
        color: #64748b;
        font-size: 11px;
        margin-right: 16px;
        text-align: right;
        flex-shrink: 0;
        user-select: none;
      }
      
      .highlighted-key {
        background: rgba(245, 158, 11, 0.3);
        color: #fbbf24;
        padding: 2px 4px;
        border-radius: 4px;
        font-weight: 600;
      }
      
      /* Enhanced Code syntax highlighting for Dart/Flutter - Material Theme */
      .dart-keyword { 
        color: #c792ea; 
        font-weight: 700; 
        text-shadow: 0 0 2px rgba(199, 146, 234, 0.3);
      }
      .dart-type { 
        color: #82aaff; 
        font-weight: 600;
        text-shadow: 0 0 2px rgba(130, 170, 255, 0.3);
      }
      .dart-function { 
        color: #82d4ff; 
        font-weight: 500; 
        text-decoration: none;
      }
      .dart-function:hover { 
        color: #a5e3ff; 
        text-decoration: underline;
        cursor: pointer;
      }
      .dart-string { 
        color: #c3e88d; 
        font-weight: 400;
        background: rgba(195, 232, 141, 0.1);
        padding: 1px 2px;
        border-radius: 2px;
      }
      .dart-comment { 
        color: #546e7a; 
        font-style: italic; 
        opacity: 0.85;
        background: rgba(84, 110, 122, 0.08);
        padding: 1px 3px;
        border-radius: 3px;
      }
      .dart-number { 
        color: #f78c6c; 
        font-weight: 500;
        background: rgba(247, 140, 108, 0.15);
        padding: 1px 3px;
        border-radius: 2px;
      }
      .dart-operator { 
        color: #89ddff; 
        font-weight: 600;
        text-shadow: 0 0 2px rgba(137, 221, 255, 0.4);
      }
      .punctuation { 
        color: #89ddff; 
        opacity: 0.8;
      }
      .dart-variable { 
        color: #eeffff; 
        font-weight: 400;
      }
      .dart-annotation { 
        color: #ffcb6b; 
        font-weight: 600;
        background: rgba(255, 203, 107, 0.15);
        padding: 1px 4px;
        border-radius: 3px;
        border: 1px solid rgba(255, 203, 107, 0.3);
      }
      
      /* Better code container styling */
      .code-container {
        background: linear-gradient(135deg, rgba(7, 10, 18, 0.95), rgba(15, 20, 30, 0.9));
        border-top: 1px solid rgba(51, 65, 85, 0.3);
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Consolas, monospace;
        font-size: 13px;
        line-height: 1.6;
        overflow-x: auto;
        border-radius: 0 0 12px 12px;
      }
      
      .code-line {
        display: flex;
        padding: 4px 20px;
        min-height: 22px;
        align-items: flex-start;
        transition: background-color 0.1s ease;
      }
      
      .code-line:hover {
        background: rgba(59, 130, 246, 0.05);
      }
      
      .code-line.highlighted-line {
        background: linear-gradient(90deg, rgba(59, 130, 246, 0.15), rgba(59, 130, 246, 0.05));
        border-left: 3px solid #3b82f6;
        padding-left: 13px;
      }
      
      .code-line-number {
        width: 45px;
        color: #64748b;
        font-size: 11px;
        margin-right: 20px;
        text-align: right;
        flex-shrink: 0;
        user-select: none;
        font-weight: 500;
        line-height: 1.6;
        padding-top: 1px;
      }
      
      .highlighted-line .code-line-number {
        color: #60a5fa;
        font-weight: 600;
      }
      
      /* Glassmorphism effects */
      .glass-morphism {
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
      }
      
      /* Custom animations */
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
      }
      
      .animate-fade-in {
        animation: fadeIn 0.3s ease-out;
      }
      
      /* Custom scrollbar for dark theme */
      .custom-scrollbar::-webkit-scrollbar {
        width: 6px;
      }
      
      .custom-scrollbar::-webkit-scrollbar-track {
        background: rgba(51, 65, 85, 0.3);
        border-radius: 3px;
      }
      
      .custom-scrollbar::-webkit-scrollbar-thumb {
        background: rgba(148, 163, 184, 0.5);
        border-radius: 3px;
      }
      
      .custom-scrollbar::-webkit-scrollbar-thumb:hover {
        background: rgba(148, 163, 184, 0.7);
      }
      
      /* Enhanced code container with header */
      .code-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 8px 16px;
        background: linear-gradient(90deg, rgba(51, 65, 85, 0.8), rgba(30, 41, 59, 0.6));
        border-bottom: 1px solid rgba(51, 65, 85, 0.4);
        font-size: 12px;
        color: #94a3b8;
        border-radius: 6px 6px 0 0;
      }
      
      .code-language {
        font-weight: 600;
        color: #60a5fa;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }
      
      .code-copy-btn {
        background: rgba(59, 130, 246, 0.1);
        border: 1px solid rgba(59, 130, 246, 0.3);
        border-radius: 4px;
        color: #60a5fa;
        padding: 4px 8px;
        cursor: pointer;
        font-size: 11px;
        transition: all 0.2s ease;
      }
      
      .code-copy-btn:hover {
        background: rgba(59, 130, 246, 0.2);
        border-color: rgba(59, 130, 246, 0.5);
        color: #93c5fd;
        transform: translateY(-1px);
      }
      
      .code-copy-btn.copied {
        background: rgba(34, 197, 94, 0.2);
        border-color: rgba(34, 197, 94, 0.5);
        color: #4ade80;
      }
      
      /* Enhanced location buttons */
      .location-btn.secondary {
        background: rgba(75, 85, 99, 0.4);
        border-color: rgba(75, 85, 99, 0.6);
        color: #9ca3af;
      }
      
      .location-btn.secondary:hover {
        background: rgba(75, 85, 99, 0.6);
        border-color: rgba(75, 85, 99, 0.8);
        color: #d1d5db;
      }
      
      .location-actions {
        display: flex;
        gap: 8px;
        align-items: center;
      }
      
      .detector-info {
        background: rgba(99, 102, 241, 0.15);
        color: #a5b4fc;
        padding: 2px 6px;
        border-radius: 3px;
        font-size: 10px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }
      
      /* Toast notifications */
      .toast {
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 10000;
        padding: 12px 20px;
        border-radius: 6px;
        color: white;
        font-weight: 500;
        font-size: 14px;
        transform: translateX(400px);
        transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
        backdrop-filter: blur(10px);
        -webkit-backdrop-filter: blur(10px);
        box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
      }
      
      .toast.show {
        transform: translateX(0);
      }
      
      .toast-success {
        background: linear-gradient(135deg, rgba(34, 197, 94, 0.9), rgba(21, 128, 61, 0.9));
        border: 1px solid rgba(34, 197, 94, 0.3);
      }
      
      .toast-error {
        background: linear-gradient(135deg, rgba(239, 68, 68, 0.9), rgba(185, 28, 28, 0.9));
        border: 1px solid rgba(239, 68, 68, 0.3);
      }
      
      .toast-info {
        background: linear-gradient(135deg, rgba(59, 130, 246, 0.9), rgba(37, 99, 235, 0.9));
        border: 1px solid rgba(59, 130, 246, 0.3);
      }
      
      /* Keyboard shortcuts */
      .keyboard-shortcuts {
        position: fixed;
        bottom: 20px;
        left: 20px;
        background: rgba(15, 23, 42, 0.9);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(51, 65, 85, 0.3);
        border-radius: 8px;
        padding: 12px 16px;
        color: #94a3b8;
        font-size: 12px;
        z-index: 1000;
        opacity: 0.7;
        transition: opacity 0.2s ease;
      }
      
      .keyboard-shortcuts:hover {
        opacity: 1;
      }
      
      .keyboard-shortcut {
        display: flex;
        justify-content: space-between;
        margin: 2px 0;
        min-width: 200px;
      }
      
      .shortcut-key {
        background: rgba(51, 65, 85, 0.8);
        padding: 2px 6px;
        border-radius: 3px;
        font-family: monospace;
        font-size: 11px;
        color: #e2e8f0;
      }

      /* Section Headers */
      .section-header {
        margin-bottom: 32px;
        padding: 24px 32px;
        border-radius: 16px;
      }
      
      .section-title-wrapper {
        display: flex;
        align-items: center;
        gap: 16px;
      }
      
      .section-icon {
        width: 48px;
        height: 48px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(59, 130, 246, 0.1);
        border-radius: 12px;
        color: #60a5fa;
        font-size: 20px;
      }
      
      .section-title-content h2 {
        margin: 0 0 8px 0;
        font-size: 28px;
        font-weight: 700;
        color: #e2e8f0;
      }
      
      .section-subtitle {
        margin: 0;
        color: #94a3b8;
        font-size: 16px;
      }

      /* Analysis Section */
      .analysis-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
        gap: 24px;
        margin-bottom: 32px;
      }
      
      .analysis-card {
        padding: 24px;
        border-radius: 16px;
      }
      
      .analysis-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 20px;
      }
      
      .analysis-header h3 {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
        color: #e2e8f0;
      }
      
      .quality-score {
        display: flex;
        align-items: center;
        gap: 20px;
      }
      
      .score-circle {
        width: 80px;
        height: 80px;
        border-radius: 50%;
        background: conic-gradient(from 0deg, #10b981 0deg, #10b981 calc(var(--percentage, 75) * 3.6deg), rgba(51, 65, 85, 0.3) calc(var(--percentage, 75) * 3.6deg));
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
      }
      
      .score-circle::before {
        content: '';
        position: absolute;
        width: 60px;
        height: 60px;
        background: #1e293b;
        border-radius: 50%;
      }
      
      .score-text {
        position: relative;
        z-index: 1;
        font-size: 18px;
        font-weight: 700;
        color: #10b981;
      }
      
      .score-details {
        flex: 1;
      }
      
      .score-item {
        display: flex;
        justify-content: space-between;
        margin-bottom: 8px;
      }
      
      .score-item .label {
        color: #94a3b8;
        font-size: 14px;
      }
      
      .score-item .value {
        font-weight: 600;
        font-size: 14px;
      }
      
      .distribution-items {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .distribution-item {
        display: grid;
        grid-template-columns: 1fr 80px 40px;
        align-items: center;
        gap: 12px;
      }
      
      .category-info {
        display: flex;
        flex-direction: column;
      }
      
      .category-name {
        color: #e2e8f0;
        font-size: 14px;
        font-weight: 500;
      }
      
      .category-count {
        color: #64748b;
        font-size: 12px;
      }
      
      .category-bar {
        height: 8px;
        background: rgba(51, 65, 85, 0.3);
        border-radius: 4px;
        overflow: hidden;
      }
      
      .bar-fill {
        height: 100%;
        background: linear-gradient(90deg, #60a5fa, #3b82f6);
        transition: width 0.3s ease;
      }
      
      .category-percentage {
        text-align: right;
        color: #60a5fa;
        font-size: 12px;
        font-weight: 600;
      }
      
      .issues-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .issue-item {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px 16px;
        border-radius: 8px;
      }
      
      .issue-item.critical {
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.3);
      }
      
      .issue-item.warning {
        background: rgba(245, 158, 11, 0.1);
        border: 1px solid rgba(245, 158, 11, 0.3);
      }
      
      .issue-item.resolved {
        background: rgba(16, 185, 129, 0.1);
        border: 1px solid rgba(16, 185, 129, 0.3);
      }
      
      .issue-text {
        flex: 1;
        color: #e2e8f0;
        font-size: 14px;
      }
      
      .issue-severity {
        font-size: 12px;
        font-weight: 600;
        padding: 4px 8px;
        border-radius: 4px;
      }
      
      .critical .issue-severity { background: rgba(239, 68, 68, 0.2); color: #ef4444; }
      .warning .issue-severity { background: rgba(245, 158, 11, 0.2); color: #f59e0b; }
      .resolved .issue-severity { background: rgba(16, 185, 129, 0.2); color: #10b981; }

      /* Stats Section */
      .stats-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 24px;
        margin-bottom: 32px;
      }
      
      .stats-card {
        padding: 24px;
        border-radius: 16px;
      }
      
      .stats-card.full-width {
        grid-column: 1 / -1;
      }
      
      .stats-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 20px;
      }
      
      .stats-header h3 {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
        color: #e2e8f0;
      }
      
      .coverage-visual {
        display: flex;
        justify-content: center;
        margin-bottom: 20px;
      }
      
      .coverage-circle {
        width: 120px;
        height: 120px;
        border-radius: 50%;
        background: conic-gradient(from 0deg, #3b82f6 0deg, #3b82f6 calc(var(--percentage, 0) * 3.6deg), rgba(51, 65, 85, 0.3) calc(var(--percentage, 0) * 3.6deg));
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
      }
      
      .coverage-circle::before {
        content: '';
        position: absolute;
        width: 90px;
        height: 90px;
        background: #1e293b;
        border-radius: 50%;
      }
      
      .coverage-text {
        position: relative;
        z-index: 1;
        font-size: 24px;
        font-weight: 700;
        color: #3b82f6;
      }
      
      .coverage-details, .performance-metrics {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .detail-item, .metric-row {
        display: flex;
        justify-content: space-between;
      }
      
      /* Enhanced Performance Metrics */
      .performance-visual {
        display: flex;
        justify-content: center;
        margin-bottom: 16px;
      }
      
      .metric-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
      }
      
      .metric-item {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
        padding: 8px;
        border-radius: 8px;
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid rgba(255, 255, 255, 0.05);
      }
      
      .metric-label {
        font-size: 0.75rem;
        color: #9CA3AF;
        text-align: center;
      }
      
      .metric-value {
        font-size: 1.1rem;
        font-weight: 600;
        color: white;
      }
      
      .metric-trend {
        font-size: 0.8rem;
        padding: 2px 4px;
        border-radius: 4px;
      }
      
      .metric-trend.excellent {
        color: #10B981;
        background: rgba(16, 185, 129, 0.1);
      }
      
      .metric-trend.good {
        color: #3B82F6;
        background: rgba(59, 130, 246, 0.1);
      }
      
      .metric-trend.average {
        color: #F59E0B;
        background: rgba(245, 158, 11, 0.1);
      }
      
      .metric-trend.poor {
        color: #EF4444;
        background: rgba(239, 68, 68, 0.1);
      }
      
      /* Distribution Chart Styles */
      .distribution-content {
        display: flex;
        gap: 16px;
        align-items: center;
      }
      
      .distribution-visual {
        flex-shrink: 0;
      }
      
      .distribution-legend {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      
      .legend-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 4px 0;
      }
      
      .legend-color {
        width: 12px;
        height: 12px;
        border-radius: 2px;
        flex-shrink: 0;
      }
      
      .legend-label {
        flex: 1;
        font-size: 0.875rem;
        color: #E5E7EB;
      }
      
      .legend-count {
        font-size: 0.875rem;
        font-weight: 600;
        color: white;
        min-width: 20px;
        text-align: right;
      }
      
      /* Quality Score Styles */
      .quality-metrics {
        display: flex;
        gap: 20px;
        align-items: center;
      }
      
      .quality-score {
        flex-shrink: 0;
      }
      
      .score-circle {
        width: 120px;
        height: 120px;
        border-radius: 50%;
        background: conic-gradient(
          from 0deg,
          #3B82F6 0deg,
          #3B82F6 calc(var(--score) * 3.6deg),
          rgba(255, 255, 255, 0.1) calc(var(--score) * 3.6deg),
          rgba(255, 255, 255, 0.1) 360deg
        );
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        position: relative;
      }
      
      .score-circle::before {
        content: '';
        position: absolute;
        width: 90px;
        height: 90px;
        border-radius: 50%;
        background: #1F2937;
      }
      
      .score-text {
        font-size: 1.5rem;
        font-weight: 700;
        color: white;
        z-index: 1;
      }
      
      .score-label {
        font-size: 0.75rem;
        color: #9CA3AF;
        z-index: 1;
      }
      
      .quality-breakdown {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .quality-item {
        display: flex;
        align-items: center;
        gap: 12px;
      }
      
      .quality-label {
        width: 90px;
        font-size: 0.875rem;
        color: #9CA3AF;
        flex-shrink: 0;
      }
      
      .quality-bar {
        flex: 1;
        height: 8px;
        background: rgba(255, 255, 255, 0.1);
        border-radius: 4px;
        overflow: hidden;
      }
      
      .quality-fill {
        height: 100%;
        background: linear-gradient(90deg, #10B981, #3B82F6);
        border-radius: 4px;
        transition: width 1s ease-in-out;
      }
      
      .quality-value {
        width: 40px;
        text-align: right;
        font-size: 0.875rem;
        font-weight: 600;
        color: white;
        flex-shrink: 0;
      }
      
      /* Enhanced Insights Styles */
      .insight-content {
        margin-left: 28px;
      }
      
      .insight-content h4 {
        margin: 0 0 8px 0;
        font-size: 1rem;
        font-weight: 600;
        color: white;
      }
      
      .insight-content p {
        margin: 0 0 12px 0;
        font-size: 0.875rem;
        color: #D1D5DB;
        line-height: 1.4;
      }
      
      .action-items {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }
      
      .action-item {
        font-size: 0.8rem;
        color: #9CA3AF;
        line-height: 1.3;
      }
      
      .detail-label, .metric-label {
        color: #94a3b8;
        font-size: 14px;
      }
      
      .detail-value, .metric-value {
        color: #e2e8f0;
        font-weight: 600;
        font-size: 14px;
      }
      
      .status-chart {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }
      
      .status-item {
        display: flex;
        align-items: center;
        gap: 12px;
      }
      
      .status-indicator {
        width: 16px;
        height: 16px;
        border-radius: 50%;
      }
      
      .status-indicator.active {
        background: #10b981;
      }
      
      .status-indicator.inactive {
        background: #64748b;
      }
      
      .status-info {
        flex: 1;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      
      .status-name {
        color: #e2e8f0;
        font-size: 14px;
      }
      
      .status-count {
        color: #94a3b8;
        font-size: 14px;
        font-weight: 600;
      }
      
      .status-percent {
        color: #60a5fa;
        font-size: 12px;
        font-weight: 600;
      }
      
      .insights-content {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .insight {
        display: flex;
        align-items: flex-start;
        gap: 12px;
        padding: 16px;
        border-radius: 8px;
        border-left: 4px solid;
        font-size: 14px;
        line-height: 1.5;
      }
      
      .insight.success {
        background: rgba(16, 185, 129, 0.1);
        border-left-color: #10b981;
        color: #10b981;
      }
      
      .insight.warning {
        background: rgba(245, 158, 11, 0.1);
        border-left-color: #f59e0b;
        color: #f59e0b;
      }
      
      .insight.critical {
        background: rgba(239, 68, 68, 0.1);
        border-left-color: #ef4444;
        color: #ef4444;
      }
      
      .insight.info {
        background: rgba(59, 130, 246, 0.1);
        border-left-color: #3b82f6;
        color: #3b82f6;
      }
      
      /* Export Section */
      .export-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 24px;
        margin-bottom: 32px;
      }
      
      .export-card {
        padding: 24px;
        border-radius: 16px;
        cursor: pointer;
        transition: all 0.3s ease;
        display: flex;
        flex-direction: column;
        align-items: center;
        text-align: center;
        gap: 16px;
      }
      
      .export-card:hover {
        transform: translateY(-4px);
        background: rgba(30, 41, 59, 0.6);
        border-color: rgba(59, 130, 246, 0.5);
      }
      
      .export-card.bulk {
        grid-column: span 2;
      }
      
      .export-icon {
        width: 64px;
        height: 64px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 16px;
        background: rgba(51, 65, 85, 0.3);
        font-size: 24px;
      }
      
      .export-content h3 {
        margin: 0 0 8px 0;
        font-size: 20px;
        font-weight: 600;
        color: #e2e8f0;
      }
      
      .export-description {
        margin: 0 0 16px 0;
        color: #94a3b8;
        font-size: 14px;
        line-height: 1.5;
      }
      
      .export-features {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        justify-content: center;
      }
      
      .feature-tag {
        padding: 4px 8px;
        background: rgba(51, 65, 85, 0.5);
        border-radius: 4px;
        font-size: 12px;
        color: #94a3b8;
        font-weight: 500;
      }
      
      .export-action {
        margin-top: auto;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(59, 130, 246, 0.1);
        border-radius: 50%;
        color: #60a5fa;
        font-size: 16px;
      }
      
      .export-status {
        padding: 16px;
        background: rgba(30, 41, 59, 0.8);
        border-radius: 8px;
        text-align: center;
      }
      
      .status-content {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 12px;
      }
      
      .status-text {
        color: #94a3b8;
        font-size: 14px;
      }
    </style>
    ''';
  }
  
  void _addLocationModal(StringBuffer buffer) {
    buffer.writeln('''
    <!-- Location Modal -->
    <div id="locationsModal" class="modal">
        <div class="modal-container">
            <div class="modal-content">
                <div class="modal-header">
                    <h3 class="modal-title" id="modalTitle">Locations for key</h3>
                    <button class="close-btn" onclick="closeLocationsModal()">
                        <i class="fa-solid fa-xmark"></i>
                    </button>
                </div>
                
                <div class="modal-body custom-scrollbar">
                    <div class="location-list" id="locationsList">
                        <!-- Locations will be populated here -->
                    </div>
                </div>
            </div>
        </div>
    </div>
    ''');
  }
  
  void _addKeyboardShortcuts(StringBuffer buffer) {
    buffer.writeln('''
    <!-- Keyboard shortcuts panel -->
    <div class="keyboard-shortcuts" id="keyboardShortcuts">
        <div class="keyboard-shortcut">
            <span>Search keys</span>
            <span class="shortcut-key">Ctrl+F</span>
        </div>
        <div class="keyboard-shortcut">
            <span>Close modal</span>
            <span class="shortcut-key">Escape</span>
        </div>
        <div class="keyboard-shortcut">
            <span>Refresh</span>
            <span class="shortcut-key">Ctrl+R</span>
        </div>
        <div class="keyboard-shortcut">
            <span>Toggle shortcuts</span>
            <span class="shortcut-key">?</span>
        </div>
    </div>
    ''');
  }
  
  // New helper methods for modern UI
  void _addSidebar(StringBuffer buffer) {
    buffer.writeln('''
    <!-- Sidebar -->
    <div class="sidebar">
        <div class="sidebar-header">
            <div class="sidebar-logo">
                <i class="fa-solid fa-key text-white text-xl"></i>
            </div>
        </div>
        <nav class="sidebar-nav">
            <div class="sidebar-nav-item active" title="Dashboard Overview" onclick="showSection('dashboard')">
                <i class="fa-solid fa-chart-pie"></i>
            </div>
            <div class="sidebar-nav-item" title="Keys Analysis" onclick="showSection('analysis')">
                <i class="fa-solid fa-key"></i>
            </div>
            <div class="sidebar-nav-item" title="Statistics" onclick="showSection('stats')">
                <i class="fa-solid fa-chart-bar"></i>
            </div>
            <div class="sidebar-nav-item" title="Export Report" onclick="showSection('export')">
                <i class="fa-solid fa-download"></i>
            </div>
        </nav>
    </div>
    ''');
  }

  void _addHeader(StringBuffer buffer) {
    buffer.writeln('''
    <!-- Header -->
    <div class="header">
        <div class="header-left">
            <div class="brand">
                <span class="brand-flutter">Flutter</span>
                <span class="brand-keycheck">KeyCheck</span>
            </div>
            <span class="brand-separator">|</span>
            <h1 class="page-title">Report Dashboard</h1>
        </div>
        <div class="header-right">
            <button class="header-btn" onclick="refreshReport()">
                <i class="fa-solid fa-refresh"></i>
                Refresh
            </button>
        </div>
    </div>
    ''');
  }

  void _addDashboardHeader(StringBuffer buffer) {
    final timestamp = DateTime.now();
    final formattedTime = '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year} - ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    
    buffer.writeln('''
        <!-- Dashboard Header -->
        <div class="dashboard-header">
            <div class="dashboard-title-section">
                <h2>Flutter KeyCheck Dashboard</h2>
                <p class="dashboard-subtitle">Comprehensive key analysis for your Flutter project</p>
            </div>
            <div class="last-updated">
                <i class="fa-regular fa-clock"></i>
                Last updated: <span class="last-updated-time">$formattedTime</span>
            </div>
        </div>
    ''');
  }

  void _addMetricsCards(StringBuffer buffer, ScanResult result) {
    final activeKeys = result.keyUsages.values.where((k) => k.status == 'active').length;
    final totalKeys = result.keyUsages.length;
    final coverage = result.metrics.fileCoverage;
    final scanTime = result.duration.inMilliseconds / 1000.0;
    
    buffer.writeln('''
        <!-- Metrics Cards -->
        <div class="metrics-grid">
            <!-- Total Keys Card -->
            <div class="metric-card glass-card">
                <div class="metric-header">
                    <div class="metric-icon">
                        <i class="fa-solid fa-key text-blue-400"></i>
                    </div>
                    <div class="metric-info">
                        <h3>Total Keys</h3>
                        <p class="metric-value">$totalKeys</p>
                    </div>
                </div>
                <div class="metric-footer">
                    <span class="metric-label">Found in scan</span>
                    <span class="metric-change positive">
                        <i class="fa-solid fa-arrow-up"></i> +5.1%
                    </span>
                </div>
            </div>

            <!-- Coverage Card -->
            <div class="metric-card glass-card">
                <div class="metric-header">
                    <div class="metric-icon">
                        <i class="fa-solid fa-chart-pie text-green-400"></i>
                    </div>
                    <div class="metric-info">
                        <h3>Coverage</h3>
                        <p class="metric-value">${coverage.toStringAsFixed(1)}%</p>
                    </div>
                </div>
                <div class="metric-footer">
                    <span class="metric-label">Target: 80%</span>
                    <span class="metric-change ${coverage >= 80 ? 'positive' : 'negative'}">
                        <i class="fa-solid fa-arrow-${coverage >= 80 ? 'up' : 'down'}"></i> ${coverage >= 80 ? '+' : ''}${(coverage - 80).toStringAsFixed(1)}%
                    </span>
                </div>
            </div>

            <!-- Scan Time Card -->
            <div class="metric-card glass-card">
                <div class="metric-header">
                    <div class="metric-icon">
                        <i class="fa-solid fa-stopwatch text-yellow-400"></i>
                    </div>
                    <div class="metric-info">
                        <h3>Scan Time</h3>
                        <p class="metric-value">${scanTime.toStringAsFixed(1)}s</p>
                    </div>
                </div>
                <div class="metric-footer">
                    <span class="metric-label">Average: 3.5s</span>
                    <span class="metric-change ${scanTime < 3.5 ? 'positive' : 'negative'}">
                        <i class="fa-solid fa-arrow-${scanTime < 3.5 ? 'down' : 'up'}"></i> ${scanTime < 3.5 ? '-' : '+'}${(scanTime - 3.5).abs().toStringAsFixed(1)}s
                    </span>
                </div>
            </div>

            <!-- Active Keys Card -->
            <div class="metric-card glass-card">
                <div class="metric-header">
                    <div class="metric-icon">
                        <i class="fa-solid fa-toggle-on text-blue-400"></i>
                    </div>
                    <div class="metric-info">
                        <h3>Active Keys</h3>
                        <p class="metric-value">$activeKeys</p>
                    </div>
                </div>
                <div class="metric-footer">
                    <span class="metric-label">Inactive: ${totalKeys - activeKeys}</span>
                    <span class="metric-change positive">
                        <i class="fa-solid fa-check"></i> ${((activeKeys / totalKeys) * 100).toStringAsFixed(1)}%
                    </span>
                </div>
            </div>
        </div>
    ''');
  }

  void _addKeysTable(StringBuffer buffer, ScanResult result) {
    buffer.writeln('''
        <!-- Keys Table Section -->
        <div class="keys-section glass-card">
            <div class="keys-header">
                <h3 class="keys-title">Keys Overview</h3>
                <div class="keys-controls">
                    <!-- Search Bar -->
                    <div class="search-container">
                        <i class="fa-solid fa-search search-icon"></i>
                        <input type="text" placeholder="Search keys..." class="search-input" id="searchInput" oninput="applyFilters()">
                    </div>
                    
                    <!-- Category Filter -->
                    <div class="filter-container">
                        <select class="filter-select" id="categoryFilter" onchange="applyFilters()">
                            <option value="">All Categories</option>
                            <option value="widget">Widget</option>
                            <option value="handler">Handler</option>
                            <option value="test">Test</option>
                            <option value="navigation">Navigation</option>
                        </select>
                    </div>
                    
                    <!-- Status Filter -->
                    <div class="filter-container">
                        <select class="filter-select" id="statusFilter" onchange="applyFilters()">
                            <option value="">All Statuses</option>
                            <option value="active">Active</option>
                            <option value="inactive">Inactive</option>
                        </select>
                    </div>
                </div>
            </div>
            
            <!-- Keys Table -->
            <div class="keys-table-container">
                <table class="keys-table">
                    <thead>
                        <tr>
                            <th>Key Name</th>
                            <th>Category</th>
                            <th>Status</th>
                            <th>Locations</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
    ''');

    // Add table rows
    for (final entry in result.keyUsages.entries) {
      final keyName = entry.key;
      final keyData = entry.value;
      final category = _inferCategory(keyName, keyData.tags);
      final isActive = keyData.status == 'active';
      
      buffer.writeln('''
                        <tr class="table-row" data-key="$keyName" data-category="$category" data-status="${isActive ? 'active' : 'inactive'}">
                            <td>
                                <div class="key-name">$keyName</div>
                            </td>
                            <td>
                                <div class="category-container">
                                    <span class="category-dot $category"></span>
                                    <span class="category-label">${_capitalize(category)}</span>
                                    <i class="fa-solid fa-${_getCategoryIcon(category)} category-icon $category"></i>
                                </div>
                            </td>
                            <td>
                                <span class="status-badge ${isActive ? 'active' : 'inactive'}">
                                    ${isActive ? 'Active' : 'Inactive'}
                                </span>
                            </td>
                            <td>
      ''');
      
      if (keyData.locations.isNotEmpty) {
        buffer.writeln('''
                                <button class="locations-btn" onclick="openLocationsModal('$keyName')">
                                    <i class="fa-solid fa-map-pin"></i> ${keyData.locations.length} location${keyData.locations.length > 1 ? 's' : ''}
                                </button>
        ''');
      } else {
        buffer.writeln('                                <span class="no-locations">No locations</span>');
      }
      
      buffer.writeln('''
                            </td>
                            <td>
                                <div class="action-buttons">
                                    <button class="action-btn" title="View key details" onclick="showKeyDetails('$keyName')">
                                        <i class="fa-solid fa-eye"></i>
                                    </button>
                                    <button class="action-btn" title="Show code locations" onclick="openLocationsModal('$keyName')">
                                        <i class="fa-solid fa-code"></i>
                                    </button>
                                </div>
                            </td>
                        </tr>
      ''');
    }

    buffer.writeln('''
                    </tbody>
                </table>
            </div>
            
            <!-- Pagination -->
            <div class="pagination">
                <div class="pagination-info">
                    Showing <span class="pagination-info-highlight">1-${result.keyUsages.length}</span> of <span class="pagination-info-highlight">${result.keyUsages.length}</span> keys
                </div>
                <div class="pagination-controls">
                    <button class="pagination-btn" disabled>
                        <i class="fa-solid fa-chevron-left"></i>
                    </button>
                    <button class="pagination-btn active">1</button>
                    <button class="pagination-btn">
                        <i class="fa-solid fa-chevron-right"></i>
                    </button>
                </div>
            </div>
        </div>
    ''');
  }


  String _inferCategory(String keyName, Set<String> tags) {
    if (keyName.toLowerCase().contains('button') || keyName.toLowerCase().contains('widget')) return 'widget';
    if (keyName.toLowerCase().contains('test')) return 'test';
    if (keyName.toLowerCase().contains('navigate') || keyName.toLowerCase().contains('route')) return 'navigation';
    if (keyName.toLowerCase().contains('handle') || keyName.toLowerCase().contains('on')) return 'handler';
    if (tags.contains('widget')) return 'widget';
    if (tags.contains('test')) return 'test';
    if (tags.contains('navigation')) return 'navigation';
    if (tags.contains('handler')) return 'handler';
    return 'widget'; // default
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'widget': return 'cube';
      case 'handler': return 'code';
      case 'test': return 'vial';
      case 'navigation': return 'route';
      default: return 'cube';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _addJavaScriptData(StringBuffer buffer, ScanResult result) {
    // Embed location data as JavaScript
    buffer.writeln('<script>');
    buffer.writeln('// Key location data');
    buffer.writeln('const keyLocations = {');
    
    for (final entry in result.keyUsages.entries) {
      buffer.write('  "${entry.key}": [');
      for (var i = 0; i < entry.value.locations.length; i++) {
        final location = entry.value.locations[i];
        buffer.write('{');
        buffer.write('"file": "${location.file.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"');
        buffer.write(', "line": ${location.line}');
        buffer.write(', "column": ${location.column}');
        buffer.write(', "detector": "${location.detector}"');
        buffer.write(', "context": "${location.context.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"');
        buffer.write('}');
        if (i < entry.value.locations.length - 1) buffer.write(', ');
      }
      buffer.writeln('],');
    }
    
    buffer.writeln('};');
    buffer.writeln('');
    
    // UI functionality  
    buffer.writeln('''
// Ensure DOM is loaded before executing functions
document.addEventListener('DOMContentLoaded', function() {
    console.log('Flutter KeyCheck Report: DOM loaded, initializing...');
    
    // Initialize filters and search functionality
    initializeFilters();
    
    // Initialize charts if on stats page
    initializeCharts();
    
    // Initialize default section
    showSection('dashboard');
});

// Old showSection function removed - using the new improved version below

// Refresh functionality
function refreshReport() {
    // Show loading state
    const refreshBtn = document.querySelector('.header-btn');
    refreshBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Refreshing...';
    refreshBtn.disabled = true;
    
    // Simulate refresh (in real implementation, this would reload data)
    setTimeout(() => {
        location.reload();
    }, 1000);
}

// Filter functionality
function applyFilters() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const categoryFilter = document.getElementById('categoryFilter').value;
    const statusFilter = document.getElementById('statusFilter').value;
    
    const rows = document.querySelectorAll('.table-row');
    let visibleCount = 0;
    
    rows.forEach(row => {
        const keyName = row.dataset.key.toLowerCase();
        const category = row.dataset.category;
        const status = row.dataset.status;
        
        let shouldShow = true;
        
        // Apply search filter
        if (searchTerm && !keyName.includes(searchTerm)) {
            shouldShow = false;
        }
        
        // Apply category filter
        if (categoryFilter && category !== categoryFilter) {
            shouldShow = false;
        }
        
        // Apply status filter
        if (statusFilter && status !== statusFilter) {
            shouldShow = false;
        }
        
        row.style.display = shouldShow ? '' : 'none';
        if (shouldShow) visibleCount++;
    });
    
    // Update pagination info
    updatePaginationInfo(visibleCount);
}

function updatePaginationInfo(visibleCount) {
    const paginationInfo = document.querySelector('.pagination-info');
    const totalKeys = document.querySelectorAll('.table-row').length;
    
    paginationInfo.innerHTML = 'Showing <span class="pagination-info-highlight">1-' + visibleCount + '</span> of <span class="pagination-info-highlight">' + totalKeys + '</span> keys';
}

// Modal functions
function openLocationsModal(keyName) {
    console.log('openLocationsModal called with:', keyName);
    const modal = document.getElementById('locationsModal');
    const modalTitle = document.getElementById('modalTitle');
    const locationsList = document.getElementById('locationsList');
    
    if (!modal || !modalTitle || !locationsList) {
        console.error('Modal elements not found!', {modal, modalTitle, locationsList});
        return;
    }
    
    modalTitle.textContent = 'Locations for ' + keyName;
    
    const locations = keyLocations[keyName];
    if (!locations || locations.length === 0) {
        locationsList.innerHTML = '<div style="text-align: center; padding: 2rem;"><p style="color: #9CA3AF;">No locations found for this key.</p></div>';
    } else {
        let html = '';
        locations.forEach((location, index) => {
            // Extract relative file path for display
            const relativePath = location.file.replace(/.*[\\/](?:lib|test|example)[\\/]/g, '');
            
            // Apply Dart/Flutter syntax highlighting
            let highlightedContext = applySyntaxHighlighting(location.context);
            
            // Highlight the specific key with emphasis
            const keyPattern = new RegExp("\\b" + escapeRegExp(keyName) + "\\b", 'g');
            highlightedContext = highlightedContext.replace(keyPattern, '<span class="highlighted-key">' + keyName + '</span>');
            
            // Split into lines and highlight the target line
            const lines = highlightedContext.split('\\n');
            let lineHtml = '';
            lines.forEach((line, lineIndex) => {
                const lineNumber = location.line - 2 + lineIndex;
                const isTargetLine = lineIndex === 2; // Middle line is usually the target
                const lineClass = isTargetLine ? 'highlighted-line' : '';
                lineHtml += '<div class="code-line ' + lineClass + '">';
                lineHtml += '<span class="code-line-number">' + lineNumber + '</span>';
                lineHtml += line;
                lineHtml += '</div>';
            });
            
            html += '<div class="location-item">' +
                '<div class="location-header">' +
                    '<div class="location-info">' +
                        '<div class="file-info">' +
                            '<i class="fa-regular fa-file-code file-icon"></i>' +
                            '<span class="file-path">' + relativePath + '</span>' +
                        '</div>' +
                        '<div class="line-info">' +
                            '<i class="fa-solid fa-location-dot"></i> Line ' + location.line + ', Column ' + location.column + 
                            ' · <span class="detector-info">' + location.detector + '</span>' +
                        '</div>' +
                    '</div>' +
                    '<div class="location-actions">' +
                        '<button class="location-btn" onclick="copyCodeBlock(this)" data-code="' + escapeHtml(location.context).replaceAll('"', '&quot;') + '" title="Copy code block">'+
                            '<i class="fa-regular fa-copy"></i> Copy Code' +
                        '</button>' +
                        '<button class="location-btn secondary" onclick="copyToClipboard(&quot;' + relativePath.replaceAll('"', '&quot;') + '&quot;)" title="Copy file path">'+
                            '<i class="fa-regular fa-folder"></i> Copy Path' +
                        '</button>' +
                    '</div>' +
                '</div>' +
                '<div class="code-container" data-language="dart">' + 
                    '<div class="code-header">' +
                        '<span class="code-language">Dart/Flutter</span>' +
                        '<button class="code-copy-btn" onclick="copyCodeBlock(this)" data-code="' + escapeHtml(location.context).replaceAll('"', '&quot;') + '">' +
                            '<i class="fa-regular fa-copy"></i>' +
                        '</button>' +
                    '</div>' +
                    lineHtml + 
                '</div>' +
            '</div>';
        });
        locationsList.innerHTML = html;
    }
    
    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function closeLocationsModal() {
    const modal = document.getElementById('locationsModal');
    modal.style.display = 'none';
    document.body.style.overflow = 'auto';
}

function showKeyDetails(keyName) {
    console.log('showKeyDetails called with:', keyName);
    
    // Create or show key details modal
    let detailModal = document.getElementById('keyDetailsModal');
    if (!detailModal) {
        // Create the modal if it doesn't exist
        detailModal = document.createElement('div');
        detailModal.id = 'keyDetailsModal';
        detailModal.className = 'modal';
        detailModal.innerHTML = `
            <div class="modal-content" style="max-width: 800px;">
                <div class="modal-header">
                    <h2 id="keyDetailsTitle">Key Details</h2>
                    <button onclick="closeKeyDetailsModal()" class="modal-close">×</button>
                </div>
                <div id="keyDetailsBody" class="modal-body">
                    <!-- Key details content will be populated here -->
                </div>
            </div>
        `;
        document.body.appendChild(detailModal);
    }
    
    const titleEl = document.getElementById('keyDetailsTitle');
    const bodyEl = document.getElementById('keyDetailsBody');
    
    titleEl.textContent = 'Details for ' + keyName;
    
    const keyData = keyLocations[keyName];
    if (!keyData || keyData.length === 0) {
        bodyEl.innerHTML = '<div style="text-align: center; padding: 2rem;"><p style="color: #9CA3AF;">No data found for this key.</p></div>';
    } else {
        let html = '<div class="key-details-grid">';
        
        // Key statistics
        html += '<div class="detail-section"><h3><i class="fa-solid fa-chart-bar"></i> Statistics</h3>';
        html += '<div class="stat-item">Total Locations: <strong>' + keyData.length + '</strong></div>';
        
        // Group by files
        const fileGroups = {};
        keyData.forEach(loc => {
            const file = loc.file.replace(/.*[\\/](?:lib|test|example)[\\/]/g, '');
            if (!fileGroups[file]) fileGroups[file] = [];
            fileGroups[file].push(loc);
        });
        
        html += '<div class="stat-item">Files: <strong>' + Object.keys(fileGroups).length + '</strong></div>';
        
        // Group by detector
        const detectorGroups = {};
        keyData.forEach(loc => {
            if (!detectorGroups[loc.detector]) detectorGroups[loc.detector] = [];
            detectorGroups[loc.detector].push(loc);
        });
        
        html += '<div class="stat-item">Detection Methods: <strong>' + Object.keys(detectorGroups).length + '</strong></div>';
        html += '</div>';
        
        // File breakdown
        html += '<div class="detail-section"><h3><i class="fa-regular fa-folder"></i> File Breakdown</h3>';
        Object.entries(fileGroups).forEach(([file, locs]) => {
            html += '<div class="file-breakdown-item">';
            html += '<div class="file-name"><i class="fa-regular fa-file-code"></i> ' + file + '</div>';
            html += '<div class="file-stats">' + locs.length + ' occurrence' + (locs.length > 1 ? 's' : '') + '</div>';
            html += '</div>';
        });
        html += '</div>';
        
        html += '</div>';
        
        // Add CSS for the details modal
        if (!document.getElementById('keyDetailsStyles')) {
            const styles = document.createElement('style');
            styles.id = 'keyDetailsStyles';
            styles.textContent = `
                .key-details-grid { display: flex; flex-direction: column; gap: 20px; }
                .detail-section { 
                    background: rgba(30, 41, 59, 0.3); 
                    border: 1px solid rgba(51, 65, 85, 0.4); 
                    border-radius: 12px; 
                    padding: 20px; 
                }
                .detail-section h3 { 
                    color: #f1f5f9; 
                    margin: 0 0 16px 0; 
                    display: flex; 
                    align-items: center; 
                    gap: 8px; 
                    font-size: 18px;
                }
                .stat-item { 
                    color: #cbd5e1; 
                    margin-bottom: 8px; 
                    display: flex; 
                    justify-content: space-between;
                }
                .file-breakdown-item { 
                    display: flex; 
                    justify-content: space-between; 
                    align-items: center; 
                    padding: 8px 0; 
                    border-bottom: 1px solid rgba(51, 65, 85, 0.3);
                }
                .file-breakdown-item:last-child { border-bottom: none; }
                .file-name { color: #94a3b8; display: flex; align-items: center; gap: 8px; }
                .file-stats { color: #64748b; font-size: 14px; }
            `;
            document.head.appendChild(styles);
        }
        
        bodyEl.innerHTML = html;
    }
    
    detailModal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function closeKeyDetailsModal() {
    const modal = document.getElementById('keyDetailsModal');
    if (modal) {
        modal.style.display = 'none';
        document.body.style.overflow = 'auto';
    }
}

function showSection(sectionName) {
    console.log('showSection called with:', sectionName);
    
    // Remove active class from all nav items
    document.querySelectorAll('.sidebar-nav-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Add active class to clicked nav item
    const activeItem = document.querySelector(`[onclick="showSection('\${sectionName}')"]`);
    if (activeItem) {
        activeItem.classList.add('active');
    }
    
    // Hide all content sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.style.display = 'none';
    });
    
    // Show the requested section
    const targetSection = document.getElementById(`\${sectionName}-section`);
    if (targetSection) {
        targetSection.style.display = 'block';
    }
    
    // Update page title
    const pageTitle = document.querySelector('.page-title');
    if (pageTitle) {
        const sectionTitles = {
            'dashboard': 'Report Dashboard',
            'analysis': 'Keys Analysis',
            'stats': 'Statistics',
            'export': 'Export Options'
        };
        pageTitle.textContent = sectionTitles[sectionName] || 'Report Dashboard';
    }
    
    // Show toast notification
    const sectionNames = {
        'dashboard': '📊 Dashboard',
        'analysis': '🔑 Keys Analysis',
        'stats': '📈 Statistics',  
        'export': '📤 Export Options'
    };
    
    showToast(`Switched to \${sectionNames[sectionName] || sectionName}`, 'info');
}

// Initialize charts
function initializeCharts() {
    // Performance Chart
    const performanceCanvas = document.getElementById('performanceChart');
    if (performanceCanvas) {
        drawPerformanceChart(performanceCanvas);
    }
    
    // Distribution Chart  
    const distributionCanvas = document.getElementById('distributionChart');
    if (distributionCanvas) {
        drawDistributionChart(distributionCanvas);
    }
}

function drawPerformanceChart(canvas) {
    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Sample performance data (you can make this dynamic)
    const data = [65, 80, 90, 75, 85];
    const labels = ['Scan', 'Parse', 'Analyze', 'Filter', 'Report'];
    const maxValue = Math.max(...data);
    
    // Draw bars
    const barWidth = width / data.length - 10;
    const barSpacing = 10;
    
    data.forEach((value, index) => {
        const barHeight = (value / maxValue) * (height - 30);
        const x = index * (barWidth + barSpacing) + 5;
        const y = height - barHeight - 15;
        
        // Draw bar
        ctx.fillStyle = '#3B82F6';
        ctx.fillRect(x, y, barWidth, barHeight);
        
        // Draw label
        ctx.fillStyle = '#9CA3AF';
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(labels[index], x + barWidth/2, height - 5);
        
        // Draw value
        ctx.fillStyle = '#E5E7EB';
        ctx.fillText(value + '%', x + barWidth/2, y - 5);
    });
}

function drawDistributionChart(canvas) {
    const ctx = canvas.getContext('2d');
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const radius = Math.min(centerX, centerY) - 20;
    
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Sample distribution data (you can make this dynamic)
    const data = [
        { label: 'Buttons', value: 35, color: '#3b82f6' },
        { label: 'Input Fields', value: 25, color: '#10b981' },
        { label: 'Navigation', value: 20, color: '#f59e0b' },
        { label: 'Modals', value: 15, color: '#8b5cf6' },
        { label: 'Lists', value: 5, color: '#ef4444' }
    ];
    
    const total = data.reduce((sum, item) => sum + item.value, 0);
    let currentAngle = -Math.PI / 2; // Start at top
    
    data.forEach(item => {
        const sliceAngle = (item.value / total) * 2 * Math.PI;
        
        // Draw slice
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.arc(centerX, centerY, radius, currentAngle, currentAngle + sliceAngle);
        ctx.closePath();
        ctx.fillStyle = item.color;
        ctx.fill();
        
        // Draw border
        ctx.strokeStyle = '#1F2937';
        ctx.lineWidth = 2;
        ctx.stroke();
        
        currentAngle += sliceAngle;
    });
    
    // Draw center circle
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius * 0.4, 0, 2 * Math.PI);
    ctx.fillStyle = '#1F2937';
    ctx.fill();
}

function initializeFilters() {
    console.log('Initializing filters...');
    
    // Ensure DOM is loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeFilters);
        return;
    }
    
    // Initialize search input
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.addEventListener('input', applyFilters);
        searchInput.addEventListener('keyup', function(e) {
            if (e.key === 'Enter') {
                applyFilters();
            }
        });
    }
    
    // Initialize filter dropdowns
    const categoryFilter = document.getElementById('categoryFilter');
    const statusFilter = document.getElementById('statusFilter');
    
    if (categoryFilter) {
        categoryFilter.addEventListener('change', applyFilters);
    }
    
    if (statusFilter) {
        statusFilter.addEventListener('change', applyFilters);
    }
    
    // Debug: check if table rows exist
    const rows = document.querySelectorAll('.table-row');
    console.log('Found table rows:', rows.length);
    
    if (rows.length === 0) {
        console.warn('No table rows found with .table-row class');
        // Try alternative selector
        const trRows = document.querySelectorAll('tbody tr');
        console.log('Found tbody tr rows:', trRows.length);
    }
    
    // Apply initial filters
    applyFilters();
}

function exportReport(format) {
    console.log('exportReport called with format:', format);
    
    const timestamp = new Date().toISOString().split('T')[0];
    let filename = 'flutter-keycheck-report-' + timestamp;
    let content = '';
    let mimeType = '';
    
    switch (format) {
        case 'html':
            filename += '.html';
            mimeType = 'text/html';
            // Get the current HTML document
            content = document.documentElement.outerHTML;
            break;
            
        case 'json':
            filename += '.json';
            mimeType = 'application/json';
            // Create structured JSON data from the current report
            const jsonData = {
                timestamp: new Date().toISOString(),
                report: {
                    totalKeys: Object.keys(keyLocations).length,
                    keys: {}
                }
            };
            
            // Add key data
            Object.entries(keyLocations).forEach(([keyName, locations]) => {
                jsonData.report.keys[keyName] = {
                    name: keyName,
                    locationCount: locations.length,
                    locations: locations.map(loc => ({
                        file: loc.file,
                        line: loc.line,
                        column: loc.column,
                        detector: loc.detector,
                        context: loc.context
                    }))
                };
            });
            
            content = JSON.stringify(jsonData, null, 2);
            break;
            
        case 'md':
            filename += '.md';
            mimeType = 'text/markdown';
            content = '# Flutter KeyCheck Report\\n\\n';
            content += `Generated: \${new Date().toISOString()}\\n\\n`;
            content += `## Summary\\n\\n`;
            content += `- **Total Keys Found**: \${Object.keys(keyLocations).length}\\n`;
            content += `- **Report Date**: \${timestamp}\\n\\n`;
            content += `## Key Details\\n\\n`;
            
            Object.entries(keyLocations).forEach(([keyName, locations]) => {
                content += `### \$keyName\\n\\n`;
                content += `- **Locations**: \${locations.length}\\n`;
                content += `- **Files**:\\n`;
                
                const files = {};
                locations.forEach(loc => {
                    const file = loc.file.replace(/.*[\\\\/](?:lib|test|example)[\\\\/]/g, '');
                    if (!files[file]) files[file] = [];
                    files[file].push(loc);
                });
                
                Object.entries(files).forEach(([file, locs]) => {
                    content += `  - \${file}: \${locs.length} occurrence(s)\\n`;
                });
                
                content += `\\n`;
            });
            break;
            
        case 'ci':
            filename += '.txt';
            mimeType = 'text/plain';
            content = 'Flutter KeyCheck Report - CI Output\\n';
            content += '=' + '='.repeat(40) + '\\n\\n';
            content += `Generated: \${new Date().toISOString()}\\n`;
            content += `Total Keys: \${Object.keys(keyLocations).length}\\n\\n`;
            
            Object.entries(keyLocations).forEach(([keyName, locations]) => {
                content += `[\$keyName] \${locations.length} location(s)\\n`;
                locations.forEach(loc => {
                    const file = loc.file.replace(/.*[\\\\/](?:lib|test|example)[\\\\/]/g, '');
                    content += `  \${file}:\${loc.line}:\${loc.column} (\${loc.detector})\\n`;
                });
                content += '\\n';
            });
            break;
            
        case 'text':
            filename += '.txt';
            mimeType = 'text/plain';
            content = 'Flutter KeyCheck Report\\n';
            content += '='.repeat(30) + '\\n\\n';
            content += `Report Generated: \${new Date().toLocaleString()}\\n`;
            content += `Total Keys Found: \${Object.keys(keyLocations).length}\\n\\n`;
            
            Object.entries(keyLocations).forEach(([keyName, locations]) => {
                content += `Key: \$keyName\\n`;
                content += `Locations: \${locations.length}\\n`;
                locations.forEach((loc, index) => {
                    const file = loc.file.replace(/.*[\\\\/](?:lib|test|example)[\\\\/]/g, '');
                    content += `  \${index + 1}. \${file} (Line \${loc.line}, Column \${loc.column})\\n`;
                });
                content += '\\n';
            });
            break;
    }
    
    // Create download
    try {
        const blob = new Blob([content], { type: mimeType });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
        
        showToast(`📥 Downloaded: \${filename}`, 'success');
    } catch (error) {
        console.error('Export failed:', error);
        showToast(`❌ Export failed: \${error.message}`, 'error');
    }
}

function copyToClipboard(text) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(text).then(() => {
            console.log('Copied to clipboard: ' + text);
            showToast('📋 Copied to clipboard!', 'success');
        }).catch(err => {
            console.error('Could not copy text: ', err);
            showToast('❌ Failed to copy', 'error');
        });
    } else {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
            document.execCommand('copy');
            showToast('📋 Copied to clipboard!', 'success');
        } catch (err) {
            console.error('Fallback: Oops, unable to copy', err);
            showToast('❌ Failed to copy', 'error');
        }
        document.body.removeChild(textArea);
    }
}

function copyCodeBlock(buttonElement) {
    const codeText = buttonElement.getAttribute('data-code');
    if (codeText) {
        // Decode HTML entities back to plain text
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = codeText;
        const plainText = tempDiv.textContent || tempDiv.innerText || '';
        
        copyToClipboard(plainText);
        
        // Visual feedback
        const originalHtml = buttonElement.innerHTML;
        buttonElement.innerHTML = '<i class="fa-solid fa-check"></i>';
        buttonElement.classList.add('copied');
        
        setTimeout(() => {
            buttonElement.innerHTML = originalHtml;
            buttonElement.classList.remove('copied');
        }, 2000);
    }
}

function showToast(message, type = 'info') {
    // Remove existing toast if any
    const existingToast = document.querySelector('.toast');
    if (existingToast) {
        existingToast.remove();
    }
    
    // Create new toast
    const toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.textContent = message;
    
    // Add toast to document
    document.body.appendChild(toast);
    
    // Animate in
    setTimeout(() => {
        toast.classList.add('show');
    }, 100);
    
    // Remove after 3 seconds
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.remove();
        }, 300);
    }, 3000);
}

// Close modal when clicking outside or pressing Escape
document.addEventListener('click', function(event) {
    const modal = document.getElementById('locationsModal');
    if (event.target === modal) {
        closeLocationsModal();
    }
});

// Enhanced keyboard shortcuts
document.addEventListener('keydown', function(event) {
    // Handle Escape key
    if (event.key === 'Escape') {
        closeLocationsModal();
        return;
    }
    
    // Handle Ctrl+F for search focus
    if (event.ctrlKey && event.key === 'f') {
        event.preventDefault();
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.focus();
            searchInput.select();
            showToast('🔍 Search mode activated', 'info');
        }
        return;
    }
    
    // Handle Ctrl+R for refresh
    if (event.ctrlKey && event.key === 'r') {
        event.preventDefault();
        refreshReport();
        return;
    }
    
    // Handle ? key for shortcuts toggle
    if (event.key === '?' && !event.ctrlKey && !event.altKey) {
        event.preventDefault();
        toggleKeyboardShortcuts();
        return;
    }
    
    // Handle Enter in search
    if (event.key === 'Enter' && event.target.id === 'searchInput') {
        applyFilters();
        return;
    }
});

function toggleKeyboardShortcuts() {
    const shortcuts = document.getElementById('keyboardShortcuts');
    if (shortcuts) {
        shortcuts.style.display = shortcuts.style.display === 'none' ? 'block' : 'none';
        showToast(shortcuts.style.display === 'none' ? 'Shortcuts hidden' : '⌨️ Keyboard shortcuts visible', 'info');
    }
}

// Auto-hide shortcuts after 10 seconds
setTimeout(() => {
    const shortcuts = document.getElementById('keyboardShortcuts');
    if (shortcuts) {
        shortcuts.style.opacity = '0.3';
    }
}, 10000);

// Utility functions
function escapeRegExp(string) {
    return string.replace(/[.*+?^|()\\[\\]]/g, function(match) { return '\\\\' + match; });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function applySyntaxHighlighting(code) {
    if (!code) return '';
    
    // Escape HTML first
    let highlighted = escapeHtml(code);
    
    // Enhanced Dart/Flutter Keywords with direct replacement
    const keywords = [
        'class', 'const', 'final', 'var', 'static', 'void', 'if', 'else', 
        'for', 'while', 'return', 'import', 'library', 'export', 'part',
        'abstract', 'extends', 'implements', 'with', 'enum', 'async', 'await',
        'try', 'catch', 'throw', 'new', 'this', 'super', 'null', 'true', 'false'
    ];
    keywords.forEach(keyword => {
        const pattern = '\\\\b' + keyword + '\\\\b';
        const regex = new RegExp(pattern, 'g');
        highlighted = highlighted.replace(regex, '<span class="dart-keyword">' + keyword + '</span>');
    });
    
    // Flutter/Dart Types and Widgets
    const types = [
        'Widget', 'StatelessWidget', 'StatefulWidget', 'State', 'BuildContext',
        'Key', 'ValueKey', 'GlobalKey', 'UniqueKey', 'ObjectKey',
        'Container', 'Text', 'Column', 'Row', 'Stack', 'Center', 'Padding',
        'Scaffold', 'AppBar', 'FloatingActionButton', 'TextField', 'Button',
        'MaterialApp', 'CupertinoApp', 'ThemeData', 'MediaQuery',
        'String', 'int', 'double', 'bool', 'List', 'Map', 'Set', 'dynamic'
    ];
    types.forEach(type => {
        const pattern = '\\\\b' + type + '\\\\b';
        const regex = new RegExp(pattern, 'g');
        highlighted = highlighted.replace(regex, '<span class="dart-type">' + type + '</span>');
    });
    
    // Simple patterns with safe replacement
    // String literals
    highlighted = highlighted.replace(/'/g, function(match, offset, string) {
        const endQuote = string.indexOf("'", offset + 1);
        if (endQuote !== -1) {
            const str = string.substring(offset, endQuote + 1);
            return '<span class="dart-string">' + str + '</span>';
        }
        return match;
    });
    
    // Numbers - simple pattern
    highlighted = highlighted.replace(/\\b\\d+\\b/g, function(match) {
        return '<span class="dart-number">' + match + '</span>';
    });
    
    // Comments - line comments
    highlighted = highlighted.replace(/\\/\\/[^\\r\\n]*/g, function(match) {
        return '<span class="dart-comment">' + match + '</span>';
    });
    
    // Function calls - simple pattern
    highlighted = highlighted.replace(/\\b\\w+(?=\\()/g, function(match) {
        return '<span class="dart-function">' + match + '</span>';
    });
    
    // Annotations
    highlighted = highlighted.replace(/@\\w+/g, function(match) {
        return '<span class="dart-annotation">' + match + '</span>';
    });
    
    return highlighted;
}

function analyzeDuplicates(keyName) {
    console.log('Analyzing duplicates for key:', keyName);
    
    // Find all duplicate rows for this key
    const duplicateRows = document.querySelectorAll(`tr[data-key="\$keyName"]`);
    
    if (duplicateRows.length === 0) {
        showToast('❌ Key not found in duplicates table', 'error');
        return;
    }
    
    // Get key data from keyLocations
    const locations = keyLocations[keyName];
    
    if (!locations || locations.length <= 1) {
        showToast('ℹ️ Key has no duplicates', 'info');
        return;
    }
    
    // Create analysis content
    let analysisContent = `<div class="duplicate-analysis">`;
    analysisContent += `<h4 style="margin-top: 0; color: #fb923c;">Duplicate Analysis: \$keyName</h4>`;
    analysisContent += `<div class="analysis-summary">`;
    analysisContent += `<p><strong>Total References:</strong> \${locations.length}</p>`;
    analysisContent += `<p><strong>Impact Level:</strong> \${locations.length > 5 ? '<span class="high">High</span>' : locations.length > 3 ? '<span class="medium">Medium</span>' : '<span class="low">Low</span>'}</p>`;
    analysisContent += `</div>`;
    
    analysisContent += `<h5>All Locations:</h5>`;
    analysisContent += `<div class="locations-list">`;
    
    locations.forEach((loc, index) => {
        const shortFile = loc.file.replace(/.*[\\\\/](?:lib|test|example)[\\\\/]/g, '');
        analysisContent += `<div class="location-detail">`;
        analysisContent += `<div class="location-header">`;
        analysisContent += `<span class="location-number">#\${index + 1}</span>`;
        analysisContent += `<span class="location-path">\${shortFile}:\${loc.line}:\${loc.column}</span>`;
        analysisContent += `<span class="detector-badge">\${loc.detector}</span>`;
        analysisContent += `</div>`;
        if (loc.context) {
            const highlightedContext = highlightKeyInContext(loc.context, keyName);
            analysisContent += `<pre class="context-preview">\${highlightedContext}</pre>`;
        }
        analysisContent += `</div>`;
    });
    
    analysisContent += `</div>`;
    analysisContent += `<div class="analysis-actions">`;
    analysisContent += `<button onclick="openLocationsModal('\$keyName')" class="action-btn primary">`;
    analysisContent += `<i class="fa-solid fa-map-pin"></i> View All Locations`;
    analysisContent += `</button>`;
    analysisContent += `</div>`;
    analysisContent += `</div>`;
    
    // Show in modal
    showModal('Duplicate Key Analysis', analysisContent);
}
''');
    
    buffer.writeln('</script>');
  }
  
  void _addAnalysisSection(StringBuffer buffer, ScanResult result) {
    final orphanKeys = result.keyUsages.values.where((k) => k.locations.isEmpty).length;
    final duplicateKeys = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    
    buffer.writeln('''
        <!-- Analysis Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-magnifying-glass-chart section-icon"></i>
                <div class="section-title-content">
                    <h2>Key Analysis</h2>
                    <p class="section-subtitle">Detailed insights and quality analysis for your Flutter keys</p>
                </div>
            </div>
        </div>

        <!-- Analysis Overview -->
        <div class="analysis-grid">
            <!-- Quality Score Card -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-award text-yellow-400"></i>
                    <h3>Quality Score</h3>
                </div>
                <div class="quality-score">
                    <div class="score-circle">
                        <span class="score-text">${(100 - (result.blindSpots.length * 5)).clamp(0, 100)}%</span>
                    </div>
                    <div class="score-details">
                        <div class="score-item">
                            <span class="label">Blind Spots:</span>
                            <span class="value ${result.blindSpots.length > 0 ? 'text-red-400' : 'text-green-400'}">${result.blindSpots.length}</span>
                        </div>
                        <div class="score-item">
                            <span class="label">Orphan Keys:</span>
                            <span class="value ${orphanKeys > 0 ? 'text-yellow-400' : 'text-green-400'}">$orphanKeys</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Key Distribution -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-chart-pie text-blue-400"></i>
                    <h3>Key Distribution</h3>
                </div>
                <div class="distribution-chart">
                    ${_buildKeyDistribution(result)}
                </div>
            </div>

            <!-- Issues Summary -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-triangle-exclamation text-orange-400"></i>
                    <h3>Issues Found</h3>
                </div>
                <div class="issues-list">
                    <div class="issue-item ${result.blindSpots.length > 0 ? 'critical' : 'resolved'}">
                        <i class="fa-solid fa-${result.blindSpots.length > 0 ? 'circle-exclamation' : 'circle-check'}"></i>
                        <span class="issue-text">${result.blindSpots.length} Blind Spots</span>
                        <span class="issue-severity">${result.blindSpots.length > 5 ? 'High' : result.blindSpots.length > 0 ? 'Medium' : 'None'}</span>
                    </div>
                    <div class="issue-item ${duplicateKeys > 0 ? 'warning' : 'resolved'}">
                        <i class="fa-solid fa-${duplicateKeys > 0 ? 'circle-minus' : 'circle-check'}"></i>
                        <span class="issue-text">$duplicateKeys Duplicate References</span>
                        <span class="issue-severity">${duplicateKeys > 3 ? 'Medium' : duplicateKeys > 0 ? 'Low' : 'None'}</span>
                    </div>
                    <div class="issue-item ${orphanKeys > 0 ? 'warning' : 'resolved'}">
                        <i class="fa-solid fa-${orphanKeys > 0 ? 'circle-minus' : 'circle-check'}"></i>
                        <span class="issue-text">$orphanKeys Orphan Keys</span>
                        <span class="issue-severity">${orphanKeys > 2 ? 'Medium' : orphanKeys > 0 ? 'Low' : 'None'}</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Duplicate Keys Table -->
        ${duplicateKeys > 0 ? _buildDuplicateKeysTable(result) : ''}

        <!-- Analysis Complete -->
        <div class="analysis-summary">
            <p class="analysis-note">
                <i class="fa-solid fa-info-circle"></i>
                For detailed key analysis, switch to the Dashboard section to view the full keys table.
            </p>
        </div>
    ''');
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
    if (name.contains('field') || name.contains('input') || name.contains('text')) return 'Input Fields';
    if (name.contains('menu') || name.contains('nav')) return 'Navigation';
    if (name.contains('modal') || name.contains('dialog')) return 'Modals';
    if (name.contains('list') || name.contains('item')) return 'Lists';
    return 'Other';
  }

  void _addStatsSection(StringBuffer buffer, ScanResult result) {
    final totalFiles = result.metrics.totalFiles;
    final filesWithKeys = result.fileAnalyses.values.where((fa) => fa.keysFound.isNotEmpty).length;
    final averageKeysPerFile = filesWithKeys > 0 ? (result.keyUsages.length / filesWithKeys).toStringAsFixed(1) : '0';
    
    buffer.writeln('''
        <!-- Stats Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-chart-line section-icon"></i>
                <div class="section-title-content">
                    <h2>Statistics & Metrics</h2>
                    <p class="section-subtitle">Comprehensive statistics and performance metrics for your Flutter keys</p>
                </div>
            </div>
        </div>

        <!-- Stats Grid -->
        <div class="stats-grid">
            <!-- File Coverage Stats -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-file-lines text-blue-400"></i>
                    <h3>File Coverage</h3>
                </div>
                <div class="stats-content">
                    <div class="coverage-visual">
                        <div class="coverage-circle" style="--percentage: ${result.metrics.fileCoverage}%">
                            <span class="coverage-text">${result.metrics.fileCoverage.toStringAsFixed(1)}%</span>
                        </div>
                    </div>
                    <div class="coverage-details">
                        <div class="detail-item">
                            <span class="detail-label">Total Files:</span>
                            <span class="detail-value">$totalFiles</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">Files with Keys:</span>
                            <span class="detail-value">$filesWithKeys</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">Avg Keys/File:</span>
                            <span class="detail-value">$averageKeysPerFile</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Performance Metrics with Chart -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-gauge text-green-400"></i>
                    <h3>Performance</h3>
                </div>
                <div class="performance-metrics">
                    <div class="performance-visual">
                        <canvas id="performanceChart" width="200" height="120"></canvas>
                    </div>
                    <div class="metric-grid">
                        <div class="metric-item">
                            <span class="metric-label">Scan Time</span>
                            <span class="metric-value">${(result.duration.inMilliseconds / 1000.0).toStringAsFixed(2)}s</span>
                            <span class="metric-trend ${_getPerformanceTrend(result.duration.inMilliseconds)}">
                                <i class="fa-solid ${_getPerformanceTrendIcon(result.duration.inMilliseconds)}"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Keys/Sec</span>
                            <span class="metric-value">${(result.keyUsages.length / (result.duration.inMilliseconds / 1000.0)).toStringAsFixed(0)}</span>
                            <span class="metric-trend good">
                                <i class="fa-solid fa-arrow-up"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Files/Sec</span>
                            <span class="metric-value">${(totalFiles / (result.duration.inMilliseconds / 1000.0)).toStringAsFixed(0)}</span>
                            <span class="metric-trend good">
                                <i class="fa-solid fa-arrow-up"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Efficiency</span>
                            <span class="metric-value">${_calculateEfficiency(result)}%</span>
                            <span class="metric-trend ${_getEfficiencyTrend(result)}">
                                <i class="fa-solid ${_getEfficiencyTrendIcon(result)}"></i>
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Key Distribution Chart -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-chart-pie text-purple-400"></i>
                    <h3>Key Distribution</h3>
                </div>
                <div class="distribution-content">
                    <div class="distribution-visual">
                        <canvas id="distributionChart" width="200" height="200"></canvas>
                    </div>
                    <div class="distribution-legend">
                        ${_buildDistributionLegend(result)}
                    </div>
                </div>
            </div>

            <!-- Quality Metrics -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-star text-yellow-400"></i>
                    <h3>Quality Score</h3>
                </div>
                <div class="quality-metrics">
                    <div class="quality-score">
                        <div class="score-circle" style="--score: ${_calculateQualityScore(result)}%">
                            <span class="score-text">${_calculateQualityScore(result)}</span>
                            <span class="score-label">Quality</span>
                        </div>
                    </div>
                    <div class="quality-breakdown">
                        <div class="quality-item">
                            <span class="quality-label">Coverage</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${result.metrics.fileCoverage}%"></div>
                            </div>
                            <span class="quality-value">${result.metrics.fileCoverage.toStringAsFixed(0)}%</span>
                        </div>
                        <div class="quality-item">
                            <span class="quality-label">Consistency</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${_calculateConsistency(result)}%"></div>
                            </div>
                            <span class="quality-value">${_calculateConsistency(result)}%</span>
                        </div>
                        <div class="quality-item">
                            <span class="quality-label">Organization</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${_calculateOrganization(result)}%"></div>
                            </div>
                            <span class="quality-value">${_calculateOrganization(result)}%</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Enhanced Insights with Action Items -->
            <div class="stats-card glass-card full-width">
                <div class="stats-header">
                    <i class="fa-solid fa-lightbulb text-orange-400"></i>
                    <h3>Insights & Recommendations</h3>
                </div>
                <div class="insights-content">
                    ${_buildEnhancedInsights(result)}
                </div>
            </div>
        </div>
    ''');
  }



  void _addExportSectionPage(StringBuffer buffer) {
    buffer.writeln('''
        <!-- Export Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-download section-icon"></i>
                <div class="section-title-content">
                    <h2>Export Options</h2>
                    <p class="section-subtitle">Download your Flutter KeyCheck report in various formats</p>
                </div>
            </div>
        </div>

        <!-- Export Grid -->
        <div class="export-grid">
            <!-- HTML Export -->
            <div class="export-card glass-card" onclick="exportReport('html')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-code text-blue-400"></i>
                </div>
                <div class="export-content">
                    <h3>Interactive HTML</h3>
                    <p class="export-description">Full interactive report with all features, charts, and navigation</p>
                    <div class="export-features">
                        <span class="feature-tag">Interactive</span>
                        <span class="feature-tag">Charts</span>
                        <span class="feature-tag">Search</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- JSON Export -->
            <div class="export-card glass-card" onclick="exportReport('json')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-code text-green-400"></i>
                </div>
                <div class="export-content">
                    <h3>JSON Data</h3>
                    <p class="export-description">Raw data in JSON format for programmatic processing and integration</p>
                    <div class="export-features">
                        <span class="feature-tag">API Ready</span>
                        <span class="feature-tag">Structured</span>
                        <span class="feature-tag">Lightweight</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Markdown Export -->
            <div class="export-card glass-card" onclick="exportReport('markdown')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-text text-purple-400"></i>
                </div>
                <div class="export-content">
                    <h3>Markdown Report</h3>
                    <p class="export-description">Human-readable report in Markdown format for documentation</p>
                    <div class="export-features">
                        <span class="feature-tag">Readable</span>
                        <span class="feature-tag">Git Friendly</span>
                        <span class="feature-tag">Documentation</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- CI Format Export -->
            <div class="export-card glass-card" onclick="exportReport('ci')">
                <div class="export-icon">
                    <i class="fa-solid fa-code-branch text-orange-400"></i>
                </div>
                <div class="export-content">
                    <h3>CI/CD Report</h3>
                    <p class="export-description">Optimized format for continuous integration and pipeline reporting</p>
                    <div class="export-features">
                        <span class="feature-tag">CI/CD</span>
                        <span class="feature-tag">Compact</span>
                        <span class="feature-tag">Automated</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Text Export -->
            <div class="export-card glass-card" onclick="exportReport('text')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-lines text-gray-400"></i>
                </div>
                <div class="export-content">
                    <h3>Plain Text</h3>
                    <p class="export-description">Simple text format for basic reporting and quick analysis</p>
                    <div class="export-features">
                        <span class="feature-tag">Simple</span>
                        <span class="feature-tag">Universal</span>
                        <span class="feature-tag">Minimal</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Bulk Export -->
            <div class="export-card glass-card bulk" onclick="exportAll()">
                <div class="export-icon">
                    <i class="fa-solid fa-file-zipper text-yellow-400"></i>
                </div>
                <div class="export-content">
                    <h3>Export All Formats</h3>
                    <p class="export-description">Download all available formats in a single ZIP archive</p>
                    <div class="export-features">
                        <span class="feature-tag">Complete</span>
                        <span class="feature-tag">ZIP Archive</span>
                        <span class="feature-tag">All Formats</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-file-zipper"></i>
                </div>
            </div>
        </div>

        <!-- Export Status -->
        <div id="exportStatus" class="export-status" style="display: none;">
            <div class="status-content">
                <i class="fa-solid fa-spinner fa-spin"></i>
                <span class="status-text">Preparing export...</span>
            </div>
        </div>
    ''');
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
    final impact = refCount > 5 ? 'High' : refCount > 3 ? 'Medium' : 'Low';
    final impactClass = refCount > 5 ? 'high' : refCount > 3 ? 'medium' : 'low';
    
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
    final keysPerSecond = result.keyUsages.length / (result.duration.inMilliseconds / 1000.0);
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
    final duplicates = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    if (duplicates > result.keyUsages.length * 0.1) {
      consistencyScore -= 15;
    }
    
    return consistencyScore.clamp(0, 100);
  }

  int _calculateOrganization(ScanResult result) {
    final keyNames = result.keyUsages.keys;
    var organizationScore = 85;
    
    // Check for clear categorization
    final categories = keyNames.map((name) => _inferCategory(name, <String>{})).toSet();
    final categoryRatio = categories.length / keyNames.length;
    
    if (categoryRatio > 0.8) {
      organizationScore += 10; // Very diverse, good organization
    } else if (categoryRatio < 0.3) {
      organizationScore -= 10; // Too homogeneous, might lack structure
    }
    
    // Check for descriptive naming
    final descriptiveKeys = keyNames.where((name) => name.length > 3 && !name.startsWith('key')).length;
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
      case 'Buttons': return '#3b82f6';
      case 'Input Fields': return '#10b981';
      case 'Navigation': return '#f59e0b';
      case 'Modals': return '#8b5cf6';
      case 'Lists': return '#ef4444';
      default: return '#6b7280';
    }
  }

  String _buildEnhancedInsights(ScanResult result) {
    final insights = <String>[];
    final coverage = result.metrics.fileCoverage;
    final totalKeys = result.keyUsages.length;
    final qualityScore = _calculateQualityScore(result);
    final duplicates = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    
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
    buffer.writeln('  Files Scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}');
    buffer.writeln('  Coverage: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');
    buffer.writeln();
    
    if (result.keyUsages.isNotEmpty) {
      buffer.writeln('Keys Found:');
      for (final entry in result.keyUsages.entries.take(20)) {
        buffer.writeln('  - ${entry.key} (${entry.value.locations.length} locations)');
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
  
  CIReporter({this.useColors = true}) : isGitLabCI = Platform.environment['GITLAB_CI'] == 'true';

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
      buffer.writeln('$_boldValidation Result:$_reset $color$_bold● $status$_reset');
    } else {
      buffer.writeln('Validation Result: $status');
    }
    
    if (hasViolations && result.violations.isNotEmpty) {
      buffer.writeln('\n${useColors ? '$_red$_bold❌ Critical Issues$_reset' : 'Critical Issues:'}');
      
      for (final violation in result.violations.take(10)) {
        final type = violation.type;
        final key = violation.key?.id ?? 'unknown';
        if (useColors) {
          buffer.writeln('$_red• $type: $_white$key$_reset $_dim- ${violation.message}$_reset');
        } else {
          buffer.writeln('• $type: $key - ${violation.message}');
        }
      }
      
      if (result.violations.length > 10) {
        buffer.writeln('${useColors ? _dim : ''}... and ${result.violations.length - 10} more violations${useColors ? _reset : ''}');
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
      
      buffer.writeln('$color$_bold$icon ${gate['name']}: $status$_reset $_dim- ${gate['description']}$_reset');
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
    if (useColors) buffer.writeln('$_yellow$_bold⚠️  Action Required$_reset');
    
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
      buffer.writeln('\ndetail<summary><b>📋 Key Details (${result.keyUsages.length} total)</b></summary>');
      
      final keysByCategory = <String, List<String>>{};
      for (final entry in result.keyUsages.entries) {
        final category = _categorizeKey(entry.key);
        keysByCategory.putIfAbsent(category, () => []).add(entry.key);
      }
      
      for (final entry in keysByCategory.entries) {
        buffer.writeln('\n**${entry.key.toUpperCase()} (${entry.value.length})**');
        for (final key in entry.value) {
          buffer.writeln('- `$key`');
        }
      }
      
      buffer.writeln('detail');
    }
    
    // Collapsible section for blind spots
    if (result.blindSpots.isNotEmpty) {
      buffer.writeln('\ndetail<summary><b>⚠️  Blind Spots (${result.blindSpots.length} found)</b></summary>');
      
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

  void _unusedAddAnalysisSection(StringBuffer buffer, ScanResult result) {
    final orphanKeys = result.keyUsages.values.where((k) => k.locations.isEmpty).length;
    final duplicateKeys = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    
    buffer.writeln('''
        <!-- Analysis Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-magnifying-glass-chart section-icon"></i>
                <div class="section-title-content">
                    <h2>Key Analysis</h2>
                    <p class="section-subtitle">Detailed insights and quality analysis for your Flutter keys</p>
                </div>
            </div>
        </div>

        <!-- Analysis Overview -->
        <div class="analysis-grid">
            <!-- Quality Score Card -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-award text-yellow-400"></i>
                    <h3>Quality Score</h3>
                </div>
                <div class="quality-score">
                    <div class="score-circle">
                        <span class="score-text">${(100 - (result.blindSpots.length * 5)).clamp(0, 100)}%</span>
                    </div>
                    <div class="score-details">
                        <div class="score-item">
                            <span class="label">Blind Spots:</span>
                            <span class="value ${result.blindSpots.length > 0 ? 'text-red-400' : 'text-green-400'}">${result.blindSpots.length}</span>
                        </div>
                        <div class="score-item">
                            <span class="label">Orphan Keys:</span>
                            <span class="value ${orphanKeys > 0 ? 'text-yellow-400' : 'text-green-400'}">$orphanKeys</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Key Distribution -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-chart-pie text-blue-400"></i>
                    <h3>Key Distribution</h3>
                </div>
                <div class="distribution-chart">
                    ${_buildKeyDistribution(result)}
                </div>
            </div>

            <!-- Issues Summary -->
            <div class="analysis-card glass-card">
                <div class="analysis-header">
                    <i class="fa-solid fa-triangle-exclamation text-orange-400"></i>
                    <h3>Issues Found</h3>
                </div>
                <div class="issues-list">
                    <div class="issue-item ${result.blindSpots.length > 0 ? 'critical' : 'resolved'}">
                        <i class="fa-solid fa-${result.blindSpots.length > 0 ? 'circle-exclamation' : 'circle-check'}"></i>
                        <span class="issue-text">${result.blindSpots.length} Blind Spots</span>
                        <span class="issue-severity">${result.blindSpots.length > 5 ? 'High' : result.blindSpots.length > 0 ? 'Medium' : 'None'}</span>
                    </div>
                    <div class="issue-item ${duplicateKeys > 0 ? 'warning' : 'resolved'}">
                        <i class="fa-solid fa-${duplicateKeys > 0 ? 'circle-minus' : 'circle-check'}"></i>
                        <span class="issue-text">$duplicateKeys Duplicate References</span>
                        <span class="issue-severity">${duplicateKeys > 3 ? 'Medium' : duplicateKeys > 0 ? 'Low' : 'None'}</span>
                    </div>
                    <div class="issue-item ${orphanKeys > 0 ? 'warning' : 'resolved'}">
                        <i class="fa-solid fa-${orphanKeys > 0 ? 'circle-minus' : 'circle-check'}"></i>
                        <span class="issue-text">$orphanKeys Orphan Keys</span>
                        <span class="issue-severity">${orphanKeys > 2 ? 'Medium' : orphanKeys > 0 ? 'Low' : 'None'}</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Duplicate Keys Table -->
        ${duplicateKeys > 0 ? _buildDuplicateKeysTable(result) : ''}

        <!-- Analysis Complete -->
        <div class="analysis-summary">
            <p class="analysis-note">
                <i class="fa-solid fa-info-circle"></i>
                For detailed key analysis, switch to the Dashboard section to view the full keys table.
            </p>
        </div>
    ''');
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
    if (name.contains('field') || name.contains('input') || name.contains('text')) return 'Input Fields';
    if (name.contains('menu') || name.contains('nav')) return 'Navigation';
    if (name.contains('modal') || name.contains('dialog')) return 'Modals';
    if (name.contains('list') || name.contains('item')) return 'Lists';
    return 'Other';
  }

  void _addStatsSection(StringBuffer buffer, ScanResult result) {
    final totalFiles = result.metrics.totalFiles;
    final filesWithKeys = result.fileAnalyses.values.where((fa) => fa.keysFound.isNotEmpty).length;
    final averageKeysPerFile = filesWithKeys > 0 ? (result.keyUsages.length / filesWithKeys).toStringAsFixed(1) : '0';
    
    buffer.writeln('''
        <!-- Stats Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-chart-line section-icon"></i>
                <div class="section-title-content">
                    <h2>Statistics & Metrics</h2>
                    <p class="section-subtitle">Comprehensive statistics and performance metrics for your Flutter keys</p>
                </div>
            </div>
        </div>

        <!-- Stats Grid -->
        <div class="stats-grid">
            <!-- File Coverage Stats -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-file-lines text-blue-400"></i>
                    <h3>File Coverage</h3>
                </div>
                <div class="stats-content">
                    <div class="coverage-visual">
                        <div class="coverage-circle" style="--percentage: ${result.metrics.fileCoverage}%">
                            <span class="coverage-text">${result.metrics.fileCoverage.toStringAsFixed(1)}%</span>
                        </div>
                    </div>
                    <div class="coverage-details">
                        <div class="detail-item">
                            <span class="detail-label">Total Files:</span>
                            <span class="detail-value">$totalFiles</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">Files with Keys:</span>
                            <span class="detail-value">$filesWithKeys</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">Avg Keys/File:</span>
                            <span class="detail-value">$averageKeysPerFile</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Performance Metrics with Chart -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-gauge text-green-400"></i>
                    <h3>Performance</h3>
                </div>
                <div class="performance-metrics">
                    <div class="performance-visual">
                        <canvas id="performanceChart" width="200" height="120"></canvas>
                    </div>
                    <div class="metric-grid">
                        <div class="metric-item">
                            <span class="metric-label">Scan Time</span>
                            <span class="metric-value">${(result.duration.inMilliseconds / 1000.0).toStringAsFixed(2)}s</span>
                            <span class="metric-trend ${_getPerformanceTrend(result.duration.inMilliseconds)}">
                                <i class="fa-solid ${_getPerformanceTrendIcon(result.duration.inMilliseconds)}"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Keys/Sec</span>
                            <span class="metric-value">${(result.keyUsages.length / (result.duration.inMilliseconds / 1000.0)).toStringAsFixed(0)}</span>
                            <span class="metric-trend good">
                                <i class="fa-solid fa-arrow-up"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Files/Sec</span>
                            <span class="metric-value">${(totalFiles / (result.duration.inMilliseconds / 1000.0)).toStringAsFixed(0)}</span>
                            <span class="metric-trend good">
                                <i class="fa-solid fa-arrow-up"></i>
                            </span>
                        </div>
                        <div class="metric-item">
                            <span class="metric-label">Efficiency</span>
                            <span class="metric-value">${_calculateEfficiency(result)}%</span>
                            <span class="metric-trend ${_getEfficiencyTrend(result)}">
                                <i class="fa-solid ${_getEfficiencyTrendIcon(result)}"></i>
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Key Distribution Chart -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-chart-pie text-purple-400"></i>
                    <h3>Key Distribution</h3>
                </div>
                <div class="distribution-content">
                    <div class="distribution-visual">
                        <canvas id="distributionChart" width="200" height="200"></canvas>
                    </div>
                    <div class="distribution-legend">
                        ${_buildDistributionLegend(result)}
                    </div>
                </div>
            </div>

            <!-- Quality Metrics -->
            <div class="stats-card glass-card">
                <div class="stats-header">
                    <i class="fa-solid fa-star text-yellow-400"></i>
                    <h3>Quality Score</h3>
                </div>
                <div class="quality-metrics">
                    <div class="quality-score">
                        <div class="score-circle" style="--score: ${_calculateQualityScore(result)}%">
                            <span class="score-text">${_calculateQualityScore(result)}</span>
                            <span class="score-label">Quality</span>
                        </div>
                    </div>
                    <div class="quality-breakdown">
                        <div class="quality-item">
                            <span class="quality-label">Coverage</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${result.metrics.fileCoverage}%"></div>
                            </div>
                            <span class="quality-value">${result.metrics.fileCoverage.toStringAsFixed(0)}%</span>
                        </div>
                        <div class="quality-item">
                            <span class="quality-label">Consistency</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${_calculateConsistency(result)}%"></div>
                            </div>
                            <span class="quality-value">${_calculateConsistency(result)}%</span>
                        </div>
                        <div class="quality-item">
                            <span class="quality-label">Organization</span>
                            <div class="quality-bar">
                                <div class="quality-fill" style="width: ${_calculateOrganization(result)}%"></div>
                            </div>
                            <span class="quality-value">${_calculateOrganization(result)}%</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Enhanced Insights with Action Items -->
            <div class="stats-card glass-card full-width">
                <div class="stats-header">
                    <i class="fa-solid fa-lightbulb text-orange-400"></i>
                    <h3>Insights & Recommendations</h3>
                </div>
                <div class="insights-content">
                    ${_buildEnhancedInsights(result)}
                </div>
            </div>
        </div>
    ''');
  }



  void _addExportSectionPage(StringBuffer buffer) {
    buffer.writeln('''
        <!-- Export Header -->
        <div class="section-header glass-card">
            <div class="section-title-wrapper">
                <i class="fa-solid fa-download section-icon"></i>
                <div class="section-title-content">
                    <h2>Export Options</h2>
                    <p class="section-subtitle">Download your Flutter KeyCheck report in various formats</p>
                </div>
            </div>
        </div>

        <!-- Export Grid -->
        <div class="export-grid">
            <!-- HTML Export -->
            <div class="export-card glass-card" onclick="exportReport('html')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-code text-blue-400"></i>
                </div>
                <div class="export-content">
                    <h3>Interactive HTML</h3>
                    <p class="export-description">Full interactive report with all features, charts, and navigation</p>
                    <div class="export-features">
                        <span class="feature-tag">Interactive</span>
                        <span class="feature-tag">Charts</span>
                        <span class="feature-tag">Search</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- JSON Export -->
            <div class="export-card glass-card" onclick="exportReport('json')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-code text-green-400"></i>
                </div>
                <div class="export-content">
                    <h3>JSON Data</h3>
                    <p class="export-description">Raw data in JSON format for programmatic processing and integration</p>
                    <div class="export-features">
                        <span class="feature-tag">API Ready</span>
                        <span class="feature-tag">Structured</span>
                        <span class="feature-tag">Lightweight</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Markdown Export -->
            <div class="export-card glass-card" onclick="exportReport('markdown')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-text text-purple-400"></i>
                </div>
                <div class="export-content">
                    <h3>Markdown Report</h3>
                    <p class="export-description">Human-readable report in Markdown format for documentation</p>
                    <div class="export-features">
                        <span class="feature-tag">Readable</span>
                        <span class="feature-tag">Git Friendly</span>
                        <span class="feature-tag">Documentation</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- CI Format Export -->
            <div class="export-card glass-card" onclick="exportReport('ci')">
                <div class="export-icon">
                    <i class="fa-solid fa-code-branch text-orange-400"></i>
                </div>
                <div class="export-content">
                    <h3>CI/CD Report</h3>
                    <p class="export-description">Optimized format for continuous integration and pipeline reporting</p>
                    <div class="export-features">
                        <span class="feature-tag">CI/CD</span>
                        <span class="feature-tag">Compact</span>
                        <span class="feature-tag">Automated</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Text Export -->
            <div class="export-card glass-card" onclick="exportReport('text')">
                <div class="export-icon">
                    <i class="fa-solid fa-file-lines text-gray-400"></i>
                </div>
                <div class="export-content">
                    <h3>Plain Text</h3>
                    <p class="export-description">Simple text format for basic reporting and quick analysis</p>
                    <div class="export-features">
                        <span class="feature-tag">Simple</span>
                        <span class="feature-tag">Universal</span>
                        <span class="feature-tag">Minimal</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-download"></i>
                </div>
            </div>

            <!-- Bulk Export -->
            <div class="export-card glass-card bulk" onclick="exportAll()">
                <div class="export-icon">
                    <i class="fa-solid fa-file-zipper text-yellow-400"></i>
                </div>
                <div class="export-content">
                    <h3>Export All Formats</h3>
                    <p class="export-description">Download all available formats in a single ZIP archive</p>
                    <div class="export-features">
                        <span class="feature-tag">Complete</span>
                        <span class="feature-tag">ZIP Archive</span>
                        <span class="feature-tag">All Formats</span>
                    </div>
                </div>
                <div class="export-action">
                    <i class="fa-solid fa-file-zipper"></i>
                </div>
            </div>
        </div>

        <!-- Export Status -->
        <div id="exportStatus" class="export-status" style="display: none;">
            <div class="status-content">
                <i class="fa-solid fa-spinner fa-spin"></i>
                <span class="status-text">Preparing export...</span>
            </div>
        </div>
    ''');
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
    final impact = refCount > 5 ? 'High' : refCount > 3 ? 'Medium' : 'Low';
    final impactClass = refCount > 5 ? 'high' : refCount > 3 ? 'medium' : 'low';
    
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
    if (keyName.toLowerCase().contains('button') || keyName.toLowerCase().contains('widget')) return 'widget';
    if (keyName.toLowerCase().contains('test')) return 'test';
    if (keyName.toLowerCase().contains('navigate') || keyName.toLowerCase().contains('route')) return 'navigation';
    if (keyName.toLowerCase().contains('handle') || keyName.toLowerCase().contains('on')) return 'handler';
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
    final keysPerSecond = result.keyUsages.length / (result.duration.inMilliseconds / 1000.0);
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
    final duplicates = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    if (duplicates > result.keyUsages.length * 0.1) {
      consistencyScore -= 15;
    }
    
    return consistencyScore.clamp(0, 100);
  }

  int _calculateOrganization(ScanResult result) {
    final keyNames = result.keyUsages.keys;
    var organizationScore = 85;
    
    // Check for clear categorization
    final categories = keyNames.map((name) => _inferCategory(name, <String>{})).toSet();
    final categoryRatio = categories.length / keyNames.length;
    
    if (categoryRatio > 0.8) {
      organizationScore += 10; // Very diverse, good organization
    } else if (categoryRatio < 0.3) {
      organizationScore -= 10; // Too homogeneous, might lack structure
    }
    
    // Check for descriptive naming
    final descriptiveKeys = keyNames.where((name) => name.length > 3 && !name.startsWith('key')).length;
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
      case 'Buttons': return '#3b82f6';
      case 'Input Fields': return '#10b981';
      case 'Navigation': return '#f59e0b';
      case 'Modals': return '#8b5cf6';
      case 'Lists': return '#ef4444';
      default: return '#6b7280';
    }
  }

  String _buildEnhancedInsights(ScanResult result) {
    final insights = <String>[];
    final coverage = result.metrics.fileCoverage;
    final totalKeys = result.keyUsages.length;
    final qualityScore = _calculateQualityScore(result);
    final duplicates = result.keyUsages.values.where((k) => k.locations.length > 1).length;
    
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
