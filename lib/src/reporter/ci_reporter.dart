/// Enhanced CI/CD reporter with beautiful terminal output
///
/// Provides rich terminal formatting with ANSI colors, GitLab CI collapsible
/// sections, quality gates visualization, and progress indicators.
library;

import 'dart:io';
import 'base_reporter.dart';
import '../quality/quality_scorer.dart';
import '../stats/stats_calculator.dart';
import '../models/scan_result.dart';

/// ANSI color codes for terminal output
class AnsiColors {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';
  static const String italic = '\x1B[3m';
  static const String underline = '\x1B[4m';

  // Foreground colors
  static const String black = '\x1B[30m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';

  // Bright colors
  static const String brightRed = '\x1B[91m';
  static const String brightGreen = '\x1B[92m';
  static const String brightYellow = '\x1B[93m';
  static const String brightBlue = '\x1B[94m';
  static const String brightMagenta = '\x1B[95m';
  static const String brightCyan = '\x1B[96m';

  // Background colors
  static const String bgRed = '\x1B[41m';
  static const String bgGreen = '\x1B[42m';
  static const String bgYellow = '\x1B[43m';
  static const String bgBlue = '\x1B[44m';
}

/// CI platform detection and formatting
enum CIPlatform {
  github,
  gitlab,
  jenkins,
  azure,
  bitbucket,
  generic,
}

/// Enhanced CI reporter with rich formatting
class CIReporter extends BaseReporter {
  final bool enableColors;
  final bool enableEmojis;
  final CIPlatform platform;
  final bool verbose;

  CIReporter({
    this.enableColors = true,
    this.enableEmojis = true,
    this.platform = CIPlatform.generic,
    this.verbose = false,
  });

  /// Factory constructor to auto-detect CI platform
  factory CIReporter.autoDetect({bool verbose = false}) {
    final platform = _detectCIPlatform();
    final enableColors = _shouldEnableColors();

    return CIReporter(
      enableColors: enableColors,
      enableEmojis:
          platform != CIPlatform.jenkins, // Jenkins doesn't handle emojis well
      platform: platform,
      verbose: verbose,
    );
  }

  @override
  String generate(ReportData data) {
    final buffer = StringBuffer();

    // Generate quality analysis
    final quality = QualityScorer.calculateQuality(
      expectedKeys: data.expectedKeys,
      foundKeys: data.foundKeys,
      missingKeys: data.missingKeys,
      extraKeys: data.extraKeys,
      keyUsageCounts: data.keyUsageCounts,
      keyLocations: data.keyLocations,
      scannedFiles: data.scannedFiles,
      scanDuration: data.scanDuration,
    );

    // Generate statistics
    final stats = StatsCalculator.calculateStatistics(
      expectedKeys: data.expectedKeys,
      foundKeys: data.foundKeys,
      missingKeys: data.missingKeys,
      extraKeys: data.extraKeys,
      keyUsageCounts: data.keyUsageCounts,
      keyLocations: data.keyLocations,
      scannedFiles: data.scannedFiles,
      scanDuration: data.scanDuration,
    );

    // Header section
    _writeHeader(buffer, data, quality);

    // Summary section
    _writeSummary(buffer, data, quality, stats);

    // Quality gates section
    _writeQualityGates(buffer, quality);

    // Issues section
    _writeIssues(buffer, data);

    // Performance section
    if (verbose) {
      _writePerformanceMetrics(buffer, data, stats);
    }

    // Recommendations section
    _writeRecommendations(buffer, quality);

    // Footer section
    _writeFooter(buffer, data, quality);

    return buffer.toString();
  }

