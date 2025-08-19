import 'dart:io';
import '../models/scan_result.dart';
import 'base_formatter.dart';

/// CI/CD-optimized formatter with beautiful terminal output
class CIFormatter extends BaseFormatter {
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

  final bool useColors;
  final bool isGitLabCI;
  
  CIFormatter({this.useColors = true}) : isGitLabCI = Platform.environment['GITLAB_CI'] == 'true';

  @override
  String format(ScanResult result) {
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
    
    return buffer.toString();
  }

  String _formatHeader() {
    if (!useColors) return '=== Flutter KeyCheck CI Report ===\n';
    
    return '''
${_cyan}╔═══════════════════════════════════════════════════════════╗
║${_bold}${_white}                 🔑 FLUTTER KEYCHECK                    ${_reset}${_cyan}║
║${_dim}                  CI/CD Analysis Report                   ${_reset}${_cyan}║
╚═══════════════════════════════════════════════════════════╝${_reset}
''';
  }

  String _formatStatus(ScanResult result) {
    final hasIssues = result.blindSpots.isNotEmpty || result.violations.isNotEmpty;
    final status = hasIssues ? 'WARNING' : 'PASSED';
    final color = hasIssues ? _yellow : _green;
    
    if (!useColors) return 'Status: $status\n';
    
    return '''
${_bold}Build Status:${_reset} ${color}${_bold}● $status${_reset}
''';
  }

  String _formatMetrics(ScanResult result) {
    if (!useColors) {
      return '''
Metrics:
  Keys Found: ${result.keys.length}
  Files Scanned: ${result.metrics.scannedFiles}/${result.metrics.totalFiles}
  Coverage: ${result.metrics.fileCoverage.toFixed(1)}%
  Scan Time: ${result.metrics.scanDuration.inMilliseconds}ms
''';
    }

    return '''
${_bold}📊 Key Metrics${_reset}
${_cyan}┌─────────────────┬────────────────────────────────┐
│${_bold} Metric          ${_reset}${_cyan}│${_bold} Value                          ${_reset}${_cyan}│
├─────────────────┼────────────────────────────────┤
│ Keys Found      │${_green}${_bold} ${result.keys.length.toString().padLeft(30)} ${_reset}${_cyan}│
│ Files Scanned   │${_blue}${_bold} ${result.metrics.scannedFiles}/${result.metrics.totalFiles}${('').padLeft(24 - '${result.metrics.scannedFiles}/${result.metrics.totalFiles}'.length)} ${_reset}${_cyan}│
│ Coverage        │${_yellow}${_bold} ${result.metrics.fileCoverage.toFixed(1)}%${('').padLeft(25 - '${result.metrics.fileCoverage.toFixed(1)}%'.length)} ${_reset}${_cyan}│
│ Scan Duration   │${_magenta}${_bold} ${result.metrics.scanDuration.inMilliseconds}ms${('').padLeft(25 - '${result.metrics.scanDuration.inMilliseconds}ms'.length)} ${_reset}${_cyan}│
└─────────────────┴────────────────────────────────┘${_reset}
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
    buffer.writeln('${_bold}🎯 Quality Gates${_reset}');
    
    for (final gate in gates) {
      final icon = gate['status'] == 'PASS' ? '✓' : '✗';
      final color = gate['status'] == 'PASS' ? _green : _red;
      final status = gate['status'] == 'PASS' ? 'PASS' : 'FAIL';
      
      buffer.writeln('${color}${_bold}$icon ${gate['name']}: $status${_reset} ${_dim}- ${gate['description']}${_reset}');
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
        'name': 'Key Consistency',
        'status': result.violations.isEmpty ? 'PASS' : 'FAIL',
        'description': 'No key naming violations found'
      },
      {
        'name': 'Blind Spot Check',
        'status': result.blindSpots.length <= 5 ? 'PASS' : 'WARN',
        'description': 'Maximum 5 blind spots allowed'
      },
      {
        'name': 'Performance Gate',
        'status': result.metrics.scanDuration.inSeconds < 30 ? 'PASS' : 'WARN',
        'description': 'Scan completed under 30 seconds'
      }
    ];
  }

  String _formatSummary(ScanResult result) {
    final hasErrors = result.violations.isNotEmpty;
    final hasWarnings = result.blindSpots.isNotEmpty;
    
    if (!hasErrors && !hasWarnings) {
      return useColors 
        ? '${_green}${_bold}🎉 All checks passed! Your Flutter app is ready for automation testing.${_reset}\n'
        : '✓ All checks passed! Your Flutter app is ready for automation testing.\n';
    }
    
    final buffer = StringBuffer();
    if (useColors) buffer.writeln('${_yellow}${_bold}⚠️  Action Required${_reset}');
    
    if (hasErrors) {
      buffer.writeln(useColors 
        ? '${_red}• ${result.violations.length} violations found${_reset}'
        : '• ${result.violations.length} violations found');
    }
    
    if (hasWarnings) {
      buffer.writeln(useColors 
        ? '${_yellow}• ${result.blindSpots.length} blind spots detected${_reset}'
        : '• ${result.blindSpots.length} blind spots detected');
    }
    
    return buffer.toString();
  }

  String _formatGitLabSections(ScanResult result) {
    final buffer = StringBuffer();
    
    // Collapsible section for detailed results
    if (result.keys.isNotEmpty) {
      buffer.writeln('\ndetail<summary><b>📋 Key Details (${result.keys.length} total)</b></summary>');
      
      final keysByCategory = <String, List<String>>{};
      for (final key in result.keys) {
        final category = _categorizeKey(key);
        keysByCategory.putIfAbsent(category, () => []).add(key);
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
        buffer.writeln('- **${spot.file}**: ${spot.reason}');
        if (spot.suggestion != null) {
          buffer.writeln('  *Suggestion: ${spot.suggestion}*');
        }
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
}