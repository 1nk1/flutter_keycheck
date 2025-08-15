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
      default:
        return JsonReporter();
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
    final report = {
      'schema_version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'scan_type': result.metrics.incrementalScan ? 'incremental' : 'full',
    };

    if (result.metrics.incrementalScan) {
      report['incremental_base'] = result.metrics.incrementalBase;
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
        keyData['locations'] = entry.value.locations.map((loc) => {
          'file': loc.file,
          'line': loc.line,
          'column': loc.column,
          'detector': loc.detector,
          'context': loc.context,
        }).toList();
      }

      keys.add(keyData);
    }
    report['keys'] = keys;

    // Add blind spots
    if (result.blindSpots.isNotEmpty) {
      report['blind_spots'] = result.blindSpots.map((spot) => spot.toMap()).toList();
    }

    // Add errors if any
    if (result.metrics.errors.isNotEmpty) {
      report['errors'] = result.metrics.errors.map((err) => err.toMap()).toList();
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
    buffer.writeln('<testsuites name="Flutter KeyCheck Scan" tests="${result.keyUsages.length}">');
    
    // Group by package
    final keysByPackage = <String, List<MapEntry<String, KeyUsage>>>{};
    for (final entry in result.keyUsages.entries) {
      final package = _getPackageFromPath(entry.value.locations.first.file);
      keysByPackage.putIfAbsent(package, () => []).add(entry);
    }
    
    for (final packageEntry in keysByPackage.entries) {
      buffer.writeln('  <testsuite name="${packageEntry.key}" tests="${packageEntry.value.length}">');
      
      for (final keyEntry in packageEntry.value) {
        buffer.writeln('    <testcase name="Key: ${keyEntry.key}" classname="Found">');
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
        buffer.writeln('    <testcase name="Key: ${violation.key?.id ?? 'policy'}" '
            'classname="${violation.type}">');
        buffer.writeln('      <failure message="${_escapeXml(violation.message)}">');
        buffer.writeln('        ${_escapeXml(violation.message)}');
        if (violation.key != null) {
          buffer.writeln('        Key: ${violation.key!.id}');
          buffer.writeln('        Tags: ${violation.key!.tags.join(', ')}');
          if (violation.key!.lastSeen != null) {
            buffer.writeln('        Last seen: ${violation.key!.lastSeen}');
          }
        }
        buffer.writeln('        Remediation: ${_escapeXml(violation.remediation)}');
        buffer.writeln('      </failure>');
        buffer.writeln('    </testcase>');
      }
      
      buffer.writeln('  </testsuite>');
    }
    
    // Add summary as properties
    buffer.writeln('  <properties>');
    buffer.writeln('    <property name="total_keys" value="${result.summary.totalKeys}"/>');
    buffer.writeln('    <property name="lost_keys" value="${result.summary.lostKeys}"/>');
    buffer.writeln('    <property name="added_keys" value="${result.summary.addedKeys}"/>');
    buffer.writeln('    <property name="renamed_keys" value="${result.summary.renamedKeys}"/>');
    buffer.writeln('    <property name="drift_percentage" value="${result.summary.driftPercentage.toStringAsFixed(1)}"/>');
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
    buffer.writeln('- **File Coverage**: ${result.metrics.fileCoverage.toStringAsFixed(1)}%');
    buffer.writeln('- **Widget Coverage**: ${result.metrics.widgetCoverage.toStringAsFixed(1)}%');
    buffer.writeln('- **Handler Coverage**: ${result.metrics.handlerCoverage.toStringAsFixed(1)}%');
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
        final icon = spot.severity == 'error' ? '🔴' : 
                     spot.severity == 'warning' ? '🟡' : 'ℹ️';
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
    buffer.writeln('- **Drift**: ${result.summary.driftPercentage.toStringAsFixed(1)}% 📈');
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
        final icon = violation.type == 'lost' ? '🔥' :
                     violation.type == 'renamed' ? '♻️' :
                     violation.type == 'extra' ? '➕' : '⚠️';
        
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