import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/semantics/semantics_detector.dart';

/// Semantic analysis result for a widget
class SemanticAnalysisResult {
  final String widgetType;
  final String? keyValue;
  final bool hasSemantics;
  final bool hasAccessibilityLabel;
  final bool hasAccessibilityHint;
  final bool hasAccessibilityValue;
  final bool isInteractive;
  final List<SemanticViolation> violations;
  final KeyLocation? location;
  final String? context;

  SemanticAnalysisResult({
    required this.widgetType,
    this.keyValue,
    required this.hasSemantics,
    required this.hasAccessibilityLabel,
    required this.hasAccessibilityHint,
    required this.hasAccessibilityValue,
    required this.isInteractive,
    required this.violations,
    this.location,
    this.context,
  });

  double get semanticsScore {
    double score = 0;
    int total = 0;

    if (hasSemantics) score += 1;
    total++;

    if (isInteractive) {
      if (hasAccessibilityLabel) score += 1;
      if (hasAccessibilityHint) score += 1;
      total += 2;
    } else {
      if (hasAccessibilityLabel) score += 0.5;
      total++;
    }

    return total > 0 ? (score / total) * 100 : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'widgetType': widgetType,
      'keyValue': keyValue,
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': hasAccessibilityHint,
      'hasAccessibilityValue': hasAccessibilityValue,
      'isInteractive': isInteractive,
      'semanticsScore': semanticsScore,
      'violations': violations.map((v) => v.toMap()).toList(),
      'location': location?.toMap(),
      'context': context,
    };
  }
}

/// Semantic violation types
enum ViolationType {
  missingLabel,
  missingHint,
  missingSemantics,
  missingValue,
  redundantLabel,
  poorContrast,
  focusIssue,
  interactiveWithoutKey,
}

/// Semantic violation found during analysis
class SemanticViolation {
  final ViolationType type;
  final String severity; // 'error', 'warning', 'info'
  final String message;
  final String? suggestion;
  final KeyLocation? location;

  SemanticViolation({
    required this.type,
    required this.severity,
    required this.message,
    this.suggestion,
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'severity': severity,
      'message': message,
      'suggestion': suggestion,
      'location': location?.toMap(),
    };
  }
}

/// Semantic coverage metrics
class SemanticsCoverageMetrics {
  int totalWidgets = 0;
  int widgetsWithSemantics = 0;
  int interactiveWidgets = 0;
  int interactiveWithLabels = 0;
  int widgetsWithKeys = 0;
  int interactiveWithKeys = 0;
  Map<String, int> violationCounts = {};
  Map<String, List<SemanticAnalysisResult>> widgetAnalysis = {};

  double get semanticsCoverage {
    return totalWidgets > 0 ? (widgetsWithSemantics / totalWidgets) * 100 : 0;
  }

  double get interactiveLabelCoverage {
    return interactiveWidgets > 0 ? (interactiveWithLabels / interactiveWidgets) * 100 : 0;
  }

  double get keySemanticsCoverage {
    return widgetsWithKeys > 0 ? (widgetsWithSemantics / widgetsWithKeys) * 100 : 0;
  }

  double get interactiveKeyCoverage {
    return interactiveWidgets > 0 ? (interactiveWithKeys / interactiveWidgets) * 100 : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWidgets': totalWidgets,
      'widgetsWithSemantics': widgetsWithSemantics,
      'interactiveWidgets': interactiveWidgets,
      'interactiveWithLabels': interactiveWithLabels,
      'widgetsWithKeys': widgetsWithKeys,
      'interactiveWithKeys': interactiveWithKeys,
      'semanticsCoverage': semanticsCoverage,
      'interactiveLabelCoverage': interactiveLabelCoverage,
      'keySemanticsCoverage': keySemanticsCoverage,
      'interactiveKeyCoverage': interactiveKeyCoverage,
      'violationCounts': violationCounts,
      'violationsSummary': violationCounts.entries
          .map((e) => {'type': e.key, 'count': e.value})
          .toList(),
    };
  }
}

/// Semantics analyzer for Flutter widgets
///
/// Analyzes AST nodes to detect widgets with semantic properties,
/// identifies accessibility violations, and calculates coverage metrics.
class SemanticsAnalyzer {
  final List<SemanticsDetector> detectors;
  final Map<String, KeyUsage> keyUsages;
  final SemanticsCoverageMetrics metrics = SemanticsCoverageMetrics();

  SemanticsAnalyzer({
    required this.keyUsages,
    List<SemanticsDetector>? customDetectors,
  }) : detectors = customDetectors ?? _getDefaultDetectors();

  static List<SemanticsDetector> _getDefaultDetectors() {
    return [
      ButtonSemanticsDetector(),
      TextFieldSemanticsDetector(),
      ImageSemanticsDetector(),
      ListSemanticsDetector(),
      InteractiveSemanticsDetector(),
      FormSemanticsDetector(),
      NavigationSemanticsDetector(),
      MediaSemanticsDetector(),
    ];
  }

  /// Analyze file for semantic properties
  Future<List<SemanticAnalysisResult>> analyzeFile(
    String filePath,
    CompilationUnit unit,
  ) async {
    final visitor = _SemanticVisitor(
      filePath: filePath,
      detectors: detectors,
      keyUsages: keyUsages,
      analyzer: this,
    );

    unit.accept(visitor);

    // Store results in metrics
    metrics.widgetAnalysis[filePath] = visitor.results;

    return visitor.results;
  }

