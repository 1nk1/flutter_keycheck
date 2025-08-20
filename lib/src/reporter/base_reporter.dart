/// Base reporter interface for generating reports
/// 
/// This provides the foundation for multiple report formats
/// including human-readable, JSON, HTML, Markdown, and JUnit.
library;

import 'dart:convert';
import 'dart:io';
import 'html_reporter.dart' as html;
import 'ci_reporter.dart' as ci;

/// Result data for report generation
class ReportData {
  final Set<String> expectedKeys;
  final Set<String> foundKeys;
  final Set<String> missingKeys;
  final Set<String> extraKeys;
  final Map<String, int>? keyUsageCounts;
  final Map<String, List<dynamic>>? keyLocations;
  final Duration? scanDuration;
  final List<String>? scannedFiles;
  final Map<String, dynamic>? metrics;
  final String projectPath;
  final DateTime timestamp;

  ReportData({
    required this.expectedKeys,
    required this.foundKeys,
    required this.missingKeys,
    required this.extraKeys,
    this.keyUsageCounts,
    this.keyLocations,
    this.scanDuration,
    this.scannedFiles,
    this.metrics,
    required this.projectPath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Calculate coverage percentage
  double get coverage {
    if (expectedKeys.isEmpty) return 100.0;
    final covered = expectedKeys.length - missingKeys.length;
    return (covered / expectedKeys.length) * 100;
  }

  /// Check if validation passed
  bool get passed => missingKeys.isEmpty;

  /// Get summary statistics
  Map<String, dynamic> get summary => {
        'expected': expectedKeys.length,
        'found': foundKeys.length,
        'missing': missingKeys.length,
        'extra': extraKeys.length,
        'coverage': coverage,
        'passed': passed,
      };
}

/// Abstract base class for report generators
abstract class BaseReporter {
  /// Generate report as a string
  String generate(ReportData data);

  /// Write report to a file
  Future<void> writeToFile(ReportData data, String path) async {
    final content = generate(data);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Get the file extension for this report type
  String get fileExtension;

  /// Get the report type name
  String get reportType;
}

/// Factory for creating reporters
class ReporterFactory {
  static BaseReporter create(String format) {
    switch (format.toLowerCase()) {
      case 'json':
        return JsonReporter();
      case 'html':
        return html.HtmlReporter();
      case 'html-premium':
        return html.HtmlReporter(darkTheme: false, includeCharts: true, responsive: true);
      case 'html-dark':
        return html.HtmlReporter(darkTheme: true, includeCharts: true, responsive: true);
      case 'ci':
        return ci.CIReporter.autoDetect();
      case 'ci-verbose':
        return ci.CIReporter.autoDetect(verbose: true);
      case 'markdown':
      case 'md':
        return MarkdownReporter();
      case 'junit':
      case 'xml':
        return JUnitReporter();
      case 'human':
      default:
        return HumanReporter();
    }
  }

  /// Get list of available formats
  static List<String> get availableFormats => [
        'human',
        'json',
        'html',
        'html-premium',
        'html-dark',
        'ci',
        'ci-verbose',
        'markdown',
        'junit',
      ];
}

/// Human-readable console reporter (default)
class HumanReporter extends BaseReporter {
  @override
  String generate(ReportData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('\n' + '=' * 60);
    buffer.writeln('Flutter KeyCheck Report');
    buffer.writeln('=' * 60);
    buffer.writeln('Project: ${data.projectPath}');
    buffer.writeln('Timestamp: ${data.timestamp.toIso8601String()}');
    
    if (data.scanDuration != null) {
      buffer.writeln('Scan Duration: ${data.scanDuration!.inMilliseconds}ms');
    }
    
    if (data.scannedFiles != null) {
      buffer.writeln('Files Scanned: ${data.scannedFiles!.length}');
    }
    
    buffer.writeln('\n--- Summary ---');
    buffer.writeln('Expected Keys: ${data.expectedKeys.length}');
    buffer.writeln('Found Keys: ${data.foundKeys.length}');
    buffer.writeln('Missing Keys: ${data.missingKeys.length}');
    buffer.writeln('Extra Keys: ${data.extraKeys.length}');
    buffer.writeln('Coverage: ${data.coverage.toStringAsFixed(1)}%');
    buffer.writeln('Status: ${data.passed ? "✅ PASSED" : "❌ FAILED"}');
    
    if (data.missingKeys.isNotEmpty) {
      buffer.writeln('\n--- Missing Keys ---');
      for (final key in data.missingKeys) {
        buffer.writeln('  ❌ $key');
      }
    }
    
    if (data.extraKeys.isNotEmpty) {
      buffer.writeln('\n--- Extra Keys ---');
      for (final key in data.extraKeys) {
        buffer.writeln('  ⚠️ $key');
      }
    }
    
    if (data.keyUsageCounts != null && data.keyUsageCounts!.isNotEmpty) {
      buffer.writeln('\n--- Key Usage Counts ---');
      final sortedKeys = data.keyUsageCounts!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (final entry in sortedKeys.take(10)) {
        buffer.writeln('  ${entry.key}: ${entry.value} usage(s)');
      }
      
      if (sortedKeys.length > 10) {
        buffer.writeln('  ... and ${sortedKeys.length - 10} more');
      }
    }
    
    buffer.writeln('\n' + '=' * 60);
    
    return buffer.toString();
  }

  @override
  String get fileExtension => 'txt';

  @override
  String get reportType => 'Human-Readable';
}

/// JSON reporter for programmatic consumption
class JsonReporter extends BaseReporter {
  @override
  String generate(ReportData data) {
    final report = {
      'timestamp': data.timestamp.toIso8601String(),
      'projectPath': data.projectPath,
      'summary': data.summary,
      'expectedKeys': data.expectedKeys.toList()..sort(),
      'foundKeys': data.foundKeys.toList()..sort(),
      'missingKeys': data.missingKeys.toList()..sort(),
      'extraKeys': data.extraKeys.toList()..sort(),
    };
    
    if (data.scanDuration != null) {
      report['scanDuration'] = data.scanDuration!.inMilliseconds;
    }
    
    if (data.scannedFiles != null) {
      report['scannedFiles'] = data.scannedFiles!;
    }
    
    if (data.keyUsageCounts != null) {
      report['keyUsageCounts'] = data.keyUsageCounts!;
    }
    
    if (data.keyLocations != null) {
      report['keyLocations'] = data.keyLocations!;
    }
    
    if (data.metrics != null) {
      report['metrics'] = data.metrics!;
    }
    
    // Use custom JSON encoder for pretty printing
    return _prettyJsonEncode(report);
  }
  
  String _prettyJsonEncode(Map<String, dynamic> object) {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(object);
  }

  @override
  String get fileExtension => 'json';

  @override
  String get reportType => 'JSON';
}

/// Markdown reporter for documentation
class MarkdownReporter extends BaseReporter {
  @override
  String generate(ReportData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('# Flutter KeyCheck Report\n');
    buffer.writeln('**Project:** `${data.projectPath}`  ');
    buffer.writeln('**Timestamp:** ${data.timestamp.toIso8601String()}  ');
    buffer.writeln('**Coverage:** ${data.coverage.toStringAsFixed(1)}%  ');
    buffer.writeln('**Status:** ${data.passed ? "✅ PASSED" : "❌ FAILED"}\n');
    
    buffer.writeln('## Summary\n');
    buffer.writeln('| Metric | Count |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Expected Keys | ${data.expectedKeys.length} |');
    buffer.writeln('| Found Keys | ${data.foundKeys.length} |');
    buffer.writeln('| Missing Keys | ${data.missingKeys.length} |');
    buffer.writeln('| Extra Keys | ${data.extraKeys.length} |');
    
    if (data.missingKeys.isNotEmpty) {
      buffer.writeln('\n## Missing Keys\n');
      for (final key in data.missingKeys) {
        buffer.writeln('- ❌ `$key`');
      }
    }
    
    if (data.extraKeys.isNotEmpty) {
      buffer.writeln('\n## Extra Keys\n');
      for (final key in data.extraKeys) {
        buffer.writeln('- ⚠️ `$key`');
      }
    }
    
    return buffer.toString();
  }

  @override
  String get fileExtension => 'md';

  @override
  String get reportType => 'Markdown';
}

/// JUnit XML reporter for CI/CD integration
class JUnitReporter extends BaseReporter {
  @override
  String generate(ReportData data) {
    final testTime = (data.scanDuration?.inMilliseconds ?? 0) / 1000.0;
    final failures = data.missingKeys.length;
    final tests = data.expectedKeys.length;
    
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<testsuites name="Flutter KeyCheck" tests="$tests" failures="$failures">');
    buffer.writeln('  <testsuite name="Key Validation" tests="$tests" failures="$failures" time="$testTime">');
    
    for (final key in data.expectedKeys) {
      final passed = !data.missingKeys.contains(key);
      buffer.writeln('    <testcase name="$key" classname="KeyValidation">');
      if (!passed) {
        buffer.writeln('      <failure message="Key not found in project">Missing key: $key</failure>');
      }
      buffer.writeln('    </testcase>');
    }
    
    buffer.writeln('  </testsuite>');
    buffer.writeln('</testsuites>');
    
    return buffer.toString();
  }

  @override
  String get fileExtension => 'xml';

  @override
  String get reportType => 'JUnit XML';
}