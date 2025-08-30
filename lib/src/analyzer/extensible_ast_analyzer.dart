import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;
import 'analyzer_compatibility.dart';

/// Extensible AST analyzer with plugin architecture
class ExtensibleAstAnalyzer {
  final List<AstAnalyzerPlugin> plugins = [];
  final Set<String> ignorePatterns;
  final bool parallel;

  ExtensibleAstAnalyzer({
    Set<String>? ignorePatterns,
    this.parallel = true,
  }) : ignorePatterns = ignorePatterns ?? {};

  /// Register a plugin for custom analysis
  void registerPlugin(AstAnalyzerPlugin plugin) {
    plugins.add(plugin);
  }

  /// Analyze a Flutter project
  Future<AnalysisResult> analyzeProject(String projectPath) async {
    final files = await _discoverDartFiles(projectPath);
    final filteredFiles = _filterFiles(files);

    final results = <FileAnalysisResult>[];

    if (parallel) {
      // Parallel analysis for better performance
      final futures =
          filteredFiles.map((file) => _analyzeFile(file, projectPath));
      results.addAll(await Future.wait(futures));
    } else {
      // Sequential analysis
      for (final file in filteredFiles) {
        results.add(await _analyzeFile(file, projectPath));
      }
    }

    // Aggregate results
    return _aggregateResults(results, projectPath);
  }

  /// Discover all Dart files in project
  Future<List<String>> _discoverDartFiles(String projectPath) async {
    final files = <String>[];
    final dir = Directory(projectPath);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }

