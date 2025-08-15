import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

/// AST-based scanner with full coverage metrics
class AstScanner {
  final String projectPath;
  final List<KeyDetector> detectors;
  final bool includeTests;
  final bool includeGenerated;
  final String? gitDiffBase;
  
  // Metrics
  final ScanMetrics metrics = ScanMetrics();
  final Map<String, FileAnalysis> fileAnalyses = {};
  final Map<String, KeyUsage> keyUsages = {};
  
  AstScanner({
    required this.projectPath,
    required this.detectors,
    this.includeTests = false,
    this.includeGenerated = false,
    this.gitDiffBase,
  });

  /// Perform full AST scan with metrics
  Future<ScanResult> scan() async {
    final startTime = DateTime.now();
    
    // Get files to scan (incremental if git-diff provided)
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

  /// Get files to scan (with incremental support)
  Future<List<String>> _getFilesToScan() async {
    if (gitDiffBase != null) {
      // Incremental scan based on git diff
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
    
    // Full scan
    return _getAllDartFiles();
  }

  /// Get all Dart files in project
  List<String> _getAllDartFiles() {
    final files = <String>[];
    final dir = Directory(projectPath);
    
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = path.relative(entity.path, from: projectPath);
        
        // Apply filters
        if (!includeTests && relativePath.contains('test/')) continue;
        if (!includeGenerated && relativePath.endsWith('.g.dart')) continue;
        if (!includeGenerated && relativePath.endsWith('.freezed.dart')) continue;
        
        files.add(entity.path);
      }
    }
    
    return files;
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
        final visitor = KeyVisitor(
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
              analysis.detectorHits[detector.name]!;
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
    metrics.fileCoverage = (metrics.scannedFiles / metrics.totalFiles * 100);
    
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
    
    // Action handler coverage
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

  /// Detect blind spots in scanning
  List<BlindSpot> _detectBlindSpots() {
    final blindSpots = <BlindSpot>[];
    
    // Check for files with no keys detected
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
    
    // Check for uncovered widget types
    final uncoveredWidgets = <String>{};
    for (final analysis in fileAnalyses.values) {
      uncoveredWidgets.addAll(analysis.uncoveredWidgetTypes);
    }
    
    if (uncoveredWidgets.isNotEmpty) {
      blindSpots.add(BlindSpot(
        type: 'uncovered_widget_types',
        location: 'global',
        severity: 'info',
        message: 'Widget types without key detection: ${uncoveredWidgets.join(', ')}',
      ));
    }
    
    // Check for detector effectiveness
    for (final entry in metrics.detectorHits.entries) {
      if (entry.value == 0) {
        blindSpots.add(BlindSpot(
          type: 'ineffective_detector',
          location: 'detector:${entry.key}',
          severity: 'warning',
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
    return file.readAsLinesSync().length;
  }
}

/// AST visitor for finding keys
class KeyVisitor extends RecursiveAstVisitor<void> {
  final List<KeyDetector> detectors;
  final FileAnalysis analysis;
  final Map<String, KeyUsage> keyUsages;
  final String filePath;
  
  KeyVisitor({
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
      if (detector.matches(node)) {
        final key = detector.extractKey(node);
        if (key != null) {
          _recordKey(key, node, detector);
        }
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
    final typeName = node.constructorName.type.name;
    if (typeName is PrefixedIdentifier) {
      analysis.widgetTypes.add(typeName.identifier.name);
    } else if (typeName is SimpleIdentifier) {
      analysis.widgetTypes.add(typeName.name);
      
      // Check if it's a widget
      if (_isWidget(typeName.name)) {
        analysis.widgetCount++;
        
        // Check for key parameter
        final keyArg = node.argumentList.arguments
            .whereType<NamedExpression>()
            .firstWhere(
              (arg) => arg.name.label.name == 'key',
              orElse: () => null as NamedExpression,
            );
        
        if (keyArg != null) {
          analysis.widgetsWithKeys++;
          
          // Extract key value
          for (final detector in detectors) {
            if (detector.matchesExpression(keyArg.expression)) {
              final key = detector.extractFromExpression(keyArg.expression);
              if (key != null) {
                _recordKey(key, node, detector);
              }
            }
          }
        } else {
          // Widget without key - potential blind spot
          analysis.uncoveredWidgetTypes.add(typeName.name);
        }
      }
    }
    
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    analysis.nodesAnalyzed++;
    analysis.functions.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    analysis.nodesAnalyzed++;
    analysis.methods.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  void _recordKey(String key, AstNode node, KeyDetector detector) {
    // Record in file analysis
    analysis.keysFound.add(key);
    analysis.detectorHits[detector.name] = 
        (analysis.detectorHits[detector.name] ?? 0) + 1;
    
    // Get location info
    final lineInfo = node.root.lineInfo;
    final location = lineInfo?.getLocation(node.offset);
    
    // Create or update key usage
    final usage = keyUsages.putIfAbsent(
      key,
      () => KeyUsage(id: key),
    );
    
    usage.locations.add(KeyLocation(
      file: filePath,
      line: location?.lineNumber ?? 0,
      column: location?.columnNumber ?? 0,
      detector: detector.name,
      context: _getContext(node),
    ));
  }

  void _checkActionHandler(MethodInvocation node) {
    // Check for common action patterns
    final methodName = node.methodName.name;
    final actionPatterns = ['onPressed', 'onTap', 'onSubmit', 'onChanged'];
    
    if (actionPatterns.contains(methodName)) {
      // Find associated key
      final parent = node.parent;
      if (parent is ArgumentList) {
        final widget = parent.parent;
        if (widget is InstanceCreationExpression) {
          // Look for key in same widget
          final keyArg = widget.argumentList.arguments
              .whereType<NamedExpression>()
              .firstWhere(
                (arg) => arg.name.label.name == 'key',
                orElse: () => null as NamedExpression,
              );
          
          if (keyArg != null) {
            // Extract key and link to handler
            for (final detector in detectors) {
              if (detector.matchesExpression(keyArg.expression)) {
                final key = detector.extractFromExpression(keyArg.expression);
                if (key != null) {
                  final usage = keyUsages[key];
                  if (usage != null) {
                    usage.handlers.add(HandlerInfo(
                      type: methodName,
                      method: _extractHandlerMethod(node),
                      file: filePath,
                      line: node.offset,
                    ));
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  String _getContext(AstNode node) {
    // Get surrounding context (widget name, method, etc.)
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
    // Extract the handler method name
    final arg = node.argumentList?.arguments.firstOrNull;
    if (arg is SimpleIdentifier) {
      return arg.name;
    }
    if (arg is FunctionExpression) {
      return '<anonymous>';
    }
    return null;
  }

  bool _isWidget(String typeName) {
    // Common Flutter widget suffixes and names
    return typeName.endsWith('Widget') ||
           typeName.endsWith('Button') ||
           typeName.endsWith('Field') ||
           typeName.endsWith('View') ||
           typeName.endsWith('Screen') ||
           typeName.endsWith('Page') ||
           typeName.endsWith('Dialog') ||
           typeName.endsWith('Card') ||
           typeName.endsWith('List') ||
           typeName.endsWith('Grid') ||
           typeName.endsWith('Container') ||
           typeName.endsWith('Box') ||
           typeName.endsWith('Text') ||
           typeName.endsWith('Image') ||
           typeName.endsWith('Icon') ||
           ['Column', 'Row', 'Stack', 'Scaffold', 'AppBar', 'Center', 
            'Padding', 'Expanded', 'Flexible', 'ListView', 'GridView']
               .contains(typeName);
  }
}

/// Models for scan results
class ScanResult {
  final ScanMetrics metrics;
  final Map<String, FileAnalysis> fileAnalyses;
  final Map<String, KeyUsage> keyUsages;
  final List<BlindSpot> blindSpots;
  final Duration duration;

  ScanResult({
    required this.metrics,
    required this.fileAnalyses,
    required this.keyUsages,
    required this.blindSpots,
    required this.duration,
  });
}

class ScanMetrics {
  int totalFiles = 0;
  int scannedFiles = 0;
  int totalLines = 0;
  int analyzedNodes = 0;
  double fileCoverage = 0;
  double widgetCoverage = 0;
  double handlerCoverage = 0;
  Map<String, int> detectorHits = {};
  List<ScanError> errors = [];
  bool incrementalScan = false;
  String? incrementalBase;
}

class FileAnalysis {
  final String path;
  final String relativePath;
  final Set<String> keysFound = {};
  final Set<String> widgetTypes = {};
  final Set<String> uncoveredWidgetTypes = {};
  final List<String> functions = [];
  final List<String> methods = [];
  final Map<String, int> detectorHits = {};
  int nodesAnalyzed = 0;
  int widgetCount = 0;
  int widgetsWithKeys = 0;

  FileAnalysis({
    required this.path,
    required this.relativePath,
  });
}

class KeyUsage {
  final String id;
  final List<KeyLocation> locations = [];
  final List<HandlerInfo> handlers = [];

  KeyUsage({required this.id});
}

class KeyLocation {
  final String file;
  final int line;
  final int column;
  final String detector;
  final String context;

  KeyLocation({
    required this.file,
    required this.line,
    required this.column,
    required this.detector,
    required this.context,
  });
}

class HandlerInfo {
  final String type;
  final String? method;
  final String file;
  final int line;

  HandlerInfo({
    required this.type,
    this.method,
    required this.file,
    required this.line,
  });
}

class BlindSpot {
  final String type;
  final String location;
  final String severity;
  final String message;

  BlindSpot({
    required this.type,
    required this.location,
    required this.severity,
    required this.message,
  });
}

class ScanError {
  final String file;
  final String error;
  final String type;

  ScanError({
    required this.file,
    required this.error,
    required this.type,
  });
}