  /// Analyze widget node for semantic properties
  SemanticAnalysisResult analyzeWidget(
    AstNode node,
    String widgetType,
    String filePath, {
    String? keyValue,
    String? context,
  }) {
    final violations = <SemanticViolation>[];
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;
    bool hasAccessibilityHint = false;
    bool hasAccessibilityValue = false;
    bool isInteractive = false;

    // Check if widget is interactive
    for (final detector in detectors) {
      if (detector.isApplicable(widgetType)) {
        isInteractive = detector.isInteractive(widgetType);

        // Analyze semantic properties
        final analysis = detector.analyze(node, widgetType);
        hasSemantics = analysis['hasSemantics'] ?? false;
        hasAccessibilityLabel = analysis['hasAccessibilityLabel'] ?? false;
        hasAccessibilityHint = analysis['hasAccessibilityHint'] ?? false;
        hasAccessibilityValue = analysis['hasAccessibilityValue'] ?? false;

        // Check for violations
        violations.addAll(detector.checkViolations(node, widgetType, keyValue));
        break;
      }
    }

    // Get location info
    KeyLocation? location;
    if (node.root != null) {
      final lineInfo = (node.root as CompilationUnit).lineInfo;
      final locationInfo = lineInfo.getLocation(node.offset);
      location = KeyLocation(
        file: filePath,
        line: locationInfo.lineNumber,
        column: locationInfo.columnNumber,
        detector: 'SemanticsAnalyzer',
        context: context ?? _getNodeContext(node),
      );
    }

    return SemanticAnalysisResult(
      widgetType: widgetType,
      keyValue: keyValue,
      hasSemantics: hasSemantics,
      hasAccessibilityLabel: hasAccessibilityLabel,
      hasAccessibilityHint: hasAccessibilityHint,
      hasAccessibilityValue: hasAccessibilityValue,
      isInteractive: isInteractive,
      violations: violations,
      location: location,
      context: context,
    );
  }

  /// Get context information for a node
  String _getNodeContext(AstNode node) {
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

  /// Check if widget type requires semantics
  bool requiresSemantics(String widgetType) {
    return detectors.any((d) => d.isApplicable(widgetType) && d.isInteractive(widgetType));
  }

  /// Get suggestions for improving semantics
  List<String> getSuggestions(SemanticAnalysisResult result) {
    final suggestions = <String>[];

    if (result.isInteractive && !result.hasAccessibilityLabel) {
      suggestions.add('Add semanticLabel or accessibilityLabel to provide screen reader description');
    }

    if (result.isInteractive && !result.hasSemantics && result.keyValue == null) {
      suggestions.add('Add a unique key to enable automated testing');
    }

    if (result.widgetType.contains('Button') && !result.hasAccessibilityHint) {
      suggestions.add('Consider adding accessibilityHint to describe button action');
    }

    if (result.widgetType == 'Image' && !result.hasAccessibilityLabel) {
      suggestions.add('Add semanticLabel to describe image content for screen readers');
    }

    if (result.widgetType.contains('TextField') && !result.hasAccessibilityHint) {
      suggestions.add('Add accessibilityHint to describe expected input format');
    }

    return suggestions;
  }
}

/// AST visitor for semantic analysis
class _SemanticVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<SemanticsDetector> detectors;
  final Map<String, KeyUsage> keyUsages;
  final SemanticsAnalyzer analyzer;
  final List<SemanticAnalysisResult> results = [];

  _SemanticVisitor({
    required this.filePath,
    required this.detectors,
    required this.keyUsages,
    required this.analyzer,
  });

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toString();

    if (_isWidget(typeName)) {
      _analyzeWidget(node, typeName);
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    if (_isWidget(methodName) && node.target == null) {
      _analyzeWidget(node, methodName);
    }

    super.visitMethodInvocation(node);
  }

  void _analyzeWidget(AstNode node, String widgetType) {
    analyzer.metrics.totalWidgets++;

    // Extract key value if present
    String? keyValue;
    bool hasKey = false;

    if (node is InstanceCreationExpression) {
      final keyArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'key')
          .firstOrNull;

      if (keyArg != null) {
        hasKey = true;
        keyValue = _extractKeyValue(keyArg.expression);
      }
    } else if (node is MethodInvocation) {
      final keyArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'key')
          .firstOrNull;

      if (keyArg != null) {
        hasKey = true;
        keyValue = _extractKeyValue(keyArg.expression);
      }
    }

    if (hasKey) {
      analyzer.metrics.widgetsWithKeys++;
    }

    // Analyze semantic properties
    final result = analyzer.analyzeWidget(node, widgetType, filePath, keyValue: keyValue);

    // Update metrics
    if (result.hasSemantics) {
      analyzer.metrics.widgetsWithSemantics++;
    }

    if (result.isInteractive) {
      analyzer.metrics.interactiveWidgets++;

      if (result.hasAccessibilityLabel) {
        analyzer.metrics.interactiveWithLabels++;
      }

      if (hasKey) {
        analyzer.metrics.interactiveWithKeys++;
      }
    }

    // Count violations
    for (final violation in result.violations) {
      analyzer.metrics.violationCounts[violation.type.name] =
          (analyzer.metrics.violationCounts[violation.type.name] ?? 0) + 1;
    }

    results.add(result);
  }

  String? _extractKeyValue(Expression expression) {
    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.toString();
      if (typeName == 'ValueKey') {
        final arg = expression.argumentList.arguments.firstOrNull;
        if (arg is StringLiteral) {
          return arg.stringValue;
        }
      }
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
        [
          'Column',
          'Row',
          'Stack',
          'Scaffold',
          'AppBar',
          'Center',
          'Padding',
          'Expanded',
          'ListView',
          'GridView',
          'Container',
          'Text',
          'Image',
          'Icon',
          'MaterialApp',
          'CupertinoApp',
          'Semantics',
          'ElevatedButton',
          'TextButton',
          'IconButton',
          'OutlinedButton'
        ].contains(typeName);
  }
}
