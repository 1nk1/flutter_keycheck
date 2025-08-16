import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors_v3.dart';
import 'package:path/path.dart' as path;

/// Enhanced AST scanner with provable coverage
class AstScannerV3 {
  final String projectPath;
  final bool includeTests;
  final bool includeGenerated;
  final String? gitDiffBase;
  final String? packageMode;
  final String? packageFilter;
  final ConfigV3 config;
  
  // Built-in detectors
  late final List<KeyDetector> detectors;
  
  // Metrics
  final ScanMetrics metrics = ScanMetrics();
  final Map<String, FileAnalysis> fileAnalyses = {};
  final Map<String, KeyUsage> keyUsages = {};
  
  AstScannerV3({
    required this.projectPath,
    this.includeTests = false,
    this.includeGenerated = false,
    this.gitDiffBase,
    this.packageMode,
    this.packageFilter,
    required this.config,
  }) {
    // Initialize built-in detectors
    detectors = [
      ValueKeyDetector(),
      BasicKeyDetector(),
      ConstKeyDetector(),
      SemanticKeyDetector(),
      TestKeyDetector(),
    ];
  }

  /// Perform full AST scan with metrics
  Future<ScanResult> scan() async {
    final startTime = DateTime.now();
    
    // Get files to scan
    final files = await _getFilesToScan();
    metrics.totalFiles = files.length;
    
    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      excludedPaths: _getExcludedPaths(),
    );
    
    // Scan each file
    for (final filePath in files) {
      await _scanFile(filePath, collection);
    }
    
    // Calculate coverage metrics
    _calculateCoverageMetrics();
    
    // Detect blind spots
    final blindSpots = _detectBlindSpots();
    
    final duration = DateTime.now().difference(startTime);
    
