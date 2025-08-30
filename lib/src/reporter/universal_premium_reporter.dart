import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/scan_result.dart';
import '../models/validation_result.dart';
import '../cache/cache_manager.dart';
import 'reporter_v3.dart';

/// Universal Premium Reporter for Flutter KeyCheck
/// Works with any Flutter project structure without hardcoded assumptions
class UniversalPremiumReporter extends ReporterV3 {
  final bool enableCache;
  final Set<String> ignorePatterns;
  final Map<String, dynamic> customConfig;

  // Cache manager for smart caching
  late final CacheManager? _cacheManager;

  // Default ignore patterns for system/generated files
  static const Set<String> defaultIgnorePatterns = {
    '.dart_tool/',
    'build/',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    '.packages',
    '.pub-cache/',
    '*.g.dart',
    '*.freezed.dart',
    '*.config.dart',
    '*.mocks.dart',
    '*.pb.dart',
    '*.pbenum.dart',
    '*.pbgrpc.dart',
    '*.pbjson.dart',
    'generated_plugin_registrant.dart',
  };

  UniversalPremiumReporter({
    this.enableCache = true,
    Set<String>? ignorePatterns,
    this.customConfig = const {},
  }) : ignorePatterns = {...defaultIgnorePatterns, ...?ignorePatterns} {
    _cacheManager = enableCache ? CacheManager() : null;
  }

  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = true,
  }) async {
    final content = await _generateUniversalReport(
      result,
      includeMetrics: includeMetrics,
      includeLocations: includeLocations,
    );
    await outputFile.writeAsString(content);
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // Validation reports can be added later
    throw UnimplementedError('Validation reports coming soon');
  }

  /// Generate universal HTML report
  Future<String> _generateUniversalReport(
    ScanResult result, {
    required bool includeMetrics,
    required bool includeLocations,
  }) async {
    // Check cache if enabled
    if (_cacheManager != null) {
      final cached = await _cacheManager!.getCachedReport(result);
      if (cached != null) return cached;
    }

    final projectInfo = _analyzeProjectStructure(result);
    final keyAnalysis = _performAdvancedKeyAnalysis(result);
    final qualityMetrics = _calculateQualityMetrics(result, keyAnalysis);

    final html = _buildHtmlReport(
      result,
      projectInfo,
      keyAnalysis,
      qualityMetrics,
      includeMetrics: includeMetrics,
      includeLocations: includeLocations,
    );

    // Cache the result if enabled
    if (_cacheManager != null) {
      await _cacheManager!.cacheReport(result, html);
    }

    return html;
  }

  /// Analyze project structure without assumptions
  ProjectInfo _analyzeProjectStructure(ScanResult result) {
    final projectPaths = <String>{};
    final packageNames = <String>{};
    final sourceDirectories = <String, int>{};

    for (final entry in result.keyUsages.entries) {
      for (final location in entry.value.locations) {
        final filePath = location.file;
        projectPaths.add(filePath);

        // Extract package name from path
        final packageMatch = RegExp(r'packages?/([^/]+)/').firstMatch(filePath);
        if (packageMatch != null) {
          packageNames.add(packageMatch.group(1)!);
        }

        // Track source directories
        final dir = path.dirname(filePath);
        sourceDirectories[dir] = (sourceDirectories[dir] ?? 0) + 1;
      }
    }

    // Determine project type
    final projectType = _detectProjectType(projectPaths);

    // Find common root
    final commonRoot = _findCommonRoot(projectPaths);

    return ProjectInfo(
      type: projectType,
      rootPath: commonRoot,
      packages: packageNames,
      sourceDirectories: sourceDirectories,
      totalFiles: projectPaths.length,
    );
  }

  /// Detect project type based on file structure
  ProjectType _detectProjectType(Set<String> paths) {
    final hasLib = paths.any((p) => p.contains('/lib/'));
    final hasTest = paths.any((p) => p.contains('/test/'));
    final hasExample = paths.any((p) => p.contains('/example/'));
    final hasPackages = paths.any((p) => p.contains('/packages/'));
    final hasApps = paths.any((p) => p.contains('/apps/'));

    if (hasPackages || hasApps) return ProjectType.monorepo;
    if (hasLib && hasExample) return ProjectType.package;
    if (hasLib && hasTest) return ProjectType.app;
    return ProjectType.unknown;
  }

  /// Find common root path
  String _findCommonRoot(Set<String> paths) {
    if (paths.isEmpty) return '';

    final pathParts = paths.map((p) => p.split('/')).toList();
    if (pathParts.isEmpty) return '';

    final minLength =
        pathParts.map((p) => p.length).reduce((a, b) => a < b ? a : b);
    final commonParts = <String>[];

    for (int i = 0; i < minLength; i++) {
      final part = pathParts.first[i];
      if (pathParts.every((p) => p[i] == part)) {
        commonParts.add(part);
      } else {
        break;
      }
    }

    return commonParts.join('/');
  }

  /// Perform advanced key analysis
  KeyAnalysis _performAdvancedKeyAnalysis(ScanResult result) {
    final categories = <String, List<String>>{};
    final patterns = <String, int>{};
    final duplicates = <String, List<String>>{};
    final coverage = <String, double>{};

    for (final entry in result.keyUsages.entries) {
      final keyName = entry.key;
      final usage = entry.value;

      // Categorize keys
      final category = _categorizeKey(keyName, usage);
      categories.putIfAbsent(category, () => []).add(keyName);

      // Detect patterns
      final pattern = _detectKeyPattern(keyName);
      patterns[pattern] = (patterns[pattern] ?? 0) + 1;

      // Find duplicates
      if (usage.locations.length > 1) {
        duplicates[keyName] =
            usage.locations.map((l) => _cleanPath(l.file)).toList();
      }
    }

    // Calculate coverage metrics
    coverage['overall'] = result.metrics.fileCoverage;
    coverage['widget'] = result.metrics.widgetCoverage;
    coverage['handler'] = result.metrics.handlerCoverage;

    return KeyAnalysis(
      categories: categories,
      patterns: patterns,
      duplicates: duplicates,
      coverage: coverage,
      totalKeys: result.keyUsages.length,
    );
  }

  /// Categorize key based on name and usage
  String _categorizeKey(String keyName, KeyUsage usage) {
    final lower = keyName.toLowerCase();

    // Smart categorization based on patterns
    if (lower.contains('button') || lower.contains('btn')) return 'buttons';
    if (lower.contains('field') || lower.contains('input')) return 'inputs';
    if (lower.contains('card') || lower.contains('tile')) return 'cards';
    if (lower.contains('list') || lower.contains('item')) return 'lists';
    if (lower.contains('dialog') || lower.contains('modal')) return 'dialogs';
    if (lower.contains('nav') || lower.contains('route')) return 'navigation';
    if (lower.contains('test')) return 'testing';

    // Check tags if available
    if (usage.tags.contains('widget')) return 'widgets';
    if (usage.tags.contains('test')) return 'testing';

    return 'other';
  }

  /// Detect naming pattern
  String _detectKeyPattern(String keyName) {
    if (RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(keyName)) return 'camelCase';
    if (RegExp(r'^[a-z]+_[a-z_]+$').hasMatch(keyName)) return 'snake_case';
    if (RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(keyName)) return 'PascalCase';
    if (RegExp(r'^[A-Z]+_[A-Z_]+$').hasMatch(keyName)) return 'SCREAMING_SNAKE';
    return 'mixed';
  }

  /// Calculate quality metrics
  QualityMetrics _calculateQualityMetrics(
      ScanResult result, KeyAnalysis analysis) {
    // Calculate various quality scores
    final consistencyScore = _calculateConsistencyScore(analysis.patterns);
    final organizationScore = _calculateOrganizationScore(analysis.categories);
    final coverageScore = analysis.coverage['overall'] ?? 0.0;
    final duplicateScore =
        100.0 * (1.0 - (analysis.duplicates.length / analysis.totalKeys));

    // Overall quality score
    final overallScore = (consistencyScore * 0.3 +
        organizationScore * 0.2 +
        coverageScore * 0.3 +
        duplicateScore * 0.2);

    // Performance metrics
    final scanSpeed =
        result.keyUsages.length / (result.duration.inMilliseconds / 1000.0);

    return QualityMetrics(
      overallScore: overallScore,
      consistencyScore: consistencyScore,
      organizationScore: organizationScore,
      coverageScore: coverageScore,
      duplicateScore: duplicateScore,
      scanSpeed: scanSpeed,
      recommendations: _generateRecommendations(analysis, overallScore),
    );
  }

  /// Calculate naming consistency score
  double _calculateConsistencyScore(Map<String, int> patterns) {
    if (patterns.isEmpty) return 0.0;

    final total = patterns.values.reduce((a, b) => a + b);
    final dominant = patterns.values.reduce((a, b) => a > b ? a : b);

    return 100.0 * (dominant / total);
  }

  /// Calculate organization score
  double _calculateOrganizationScore(Map<String, List<String>> categories) {
    if (categories.isEmpty) return 0.0;

    // Good organization = balanced distribution across categories
    final sizes = categories.values.map((v) => v.length).toList();
    final avg = sizes.reduce((a, b) => a + b) / sizes.length;
    final variance =
        sizes.map((s) => (s - avg) * (s - avg)).reduce((a, b) => a + b) /
            sizes.length;
    final stdDev = variance > 0 ? variance : 1.0;

    // Lower variance = better organization
    return 100.0 * (1.0 / (1.0 + stdDev / avg)).clamp(0.0, 1.0);
  }

  /// Generate recommendations
  List<String> _generateRecommendations(
      KeyAnalysis analysis, double overallScore) {
    final recommendations = <String>[];

    if (analysis.patterns.length > 2) {
      recommendations.add('Standardize naming convention across keys');
    }

    if (analysis.duplicates.length > analysis.totalKeys * 0.1) {
      recommendations.add('Review and consolidate duplicate keys');
    }

    if ((analysis.coverage['overall'] ?? 0) < 70) {
      recommendations.add('Increase key coverage for better testability');
    }

    if (overallScore < 60) {
      recommendations
          .add('Consider refactoring key structure for better maintainability');
    }

    return recommendations;
  }

  /// Clean file path for display
  String _cleanPath(String filePath) {
    // Remove common prefixes while preserving structure
    final patterns = [
      RegExp(r'.*/lib/(.*)'),
      RegExp(r'.*/test/(.*)'),
      RegExp(r'.*/example/(.*)'),
      RegExp(r'.*/packages/([^/]+)/(.*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(filePath);
      if (match != null) {
        if (match.groupCount == 2) {
          return '${match.group(1)}/${match.group(2)}';
        }
        return match.group(1) ?? filePath;
      }
    }

    // Fallback: return basename
    return path.basename(filePath);
  }

  /// Build HTML report
  String _buildHtmlReport(
    ScanResult result,
    ProjectInfo projectInfo,
    KeyAnalysis keyAnalysis,
    QualityMetrics qualityMetrics, {
    required bool includeMetrics,
    required bool includeLocations,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter KeyCheck - Universal Premium Report</title>
  
  <!-- External Dependencies -->
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  
  <style>
    ${_getUniversalStyles()}
  </style>
</head>
<body>
  <div class="app-container">
    ${_buildHeader(projectInfo)}
    ${_buildSummaryCards(keyAnalysis, qualityMetrics)}
    ${includeMetrics ? _buildMetricsSection(result, qualityMetrics) : ''}
    ${_buildKeyAnalysisSection(keyAnalysis)}
    ${includeLocations ? _buildLocationsSection(result, keyAnalysis) : ''}
    ${_buildRecommendationsSection(qualityMetrics)}
  </div>
  
  <script>
    ${_getUniversalScripts(result, keyAnalysis)}
  </script>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Get universal styles
  String _getUniversalStyles() {
    return '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    :root {
      --primary: #3b82f6;
      --primary-dark: #2563eb;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
      --dark: #0f172a;
      --dark-lighter: #1e293b;
      --dark-border: #334155;
      --text-primary: #f1f5f9;
      --text-secondary: #94a3b8;
      --text-muted: #64748b;
    }
    
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: linear-gradient(135deg, var(--dark) 0%, var(--dark-lighter) 100%);
      color: var(--text-primary);
      min-height: 100vh;
    }
    
    .app-container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 2rem;
    }
    
    .header {
      text-align: center;
      margin-bottom: 3rem;
      padding: 2rem;
      background: rgba(30, 41, 59, 0.5);
      border-radius: 1rem;
      backdrop-filter: blur(10px);
      border: 1px solid var(--dark-border);
    }
    
    .header h1 {
      font-size: 2.5rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
      background: linear-gradient(135deg, var(--primary) 0%, var(--success) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 1.5rem;
      margin-bottom: 3rem;
    }
    
    .summary-card {
      background: rgba(30, 41, 59, 0.5);
      border: 1px solid var(--dark-border);
      border-radius: 1rem;
      padding: 1.5rem;
      backdrop-filter: blur(10px);
      transition: transform 0.3s, box-shadow 0.3s;
    }
    
    .summary-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    }
    
    .metric-value {
      font-size: 2rem;
      font-weight: 700;
      margin: 0.5rem 0;
    }
    
    .metric-label {
      color: var(--text-secondary);
      font-size: 0.875rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    
    .section {
      background: rgba(30, 41, 59, 0.5);
      border: 1px solid var(--dark-border);
      border-radius: 1rem;
      padding: 2rem;
      margin-bottom: 2rem;
      backdrop-filter: blur(10px);
    }
    
    .section-title {
      font-size: 1.5rem;
      font-weight: 600;
      margin-bottom: 1.5rem;
      color: var(--text-primary);
    }
    
    .chart-container {
      position: relative;
      height: 300px;
      margin: 1.5rem 0;
    }
    
    .table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 1rem;
    }
    
    .table th,
    .table td {
      padding: 0.75rem;
      text-align: left;
      border-bottom: 1px solid var(--dark-border);
    }
    
    .table th {
      color: var(--text-secondary);
      font-weight: 600;
      text-transform: uppercase;
      font-size: 0.75rem;
      letter-spacing: 0.05em;
    }
    
    .badge {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    
    .badge-success {
      background: rgba(16, 185, 129, 0.2);
      color: var(--success);
    }
    
    .badge-warning {
      background: rgba(245, 158, 11, 0.2);
      color: var(--warning);
    }
    
    .badge-danger {
      background: rgba(239, 68, 68, 0.2);
      color: var(--danger);
    }
    
    .progress-bar {
      height: 8px;
      background: var(--dark-lighter);
      border-radius: 4px;
      overflow: hidden;
      margin: 0.5rem 0;
    }
    
    .progress-fill {
      height: 100%;
      background: linear-gradient(90deg, var(--primary) 0%, var(--success) 100%);
      transition: width 0.3s;
    }
    
    .recommendation-item {
      padding: 1rem;
      background: rgba(59, 130, 246, 0.1);
      border-left: 3px solid var(--primary);
      border-radius: 0.5rem;
      margin-bottom: 0.75rem;
    }
    ''';
  }

  /// Build header section
  String _buildHeader(ProjectInfo projectInfo) {
    return '''
    <div class="header">
      <h1>Flutter KeyCheck Premium Report</h1>
      <p style="color: var(--text-secondary);">
        Project Type: <span style="color: var(--primary);">${projectInfo.type.toString().split('.').last}</span> | 
        Files: <span style="color: var(--success);">${projectInfo.totalFiles}</span> | 
        Generated: ${DateTime.now().toLocal()}
      </p>
    </div>
    ''';
  }

  /// Build summary cards
  String _buildSummaryCards(KeyAnalysis analysis, QualityMetrics metrics) {
    final scoreColor = metrics.overallScore >= 80
        ? 'var(--success)'
        : metrics.overallScore >= 60
            ? 'var(--warning)'
            : 'var(--danger)';

    return '''
    <div class="summary-grid">
      <div class="summary-card">
        <div class="metric-label">Overall Quality</div>
        <div class="metric-value" style="color: $scoreColor;">${metrics.overallScore.toStringAsFixed(1)}%</div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${metrics.overallScore}%"></div>
        </div>
      </div>
      
      <div class="summary-card">
        <div class="metric-label">Total Keys</div>
        <div class="metric-value">${analysis.totalKeys}</div>
        <div style="color: var(--text-muted); font-size: 0.875rem;">
          ${analysis.categories.length} categories
        </div>
      </div>
      
      <div class="summary-card">
        <div class="metric-label">Coverage</div>
        <div class="metric-value">${(analysis.coverage['overall'] ?? 0).toStringAsFixed(1)}%</div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${analysis.coverage['overall'] ?? 0}%"></div>
        </div>
      </div>
      
      <div class="summary-card">
        <div class="metric-label">Scan Speed</div>
        <div class="metric-value">${metrics.scanSpeed.toStringAsFixed(0)}</div>
        <div style="color: var(--text-muted); font-size: 0.875rem;">keys/sec</div>
      </div>
    </div>
    ''';
  }

  /// Build metrics section
  String _buildMetricsSection(ScanResult result, QualityMetrics metrics) {
    return '''
    <div class="section">
      <h2 class="section-title">Performance Metrics</h2>
      <div class="chart-container">
        <canvas id="metricsChart"></canvas>
      </div>
    </div>
    ''';
  }

  /// Build key analysis section
  String _buildKeyAnalysisSection(KeyAnalysis analysis) {
    final buffer = StringBuffer();

    buffer.writeln('<div class="section">');
    buffer.writeln('<h2 class="section-title">Key Analysis</h2>');

    // Categories breakdown
    buffer.writeln(
        '<h3 style="margin: 1.5rem 0 1rem; color: var(--text-secondary);">Categories Distribution</h3>');
    buffer.writeln('<div class="chart-container">');
    buffer.writeln('<canvas id="categoriesChart"></canvas>');
    buffer.writeln('</div>');

    // Naming patterns
    buffer.writeln(
        '<h3 style="margin: 1.5rem 0 1rem; color: var(--text-secondary);">Naming Patterns</h3>');
    buffer.writeln('<table class="table">');
    buffer.writeln(
        '<thead><tr><th>Pattern</th><th>Count</th><th>Percentage</th></tr></thead>');
    buffer.writeln('<tbody>');

    final totalPatterns = analysis.patterns.values.reduce((a, b) => a + b);
    analysis.patterns.forEach((pattern, count) {
      final percentage = (100.0 * count / totalPatterns).toStringAsFixed(1);
      buffer.writeln('<tr>');
      buffer.writeln('<td>$pattern</td>');
      buffer.writeln('<td>$count</td>');
      buffer.writeln('<td>$percentage%</td>');
      buffer.writeln('</tr>');
    });

    buffer.writeln('</tbody></table>');
    buffer.writeln('</div>');

    return buffer.toString();
  }

  /// Build locations section
  String _buildLocationsSection(ScanResult result, KeyAnalysis analysis) {
    final buffer = StringBuffer();

    buffer.writeln('<div class="section">');
    buffer.writeln('<h2 class="section-title">Key Locations</h2>');

    if (analysis.duplicates.isNotEmpty) {
      buffer.writeln(
          '<h3 style="margin: 1.5rem 0 1rem; color: var(--warning);">Duplicate Keys</h3>');
      buffer.writeln('<table class="table">');
      buffer.writeln(
          '<thead><tr><th>Key</th><th>Locations</th><th>Count</th></tr></thead>');
      buffer.writeln('<tbody>');

      analysis.duplicates.forEach((key, locations) {
        buffer.writeln('<tr>');
        buffer.writeln('<td style="font-family: monospace;">$key</td>');
        buffer.writeln('<td>${locations.join(', ')}</td>');
        buffer.writeln(
            '<td><span class="badge badge-warning">${locations.length}</span></td>');
        buffer.writeln('</tr>');
      });

      buffer.writeln('</tbody></table>');
    }

    buffer.writeln('</div>');

    return buffer.toString();
  }

  /// Build recommendations section
  String _buildRecommendationsSection(QualityMetrics metrics) {
    if (metrics.recommendations.isEmpty) return '';

    final buffer = StringBuffer();

    buffer.writeln('<div class="section">');
    buffer.writeln('<h2 class="section-title">Recommendations</h2>');

    for (final recommendation in metrics.recommendations) {
      buffer.writeln('<div class="recommendation-item">');
      buffer.writeln('$recommendation');
      buffer.writeln('</div>');
    }

    buffer.writeln('</div>');

    return buffer.toString();
  }

  /// Get universal scripts
  String _getUniversalScripts(ScanResult result, KeyAnalysis analysis) {
    // Prepare data for charts
    final categoriesData =
        analysis.categories.map((k, v) => MapEntry(k, v.length));

    return '''
    // Categories chart
    const categoriesCtx = document.getElementById('categoriesChart');
    if (categoriesCtx) {
      new Chart(categoriesCtx, {
        type: 'doughnut',
        data: {
          labels: ${json.encode(categoriesData.keys.toList())},
          datasets: [{
            data: ${json.encode(categoriesData.values.toList())},
            backgroundColor: [
              '#3b82f6', '#10b981', '#f59e0b', '#ef4444', 
              '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16'
            ]
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'right',
              labels: { color: '#94a3b8' }
            }
          }
        }
      });
    }
    
    // Metrics chart
    const metricsCtx = document.getElementById('metricsChart');
    if (metricsCtx) {
      new Chart(metricsCtx, {
        type: 'radar',
        data: {
          labels: ['Consistency', 'Organization', 'Coverage', 'Duplicates', 'Speed'],
          datasets: [{
            label: 'Quality Metrics',
            data: [
              ${_calculateConsistencyScore(analysis.patterns)},
              ${_calculateOrganizationScore(analysis.categories)},
              ${analysis.coverage['overall'] ?? 0},
              ${100.0 * (1.0 - (analysis.duplicates.length / analysis.totalKeys))},
              ${result.keyUsages.length / (result.duration.inMilliseconds / 1000.0) * 10}
            ],
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.2)'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            r: {
              beginAtZero: true,
              max: 100,
              grid: { color: '#334155' },
              ticks: { color: '#64748b' }
            }
          },
          plugins: {
            legend: {
              labels: { color: '#94a3b8' }
            }
          }
        }
      });
    }
    ''';
  }
}

/// Project information
class ProjectInfo {
  final ProjectType type;
  final String rootPath;
  final Set<String> packages;
  final Map<String, int> sourceDirectories;
  final int totalFiles;

  ProjectInfo({
    required this.type,
    required this.rootPath,
    required this.packages,
    required this.sourceDirectories,
    required this.totalFiles,
  });
}

/// Project type enumeration
enum ProjectType {
  app,
  package,
  monorepo,
  unknown,
}

/// Key analysis results
class KeyAnalysis {
  final Map<String, List<String>> categories;
  final Map<String, int> patterns;
  final Map<String, List<String>> duplicates;
  final Map<String, double> coverage;
  final int totalKeys;

  KeyAnalysis({
    required this.categories,
    required this.patterns,
    required this.duplicates,
    required this.coverage,
    required this.totalKeys,
  });
}

/// Quality metrics
class QualityMetrics {
  final double overallScore;
  final double consistencyScore;
  final double organizationScore;
  final double coverageScore;
  final double duplicateScore;
  final double scanSpeed;
  final List<String> recommendations;

  QualityMetrics({
    required this.overallScore,
    required this.consistencyScore,
    required this.organizationScore,
    required this.coverageScore,
    required this.duplicateScore,
    required this.scanSpeed,
    required this.recommendations,
  });
}
