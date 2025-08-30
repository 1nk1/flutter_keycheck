// Custom analyzer plugin for Flutter KeyCheck
// Demonstrates extensible plugin architecture

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Custom analyzer plugin that detects additional patterns
class CustomAnalyzerPlugin extends RecursiveAstVisitor<void> {
  final List<String> detectedPatterns = [];
  
  /// Plugin metadata
  static const String name = 'CustomAnalyzer';
  static const String version = '1.0.0';
  static const String description = 'Custom pattern detection for enterprise requirements';
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Detect custom key patterns (e.g., TestID, AutomationKey)
    final methodName = node.methodName.name;
    
    if (methodName == 'TestID' || methodName == 'AutomationKey') {
      final arguments = node.argumentList.arguments;
      if (arguments.isNotEmpty) {
        final firstArg = arguments.first;
        if (firstArg is StringLiteral) {
          detectedPatterns.add('${methodName}: ${firstArg.stringValue}');
        }
      }
    }
    
    // Detect custom widget patterns
    if (methodName.endsWith('TestWidget') || methodName.endsWith('AutomationWidget')) {
      detectedPatterns.add('CustomWidget: $methodName');
    }
    
    super.visitMethodInvocation(node);
  }
  
  @override
  void visitAnnotation(Annotation node) {
    // Detect custom annotations
    final name = node.name.toString();
    if (name == 'AutomationTarget' || name == 'TestIdentifier') {
      detectedPatterns.add('Annotation: $name');
    }
    super.visitAnnotation(node);
  }
  
  /// Get analysis results
  Map<String, dynamic> getResults() {
    return {
      'plugin': name,
      'version': version,
      'patterns_found': detectedPatterns.length,
      'patterns': detectedPatterns,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Plugin capabilities
  static Map<String, dynamic> getCapabilities() {
    return {
      'supports_async': true,
      'supports_caching': true,
      'supports_incremental': true,
      'pattern_types': [
        'TestID',
        'AutomationKey',
        'CustomWidget',
        'Annotations',
      ],
      'file_extensions': ['.dart'],
      'priority': 100,
    };
  }
}