    return ScanResult(
      metrics: metrics,
      fileAnalyses: fileAnalyses,
      keyUsages: keyUsages,
      blindSpots: blindSpots,
      duration: duration,
    );
  }

  /// Get files to scan
  Future<List<String>> _getFilesToScan() async {
    if (gitDiffBase != null) {
      // Incremental scan
      final result = await Process.run(
        'git',
        ['diff', '--name-only', gitDiffBase!, '--', '*.dart'],
        workingDirectory: projectPath,
      );
      
      if (result.exitCode == 0) {
        final files = result.stdout
            .toString()
            .split('\n')
            .where((f) => f.isNotEmpty && f.endsWith('.dart'))
            .map((f) => path.join(projectPath, f))
            .toList();
        
        metrics.incrementalScan = true;
        metrics.incrementalBase = gitDiffBase!;
        return files;
      }
    }
    
    // Full scan based on package mode
    if (packageMode == 'resolve') {
      return await _getResolvedPackageFiles();
    } else {
      return _getWorkspaceFiles();
    }
  }

  /// Get workspace files
  List<String> _getWorkspaceFiles() {
    final files = <String>[];
    final dir = Directory(projectPath);
    
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = path.relative(entity.path, from: projectPath);
        
        // Apply filters
        if (!_shouldIncludeFile(relativePath)) continue;
        
        // Apply package filter if set
        if (packageFilter != null) {
          final pattern = RegExp(packageFilter!);
          if (!pattern.hasMatch(relativePath)) continue;
        }
        
        files.add(entity.path);
      }
    }
    
    return files;
  }

  /// Get resolved package files (including dependencies)
  Future<List<String>> _getResolvedPackageFiles() async {
    // Run flutter pub deps to get dependencies
    final result = await Process.run(
      'flutter',
      ['pub', 'deps', '--json'],
      workingDirectory: projectPath,
    );
    
    if (result.exitCode != 0) {
      // Fallback to workspace scan
      return _getWorkspaceFiles();
    }
    
    // Parse dependencies and scan their lib folders
    // This is simplified - full implementation would parse JSON
    // and scan each package's lib folder
    return _getWorkspaceFiles();
  }

  /// Check if file should be included
  bool _shouldIncludeFile(String relativePath) {
    if (!includeTests && relativePath.contains('test/')) return false;
    if (!includeGenerated && relativePath.endsWith('.g.dart')) return false;
    if (!includeGenerated && relativePath.endsWith('.freezed.dart')) return false;
    
    // Check exclude patterns from config
    for (final pattern in config.scan.excludePatterns) {
      if (_matchesPattern(relativePath, pattern)) return false;
    }
    
    return true;
  }

  /// Match glob pattern
  bool _matchesPattern(String path, String pattern) {
    // Simplified glob matching
    final regex = pattern
        .replaceAll('**/', '.*')
        .replaceAll('*', '[^/]*')
        .replaceAll('?', '.');
    return RegExp(regex).hasMatch(path);
  }

  /// Scan single file with AST
  Future<void> _scanFile(String filePath, AnalysisContextCollection collection) async {
    try {
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      
      if (result is ResolvedUnitResult) {
        final analysis = FileAnalysis(
          path: filePath,
          relativePath: path.relative(filePath, from: projectPath),
        );
        
        // Create visitor with all detectors
        final visitor = KeyVisitorV3(
          detectors: detectors,
          analysis: analysis,
          keyUsages: keyUsages,
          filePath: filePath,
        );
        
        // Visit AST
        result.unit.visitChildren(visitor);
        
        // Store analysis
        fileAnalyses[filePath] = analysis;
        metrics.scannedFiles++;
        metrics.totalLines += _countLines(File(filePath));
        metrics.analyzedNodes += analysis.nodesAnalyzed;
        
        // Update detector metrics
        for (final detector in detectors) {
          metrics.detectorHits[detector.name] = 
              (metrics.detectorHits[detector.name] ?? 0) + 
              (analysis.detectorHits[detector.name] ?? 0);
        }
      }
    } catch (e) {
      metrics.errors.add(ScanError(
        file: filePath,
        error: e.toString(),
        type: 'ast_parse',
      ));
    }
  }

  /// Calculate coverage metrics
  void _calculateCoverageMetrics() {
    // File coverage
    metrics.fileCoverage = metrics.totalFiles > 0
        ? (metrics.scannedFiles / metrics.totalFiles * 100)
        : 0;
    
    // Widget coverage
    int totalWidgets = 0;
    int widgetsWithKeys = 0;
    
    for (final analysis in fileAnalyses.values) {
      totalWidgets += analysis.widgetCount;
      widgetsWithKeys += analysis.widgetsWithKeys;
    }
    
    metrics.widgetCoverage = totalWidgets > 0 
        ? (widgetsWithKeys / totalWidgets * 100) 
        : 0;
    
    // Handler coverage
    int totalHandlers = 0;
    int handlersWithKeys = 0;
    
    for (final usage in keyUsages.values) {
      if (usage.handlers.isNotEmpty) {
        handlersWithKeys++;
      }
      totalHandlers++;
    }
    
    metrics.handlerCoverage = totalHandlers > 0
        ? (handlersWithKeys / totalHandlers * 100)
        : 0;
  }

  /// Detect blind spots
  List<BlindSpot> _detectBlindSpots() {
    final blindSpots = <BlindSpot>[];
    
    // Check for files with no keys
    for (final entry in fileAnalyses.entries) {
      if (entry.value.keysFound.isEmpty && entry.value.widgetCount > 5) {
        blindSpots.add(BlindSpot(
          type: 'no_keys_in_ui_heavy_file',
          location: entry.key,
          severity: 'warning',
          message: 'File has ${entry.value.widgetCount} widgets but no keys',
        ));
      }
    }
    
    // Check detector effectiveness
    for (final entry in metrics.detectorHits.entries) {
      if (entry.value == 0) {
        blindSpots.add(BlindSpot(
          type: 'ineffective_detector',
          location: 'detector:${entry.key}',
          severity: 'info',
          message: 'Detector "${entry.key}" found no matches',
        ));
      }
    }
    
    return blindSpots;
  }

  List<String> _getExcludedPaths() {
    final excluded = <String>[];
    if (!includeTests) excluded.add('test/');
    if (!includeGenerated) {
      excluded.add('**.g.dart');
      excluded.add('**.freezed.dart');
    }
    return excluded;
  }

  int _countLines(File file) {
    try {
      return file.readAsLinesSync().length;
    } catch (_) {
      return 0;
    }
  }
}

/// Enhanced AST visitor for v3
class KeyVisitorV3 extends RecursiveAstVisitor<void> {
  final List<KeyDetector> detectors;
  final FileAnalysis analysis;
  final Map<String, KeyUsage> keyUsages;
  final String filePath;
  