    return files;
  }

  /// Filter files based on ignore patterns
  List<String> _filterFiles(List<String> files) {
    return files.where((file) {
      for (final pattern in ignorePatterns) {
        if (_matchesPattern(file, pattern)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Check if file matches ignore pattern
  bool _matchesPattern(String file, String pattern) {
    // Simple glob-like pattern matching
    if (pattern.contains('*')) {
      final regex = pattern
          .replaceAll('.', r'\.')
          .replaceAll('*', '.*')
          .replaceAll('/', r'[/\\]');
      return RegExp(regex).hasMatch(file);
    }
    return file.contains(pattern);
  }

  /// Analyze a single file
  Future<FileAnalysisResult> _analyzeFile(
      String filePath, String projectPath) async {
    try {
      final collection = AnalysisContextCollection(
        includedPaths: [filePath],
      );

      final context = collection.contextFor(filePath);
      final resolvedUnit =
          await context.currentSession.getResolvedUnit(filePath);

      if (resolvedUnit is ResolvedUnitResult) {
        final unit = resolvedUnit.unit;
        final visitor = ExtensibleAstVisitor(filePath, plugins);
        unit.accept(visitor);

        return FileAnalysisResult(
          path: path.relative(filePath, from: projectPath),
          absolutePath: filePath,
          findings: visitor.findings,
          metrics: visitor.metrics,
          errors: [],
        );
      }
    } catch (e) {
      return FileAnalysisResult(
        path: path.relative(filePath, from: projectPath),
        absolutePath: filePath,
        findings: [],
        metrics: {},
        errors: [e.toString()],
      );
    }

    return FileAnalysisResult(
      path: path.relative(filePath, from: projectPath),
      absolutePath: filePath,
      findings: [],
      metrics: {},
      errors: ['Failed to analyze file'],
    );
  }

  /// Aggregate analysis results
  AnalysisResult _aggregateResults(
      List<FileAnalysisResult> results, String projectPath) {
    final allFindings = <Finding>[];
    final aggregatedMetrics = <String, dynamic>{};
    final errors = <String>[];

    for (final result in results) {
      allFindings.addAll(result.findings);
      errors.addAll(result.errors);

      // Merge metrics
      result.metrics.forEach((key, value) {
        if (aggregatedMetrics.containsKey(key)) {
          // Aggregate numeric metrics
          if (value is num && aggregatedMetrics[key] is num) {
            aggregatedMetrics[key] = aggregatedMetrics[key] + value;
          } else if (value is List && aggregatedMetrics[key] is List) {
            (aggregatedMetrics[key] as List).addAll(value);
          }
        } else {
          aggregatedMetrics[key] = value;
        }
      });
    }

    // Let plugins post-process results
    for (final plugin in plugins) {
      plugin.postProcess(allFindings, aggregatedMetrics);
    }

    return AnalysisResult(
      projectPath: projectPath,
      files: results,
      findings: allFindings,
      metrics: aggregatedMetrics,
      errors: errors,
    );
  }
}

/// Extensible AST visitor
class ExtensibleAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<AstAnalyzerPlugin> plugins;
  final List<Finding> findings = [];
  final Map<String, dynamic> metrics = {};

  ExtensibleAstVisitor(this.filePath, this.plugins);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // Let plugins initialize
    for (final plugin in plugins) {
      plugin.beforeAnalysis(node, filePath);
    }

    super.visitCompilationUnit(node);

    // Let plugins finalize
    for (final plugin in plugins) {
      final pluginFindings = plugin.afterAnalysis(node, filePath);
      findings.addAll(pluginFindings);

      final pluginMetrics = plugin.getMetrics();
      metrics.addAll(pluginMetrics);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Let plugins analyze
    for (final plugin in plugins) {
      final finding = plugin.analyzeInstanceCreation(node, filePath);
      if (finding != null) {
        findings.add(finding);
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Let plugins analyze
    for (final plugin in plugins) {
      final finding = plugin.analyzeMethodInvocation(node, filePath);
      if (finding != null) {
        findings.add(finding);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Let plugins analyze
    for (final plugin in plugins) {
      final finding = plugin.analyzeFunctionDeclaration(node, filePath);
      if (finding != null) {
        findings.add(finding);
      }
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Let plugins analyze
    for (final plugin in plugins) {
      final finding = plugin.analyzeClassDeclaration(node, filePath);
      if (finding != null) {
        findings.add(finding);
      }
    }

    super.visitClassDeclaration(node);
  }
}

/// Base class for AST analyzer plugins
abstract class AstAnalyzerPlugin {
  /// Called before analysis starts
  void beforeAnalysis(CompilationUnit unit, String filePath) {}

  /// Called after analysis completes
  List<Finding> afterAnalysis(CompilationUnit unit, String filePath) {
    return [];
  }

  /// Analyze instance creation expressions
  Finding? analyzeInstanceCreation(
      InstanceCreationExpression node, String filePath) {
    return null;
  }

  /// Analyze method invocations
  Finding? analyzeMethodInvocation(MethodInvocation node, String filePath) {
    return null;
  }

  /// Analyze function declarations
  Finding? analyzeFunctionDeclaration(
      FunctionDeclaration node, String filePath) {
    return null;
  }

  /// Analyze class declarations
  Finding? analyzeClassDeclaration(ClassDeclaration node, String filePath) {
    return null;
  }

  /// Get metrics collected by this plugin
  Map<String, dynamic> getMetrics() {
    return {};
  }

  /// Post-process all findings
  void postProcess(List<Finding> findings, Map<String, dynamic> metrics) {}
}

/// Flutter Key analyzer plugin
class FlutterKeyAnalyzerPlugin extends AstAnalyzerPlugin {
  final List<KeyFinding> keyFindings = [];
  int totalKeys = 0;
  int widgetKeys = 0;
  int testKeys = 0;

  @override
  Finding? analyzeInstanceCreation(
      InstanceCreationExpression node, String filePath) {
    if (AnalyzerCompatibility.isKeyConstructor(node)) {
      final keyValue = _extractKeyValue(node);
      if (keyValue != null) {
        totalKeys++;
        final finding = KeyFinding(
          type: FindingType.key,
          severity: Severity.info,
          message: 'Found key: $keyValue',
          filePath: filePath,
          line: _getLineNumber(node),
          keyName: keyValue,
          keyType: _getKeyType(node),
        );
        keyFindings.add(finding);
        return finding;
      }
    }

    // Check for widgets with keys
    final keyArg = AnalyzerCompatibility.getNamedArgumentValue(
      node.argumentList,
      'key',
    );

    if (keyArg != null && AnalyzerCompatibility.isKeyConstructor(keyArg)) {
      widgetKeys++;
    }

    return null;
  }

  @override
  Finding? analyzeMethodInvocation(MethodInvocation node, String filePath) {
    final methodName = node.methodName.name;

    if (methodName == 'byKey' || methodName == 'byValueKey') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'find') {
        testKeys++;
        return Finding(
          type: FindingType.testFinder,
          severity: Severity.info,
          message: 'Test finder using key',
          filePath: filePath,
          line: _getLineNumber(node),
        );
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> getMetrics() {
    return {
      'totalKeys': totalKeys,
      'widgetKeys': widgetKeys,
      'testKeys': testKeys,
      'keyFindings': keyFindings,
    };
  }

  String? _extractKeyValue(InstanceCreationExpression node) {
    final firstArg = AnalyzerCompatibility.getPositionalArgument(
      node.argumentList,
      0,
    );

    if (firstArg != null) {
      return AnalyzerCompatibility.getStringLiteralValue(firstArg) ??
          firstArg.toString();
    }

    return null;
  }

  String _getKeyType(InstanceCreationExpression node) {
    return node.constructorName.type.name.toString();
  }

  int _getLineNumber(AstNode node) {
    // This would normally calculate the actual line number
    // For simplicity, using offset
    return node.offset;
  }
}

/// Analysis result
class AnalysisResult {
  final String projectPath;
  final List<FileAnalysisResult> files;
  final List<Finding> findings;
  final Map<String, dynamic> metrics;
  final List<String> errors;

  AnalysisResult({
    required this.projectPath,
    required this.files,
    required this.findings,
    required this.metrics,
    required this.errors,
  });
}

/// File analysis result
class FileAnalysisResult {
  final String path;
  final String absolutePath;
  final List<Finding> findings;
  final Map<String, dynamic> metrics;
  final List<String> errors;

  FileAnalysisResult({
    required this.path,
    required this.absolutePath,
    required this.findings,
    required this.metrics,
    required this.errors,
  });
}

/// Finding from analysis
class Finding {
  final FindingType type;
  final Severity severity;
  final String message;
  final String filePath;
  final int line;

  Finding({
    required this.type,
    required this.severity,
    required this.message,
    required this.filePath,
    required this.line,
  });
}

/// Key-specific finding
class KeyFinding extends Finding {
  final String keyName;
  final String keyType;

  KeyFinding({
    required FindingType type,
    required Severity severity,
    required String message,
    required String filePath,
    required int line,
    required this.keyName,
    required this.keyType,
  }) : super(
          type: type,
          severity: severity,
          message: message,
          filePath: filePath,
          line: line,
        );
}

/// Finding types
enum FindingType {
  key,
  testFinder,
  issue,
  warning,
  info,
}

/// Severity levels
enum Severity {
  error,
  warning,
  info,
}