  /// Write colorized header with status
  void _writeHeader(
      StringBuffer buffer, ReportData data, QualityBreakdown quality) {
    final status = data.passed ? 'PASSED' : 'FAILED';
    final statusColor =
        data.passed ? AnsiColors.brightGreen : AnsiColors.brightRed;
    final statusEmoji = data.passed ? '✅' : '❌';

    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection(
          'flutter_keycheck_summary', 'Flutter KeyCheck Report'));
    }

    buffer.writeln(_colorize('╭${'─' * 58}╮', AnsiColors.blue));
    buffer.writeln(_colorize(
        '│${_center('🔑 FLUTTER KEYCHECK REPORT', 58)}│', AnsiColors.blue));
    buffer.writeln(_colorize('╰${'─' * 58}╯', AnsiColors.blue));
    buffer.writeln();

    // Status line with color and emoji
    final statusLine = enableEmojis ? '$statusEmoji $status' : status;
    buffer.writeln(_colorize('Status: ', AnsiColors.white) +
        _colorize(statusLine, statusColor + AnsiColors.bold));

    // Quality score with color coding
    final qualityScore = quality.overall.toStringAsFixed(1);
    final qualityColor = _getQualityColor(quality.overall);
    final qualityEmoji = _getQualityEmoji(quality.overall);
    buffer.writeln(_colorize('Quality: ', AnsiColors.white) +
        _colorize(
            '$qualityEmoji $qualityScore/100', qualityColor + AnsiColors.bold));

    // Coverage with progress bar
    final coverage = data.coverage.toStringAsFixed(1);
    final coverageBar = _createProgressBar(data.coverage, 30);
    buffer.writeln(_colorize('Coverage: ', AnsiColors.white) +
        _colorize('$coverage% ', _getCoverageColor(data.coverage)) +
        coverageBar);

    buffer.writeln();
  }

  /// Write summary statistics table
  void _writeSummary(StringBuffer buffer, ReportData data,
      QualityBreakdown quality, KeyStatistics stats) {
    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection('summary', 'Summary Statistics'));
    } else {
      buffer.writeln(
          _colorize('📊 SUMMARY', AnsiColors.brightBlue + AnsiColors.bold));
    }

    buffer.writeln();

    // Create a formatted table
    final rows = [
      ['Metric', 'Value', 'Status'],
      ['─' * 20, '─' * 12, '─' * 8],
      [
        'Expected Keys',
        '${data.expectedKeys.length}',
        _getCountStatus(data.expectedKeys.length)
      ],
      [
        'Found Keys',
        '${data.foundKeys.length}',
        _getCountStatus(data.foundKeys.length)
      ],
      [
        'Missing Keys',
        '${data.missingKeys.length}',
        _getMissingStatus(data.missingKeys.length)
      ],
      [
        'Extra Keys',
        '${data.extraKeys.length}',
        _getExtraStatus(data.extraKeys.length)
      ],
      [
        'Coverage',
        '${data.coverage.toStringAsFixed(1)}%',
        _getCoverageStatus(data.coverage)
      ],
      [
        'Quality Score',
        '${quality.overall.toStringAsFixed(1)}/100',
        _getQualityStatus(quality.overall)
      ],
    ];

    if (data.scannedFiles != null) {
      rows.add([
        'Files Scanned',
        '${data.scannedFiles!.length}',
        _getCountStatus(data.scannedFiles!.length)
      ]);
    }

    if (data.scanDuration != null) {
      rows.add([
        'Scan Time',
        '${data.scanDuration!.inMilliseconds}ms',
        _getPerformanceStatus(data.scanDuration!)
      ]);
    }

    for (final row in rows) {
      if (row[0].startsWith('─')) {
        buffer.writeln(
            _colorize('  ${row[0]}   ${row[1]}   ${row[2]}', AnsiColors.dim));
      } else if (row[0] == 'Metric') {
        buffer.writeln(_colorize(
            '  ${_padRight(row[0], 20)} ${_padRight(row[1], 12)} ${row[2]}',
            AnsiColors.white + AnsiColors.bold));
      } else {
        buffer.writeln(
            '  ${_padRight(row[0], 20)} ${_padRight(row[1], 12)} ${row[2]}');
      }
    }

    buffer.writeln();
  }

  /// Write quality gates visualization
  void _writeQualityGates(StringBuffer buffer, QualityBreakdown quality) {
    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection('quality_gates', 'Quality Gates'));
    } else {
      buffer.writeln(_colorize(
          '🎯 QUALITY GATES', AnsiColors.brightBlue + AnsiColors.bold));
    }

    buffer.writeln();

    final gates = [
      ('Coverage', quality.coverage, 80.0),
      ('Organization', quality.organization, 70.0),
      ('Consistency', quality.consistency, 75.0),
      ('Efficiency', quality.efficiency, 70.0),
      ('Maintainability', quality.maintainability, 65.0),
    ];

    for (final gate in gates) {
      final name = gate.$1;
      final score = gate.$2;
      final threshold = gate.$3;
      final passed = score >= threshold;

      final statusIcon = passed ? '✅' : '❌';
      final statusColor = passed ? AnsiColors.green : AnsiColors.red;
      final progressBar = _createProgressBar(score, 20);

      buffer.writeln(
          '  ${enableEmojis ? statusIcon : (passed ? "PASS" : "FAIL")} ${_colorize(_padRight(name, 15), AnsiColors.white)}${_colorize('${score.toStringAsFixed(1)}%'.padLeft(6), statusColor)} $progressBar ${_colorize('(threshold: ${threshold.toStringAsFixed(0)}%)', AnsiColors.dim)}');
    }

    buffer.writeln();
  }

  /// Write issues section with categorization
  void _writeIssues(StringBuffer buffer, ReportData data) {
    final hasIssues = data.missingKeys.isNotEmpty || data.extraKeys.isNotEmpty;

    if (!hasIssues) {
      buffer.writeln(_colorize(
          '✨ NO ISSUES FOUND', AnsiColors.brightGreen + AnsiColors.bold));
      buffer.writeln(
          _colorize('  All keys are properly organized!', AnsiColors.green));
      buffer.writeln();
      return;
    }

    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection('issues', 'Issues Found'));
    } else {
      buffer.writeln(
          _colorize('🚨 ISSUES FOUND', AnsiColors.brightRed + AnsiColors.bold));
    }

    buffer.writeln();

    // Missing keys (critical issues)
    if (data.missingKeys.isNotEmpty) {
      buffer.writeln(_colorize(
          '  🔴 CRITICAL: Missing Keys (${data.missingKeys.length})',
          AnsiColors.brightRed + AnsiColors.bold));

      final sortedMissing = data.missingKeys.toList()..sort();
      for (final key in sortedMissing.take(10)) {
        buffer.writeln(_colorize('    ❌ $key', AnsiColors.red));
      }

      if (sortedMissing.length > 10) {
        buffer.writeln(_colorize(
            '    ... and ${sortedMissing.length - 10} more', AnsiColors.dim));
      }
      buffer.writeln();
    }

    // Extra keys (warnings)
    if (data.extraKeys.isNotEmpty) {
      buffer.writeln(_colorize(
          '  🟡 WARNING: Extra Keys (${data.extraKeys.length})',
          AnsiColors.brightYellow + AnsiColors.bold));

      final sortedExtra = data.extraKeys.toList()..sort();
      for (final key in sortedExtra.take(10)) {
        buffer.writeln(_colorize('    ⚠️ $key', AnsiColors.yellow));
      }

      if (sortedExtra.length > 10) {
        buffer.writeln(_colorize(
            '    ... and ${sortedExtra.length - 10} more', AnsiColors.dim));
      }
      buffer.writeln();
    }

    // Usage analysis
    if (data.keyUsageCounts != null && data.keyUsageCounts!.isNotEmpty) {
      final duplicates = data.keyUsageCounts!.entries
          .where((entry) => entry.value > 1)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (duplicates.isNotEmpty) {
        buffer.writeln(_colorize(
            '  🔵 INFO: Duplicate Usage (${duplicates.length})',
            AnsiColors.brightCyan + AnsiColors.bold));

        for (final entry in duplicates.take(5)) {
          buffer.writeln(_colorize(
              '    🔄 ${entry.key}: ${entry.value} usage(s)', AnsiColors.cyan));
        }

        if (duplicates.length > 5) {
          buffer.writeln(_colorize(
              '    ... and ${duplicates.length - 5} more', AnsiColors.dim));
        }
        buffer.writeln();
      }
    }
  }

  /// Write performance metrics
  void _writePerformanceMetrics(
      StringBuffer buffer, ReportData data, KeyStatistics stats) {
    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection('performance', 'Performance Metrics'));
    } else {
      buffer.writeln(_colorize(
          '⚡ PERFORMANCE', AnsiColors.brightMagenta + AnsiColors.bold));
    }

    buffer.writeln();

    if (data.scanDuration != null) {
      final duration = data.scanDuration!;
      final keysPerSec = duration.inMilliseconds > 0
          ? (data.foundKeys.length * 1000) / duration.inMilliseconds
          : 0;

      buffer.writeln(
          '  ${_colorize('Scan Time:', AnsiColors.white)} ${duration.inMilliseconds}ms');
      buffer.writeln(
          '  ${_colorize('Keys/Second:', AnsiColors.white)} ${keysPerSec.toStringAsFixed(1)}');

      if (data.scannedFiles != null) {
        final filesPerSec = duration.inMilliseconds > 0
            ? (data.scannedFiles!.length * 1000) / duration.inMilliseconds
            : 0;
        buffer.writeln(
            '  ${_colorize('Files/Second:', AnsiColors.white)} ${filesPerSec.toStringAsFixed(1)}');
      }
    }

    final performanceScore = stats.performance['score'] ?? 0.0;
    final performanceColor = _getPerformanceColor(performanceScore);
    buffer.writeln(
        '  ${_colorize('Performance Score:', AnsiColors.white)} ${_colorize('${performanceScore.toStringAsFixed(1)}/100', performanceColor)}');

    buffer.writeln();
  }

  /// Write recommendations
  void _writeRecommendations(StringBuffer buffer, QualityBreakdown quality) {
    if (quality.recommendations.isEmpty) return;

    if (platform == CIPlatform.gitlab) {
      buffer.writeln(_gitlabSection('recommendations', 'Recommendations'));
    } else {
      buffer.writeln(_colorize(
          '💡 RECOMMENDATIONS', AnsiColors.brightYellow + AnsiColors.bold));
    }

    buffer.writeln();

    for (final recommendation in quality.recommendations.take(5)) {
      buffer.writeln(_colorize('  • $recommendation', AnsiColors.yellow));
    }

    if (quality.recommendations.length > 5) {
      buffer.writeln(_colorize(
          '  ... and ${quality.recommendations.length - 5} more recommendations',
          AnsiColors.dim));
    }

    buffer.writeln();
  }

  /// Write footer with summary
  void _writeFooter(
      StringBuffer buffer, ReportData data, QualityBreakdown quality) {
    buffer.writeln(_colorize('╭${'─' * 58}╮', AnsiColors.blue));

    final status = data.passed ? 'SUCCESS' : 'FAILURE';
    final statusColor =
        data.passed ? AnsiColors.brightGreen : AnsiColors.brightRed;
    final statusEmoji = data.passed ? '🎉' : '🔧';

    final message = data.passed
        ? 'All validation checks passed! 🎉'
        : 'Issues found - see details above 🔧';

    buffer.writeln(_colorize(
        '│${_center(enableEmojis ? '$statusEmoji $status' : status, 58)}│',
        statusColor + AnsiColors.bold));
    buffer.writeln(_colorize('│${_center(message, 58)}│', AnsiColors.white));
    buffer.writeln(_colorize('╰${'─' * 58}╯', AnsiColors.blue));

    // Platform-specific closing
    if (platform == CIPlatform.gitlab) {
      buffer.writeln('\nReport generated by Flutter KeyCheck v3.x');
    }
  }

  /// Create a progress bar visualization
  String _createProgressBar(double percentage, int width) {
    final filled = (percentage / 100 * width).round();
    final empty = width - filled;

    final filledChar = '█';
    final emptyChar = '░';

    final bar = filledChar * filled + emptyChar * empty;
    final color = _getProgressBarColor(percentage);

    return _colorize('[$bar]', color);
  }

  /// Get color for progress bar based on percentage
  String _getProgressBarColor(double percentage) {
    if (percentage >= 80) return AnsiColors.green;
    if (percentage >= 60) return AnsiColors.yellow;
    return AnsiColors.red;
  }

  /// Get quality color based on score
  String _getQualityColor(double score) {
    if (score >= 80) return AnsiColors.brightGreen;
    if (score >= 60) return AnsiColors.yellow;
    return AnsiColors.red;
  }

  /// Get quality emoji based on score
  String _getQualityEmoji(double score) {
    if (!enableEmojis) return '';
    if (score >= 90) return '🏆';
    if (score >= 80) return '⭐';
    if (score >= 70) return '👍';
    if (score >= 60) return '👌';
    return '🔧';
  }

  /// Get coverage color
  String _getCoverageColor(double coverage) {
    if (coverage >= 90) return AnsiColors.brightGreen;
    if (coverage >= 80) return AnsiColors.green;
    if (coverage >= 70) return AnsiColors.yellow;
    return AnsiColors.red;
  }

  /// Get status indicators for different metrics
  String _getCountStatus(int count) {
    final emoji = enableEmojis ? '📊' : 'INFO';
    return _colorize(emoji, AnsiColors.blue);
  }

  String _getMissingStatus(int count) {
    if (count == 0) {
      final emoji = enableEmojis ? '✅' : 'OK';
      return _colorize(emoji, AnsiColors.green);
    }
    final emoji = enableEmojis ? '❌' : 'FAIL';
    return _colorize(emoji, AnsiColors.red);
  }

  String _getExtraStatus(int count) {
    if (count == 0) {
      final emoji = enableEmojis ? '✅' : 'OK';
      return _colorize(emoji, AnsiColors.green);
    }
    final emoji = enableEmojis ? '⚠️' : 'WARN';
    return _colorize(emoji, AnsiColors.yellow);
  }

  String _getCoverageStatus(double coverage) {
    if (coverage >= 90) {
      final emoji = enableEmojis ? '🎯' : 'EXCELLENT';
      return _colorize(emoji, AnsiColors.brightGreen);
    }
    if (coverage >= 80) {
      final emoji = enableEmojis ? '👍' : 'GOOD';
      return _colorize(emoji, AnsiColors.green);
    }
    if (coverage >= 70) {
      final emoji = enableEmojis ? '👌' : 'OK';
      return _colorize(emoji, AnsiColors.yellow);
    }
    final emoji = enableEmojis ? '🔧' : 'POOR';
    return _colorize(emoji, AnsiColors.red);
  }

  String _getQualityStatus(double quality) {
    if (quality >= 80) {
      final emoji = enableEmojis ? '🏆' : 'EXCELLENT';
      return _colorize(emoji, AnsiColors.brightGreen);
    }
    if (quality >= 70) {
      final emoji = enableEmojis ? '⭐' : 'GOOD';
      return _colorize(emoji, AnsiColors.green);
    }
    if (quality >= 60) {
      final emoji = enableEmojis ? '👍' : 'OK';
      return _colorize(emoji, AnsiColors.yellow);
    }
    final emoji = enableEmojis ? '🔧' : 'POOR';
    return _colorize(emoji, AnsiColors.red);
  }

  String _getPerformanceStatus(Duration duration) {
    if (duration.inMilliseconds < 100) {
      final emoji = enableEmojis ? '⚡' : 'FAST';
      return _colorize(emoji, AnsiColors.brightGreen);
    }
    if (duration.inMilliseconds < 500) {
      final emoji = enableEmojis ? '👍' : 'GOOD';
      return _colorize(emoji, AnsiColors.green);
    }
    if (duration.inMilliseconds < 2000) {
      final emoji = enableEmojis ? '👌' : 'OK';
      return _colorize(emoji, AnsiColors.yellow);
    }
    final emoji = enableEmojis ? '🐌' : 'SLOW';
    return _colorize(emoji, AnsiColors.red);
  }

  String _getPerformanceColor(double score) {
    if (score >= 80) return AnsiColors.brightGreen;
    if (score >= 60) return AnsiColors.yellow;
    return AnsiColors.red;
  }

  /// Colorize text if colors are enabled
  String _colorize(String text, String color) {
    if (!enableColors) return text;
    return '$color$text${AnsiColors.reset}';
  }

  /// Center text in a field of given width
  String _center(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) / 2;
    final leftPad = ' ' * padding.floor();
    final rightPad = ' ' * padding.ceil();
    return '$leftPad$text$rightPad';
  }

  /// Pad text to the right
  String _padRight(String text, int width) {
    if (text.length >= width) return text;
    return text + ' ' * (width - text.length);
  }

  /// Create GitLab CI collapsible section
  String _gitlabSection(String id, String title) {
    return '\ne[0Ksection_start:${DateTime.now().millisecondsSinceEpoch}:$id\re[0K$title';
  }

  /// Detect CI platform from environment
  static CIPlatform _detectCIPlatform() {
    final env = Platform.environment;

    if (env.containsKey('GITHUB_ACTIONS')) return CIPlatform.github;
    if (env.containsKey('GITLAB_CI')) return CIPlatform.gitlab;
    if (env.containsKey('JENKINS_URL')) return CIPlatform.jenkins;
    if (env.containsKey('AZURE_HTTP_USER_AGENT')) return CIPlatform.azure;
    if (env.containsKey('BITBUCKET_BUILD_NUMBER')) return CIPlatform.bitbucket;

    return CIPlatform.generic;
  }

  /// Check if colors should be enabled
  static bool _shouldEnableColors() {
    final env = Platform.environment;

    // Check if explicitly disabled
    if (env['NO_COLOR'] != null) return false;
    if (env['TERM'] == 'dumb') return false;

    // Check if explicitly enabled
    if (env['FORCE_COLOR'] != null) return true;

    // Check if we're in a terminal
    return stdout.hasTerminal;
  }

  @override
  String get fileExtension => 'log';

  @override
  String get reportType => 'Enhanced CI';

  // Additional methods required by HTML reporters
  String _buildDuplicateKeysTable(ScanResult result) {
    final duplicates = result.keyUsages.entries
        .where((e) => e.value.locations.length > 2)
        .toList();

    if (duplicates.isEmpty) {
      return '<p>No duplicate keys found</p>';
    }

    final buffer = StringBuffer();
    buffer.writeln('<table class="duplicate-keys-table">');
    buffer.writeln('<thead><tr>');
    buffer.writeln('<th>Key Name</th>');
    buffer.writeln('<th>Count</th>');
    buffer.writeln('<th>Locations</th>');
    buffer.writeln('</tr></thead>');
    buffer.writeln('<tbody>');

    for (final entry in duplicates) {
      buffer.writeln('<tr>');
      buffer.writeln('<td>${entry.key}</td>');
      buffer.writeln('<td>${entry.value.locations.length}</td>');
      buffer.writeln('<td>${entry.value.locations.join(', ')}</td>');
      buffer.writeln('</tr>');
    }

    buffer.writeln('</tbody></table>');
    return buffer.toString();
  }

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

  double _calculateEfficiency(ScanResult result) {
    final keysPerSecond =
        result.keyUsages.length / (result.duration.inMilliseconds / 1000.0);
    if (keysPerSecond > 20) return 95.0;
    if (keysPerSecond > 10) return 85.0;
    if (keysPerSecond > 5) return 75.0;
    return 60.0;
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

  String _buildDistributionLegend(ScanResult result) {
    final categories = <String, int>{};

    for (final entry in result.keyUsages.entries) {
      final category = _inferCategory(entry.key, entry.value.tags);
      categories[category] = (categories[category] ?? 0) + 1;
    }

    final buffer = StringBuffer();
    buffer.writeln('<div class="distribution-legend">');

    for (final entry in categories.entries) {
      final color = _getCategoryColor(entry.key);
      buffer.writeln('<div class="legend-item">');
      buffer.writeln(
          '<span class="legend-color" style="background-color: $color"></span>');
      buffer.writeln(
          '<span class="legend-label">${entry.key}: ${entry.value}</span>');
      buffer.writeln('</div>');
    }

    buffer.writeln('</div>');
    return buffer.toString();
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

  String _getCategoryColor(String category) {
    switch (category) {
      case 'widget':
        return '#3b82f6';
      case 'test':
        return '#10b981';
      case 'navigation':
        return '#8b5cf6';
      case 'handler':
        return '#f59e0b';
      default:
        return '#6b7280';
    }
  }

  double _calculateQualityScore(ScanResult result) {
    var score = 0.0;

    // Coverage score (40% of total)
    score += (result.metrics.fileCoverage * 0.4);

    // Key organization score (30% of total)
    final organizationScore = _calculateOrganization(result);
    score += (organizationScore * 0.3);

    // Consistency score (30% of total)
    final consistencyScore = _calculateConsistency(result);
    score += (consistencyScore * 0.3);

    return score.clamp(0.0, 100.0);
  }

  double _calculateConsistency(ScanResult result) {
    final keyNames = result.keyUsages.keys;
    var consistencyScore = 90.0;

    // Check naming conventions
    var hasUnderscore = false;
    var hasCamelCase = false;

    for (final name in keyNames) {
      if (name.contains('_')) hasUnderscore = true;
      if (RegExp(r'[a-z][A-Z]').hasMatch(name)) hasCamelCase = true;
    }

    if (hasUnderscore && hasCamelCase) {
      consistencyScore -= 20.0;
    }

    return consistencyScore;
  }

  double _calculateOrganization(ScanResult result) {
    // Calculate based on how well keys are organized
    if (result.keyUsages.isEmpty) return 0.0;

    final uniqueCategories = <String>{};
    for (final entry in result.keyUsages.entries) {
      uniqueCategories.add(_inferCategory(entry.key, entry.value.tags));
    }

    // Better organization = fewer different categories relative to total keys
    final ratio = uniqueCategories.length / result.keyUsages.length;
    return (100.0 * (1.0 - ratio)).clamp(0.0, 100.0);
  }

  String _buildEnhancedInsights(ScanResult result) {
    final buffer = StringBuffer();
    buffer.writeln('<div class="enhanced-insights">');

    // Quality insights
    final qualityScore = _calculateQualityScore(result);
    buffer.writeln('<div class="insight-item">');
    buffer.writeln('<h4>Quality Score</h4>');
    buffer.writeln('<p>${qualityScore.toStringAsFixed(1)}%</p>');
    buffer.writeln('</div>');

    // Performance insights
    buffer.writeln('<div class="insight-item">');
    buffer.writeln('<h4>Performance</h4>');
    buffer.writeln(
        '<p>${_getPerformanceTrend(result.duration.inMilliseconds)}</p>');
    buffer.writeln('</div>');

    // Efficiency insights
    buffer.writeln('<div class="insight-item">');
    buffer.writeln('<h4>Efficiency</h4>');
    buffer.writeln('<p>${_getEfficiencyTrend(result)}</p>');
    buffer.writeln('</div>');

    buffer.writeln('</div>');
    return buffer.toString();
  }
}