  KeyVisitorV3({
    required this.detectors,
    required this.analysis,
    required this.keyUsages,
    required this.filePath,
  });

  @override
  void visitMethodInvocation(MethodInvocation node) {
    analysis.nodesAnalyzed++;
    
    // Check each detector
    for (final detector in detectors) {
      final result = detector.detect(node);
      if (result != null) {
        _recordKey(result.key, node, detector, result);
      }
    }
    
    // Check for action handlers
    _checkActionHandler(node);
    
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    analysis.nodesAnalyzed++;
    
    // Track widget creation
    final typeName = node.constructorName.type.toString();
    if (_isWidget(typeName)) {
      analysis.widgetCount++;
      analysis.widgetTypes.add(typeName);
      
      // Check for key parameter
      final keyArgs = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'key')
          .toList();
      final keyArg = keyArgs.isNotEmpty ? keyArgs.first : null;
      
      if (keyArg != null) {
        analysis.widgetsWithKeys++;
        
        // Extract key value using detectors
        for (final detector in detectors) {
          final result = detector.detectExpression(keyArg.expression);
          if (result != null) {
            _recordKey(result.key, node, detector, result);
          }
        }
      } else {
        analysis.uncoveredWidgetTypes.add(typeName);
      }
    }
    
    super.visitInstanceCreationExpression(node);
  }

  void _recordKey(String key, AstNode node, KeyDetector detector, DetectionResult result) {
    // Record in file analysis
    analysis.keysFound.add(key);
    analysis.detectorHits[detector.name] = 
        (analysis.detectorHits[detector.name] ?? 0) + 1;
    
    // Get location info
    final lineInfo = (node.root as CompilationUnit).lineInfo;
    final location = lineInfo.getLocation(node.offset);
    
    // Create or update key usage
    final usage = keyUsages.putIfAbsent(
      key,
      () => KeyUsage(id: key),
    );
    
    usage.locations.add(KeyLocation(
      file: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      detector: detector.name,
      context: _getContext(node),
    ));
    
    // Add tags from detector
    if (result.tags != null) {
      usage.tags.addAll(result.tags!);
    }
  }

  void _checkActionHandler(MethodInvocation node) {
    final methodName = node.methodName.name;
    final actionPatterns = ['onPressed', 'onTap', 'onSubmit', 'onChanged'];
    
    if (actionPatterns.contains(methodName)) {
      // Find associated key in parent widget
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final keyArgs = current.argumentList.arguments
              .whereType<NamedExpression>()
              .where((arg) => arg.name.label.name == 'key')
              .toList();
          final keyArg = keyArgs.isNotEmpty ? keyArgs.first : null;
          
          if (keyArg != null) {
            for (final detector in detectors) {
              final result = detector.detectExpression(keyArg.expression);
              if (result != null) {
                final usage = keyUsages[result.key];
                if (usage != null) {
                  usage.handlers.add(HandlerInfo(
                    type: methodName,
                    method: _extractHandlerMethod(node),
                    file: filePath,
                    line: node.offset,
                  ));
                }
                break;
              }
            }
          }
          break;
        }
        current = current.parent;
      }
    }
  }

  String _getContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return 'method:${current.name.lexeme}';
      }
      if (current is FunctionDeclaration) {
        return 'function:${current.name.lexeme}';
      }
      if (current is ClassDeclaration) {
        return 'class:${current.name.lexeme}';
      }
      current = current.parent;
    }
    return 'global';
  }

  String? _extractHandlerMethod(MethodInvocation node) {
    final args = node.argumentList?.arguments ?? [];
    final arg = args.isNotEmpty ? args.first : null;
    if (arg is SimpleIdentifier) {
      return arg.name;
    }
    if (arg is FunctionExpression) {
      return '<anonymous>';
    }
    return null;
  }

  bool _isWidget(String typeName) {
    return typeName.endsWith('Widget') ||
           typeName.endsWith('Button') ||
           typeName.endsWith('Field') ||
           typeName.endsWith('View') ||
           typeName.endsWith('Screen') ||
           typeName.endsWith('Page') ||
           typeName.endsWith('Dialog') ||
           typeName.endsWith('Card') ||
           ['Column', 'Row', 'Stack', 'Scaffold', 'AppBar', 'Center', 
            'Padding', 'Expanded', 'ListView', 'GridView'].contains(typeName);
  }
}