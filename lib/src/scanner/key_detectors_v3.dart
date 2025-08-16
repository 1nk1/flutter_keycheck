import 'package:analyzer/dart/ast/ast.dart';

/// Base class for key detectors
abstract class KeyDetector {
  String get name;

  /// Detect key in a method invocation
  DetectionResult? detect(MethodInvocation node);

  /// Detect key in an expression
  DetectionResult? detectExpression(Expression expression);
}

/// Result of key detection
class DetectionResult {
  final String key;
  final String detector;
  final List<String>? tags;
  final Map<String, dynamic>? metadata;

  DetectionResult({
    required this.key,
    required this.detector,
    this.tags,
    this.metadata,
  });
}

/// Detector for ValueKey usage
class ValueKeyDetector extends KeyDetector {
  @override
  String get name => 'ValueKey';

  @override
  DetectionResult? detect(MethodInvocation node) {
    if (node.methodName.name == 'ValueKey' ||
        node.target?.toString() == 'ValueKey') {
      final arg = node.argumentList.arguments.isNotEmpty == true
          ? node.argumentList.arguments.first
          : null;
      if (arg is StringLiteral) {
        return DetectionResult(
          key: arg.stringValue ?? '',
          detector: name,
        );
      }
    }
    return null;
  }

  @override
  DetectionResult? detectExpression(Expression expression) {
    if (expression is MethodInvocation) {
      return detect(expression);
    }
    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.toString();
      if (typeName == 'ValueKey') {
        final arg = expression.argumentList.arguments.isNotEmpty
            ? expression.argumentList.arguments.first
            : null;
        if (arg is StringLiteral) {
          return DetectionResult(
            key: arg.stringValue ?? '',
            detector: name,
          );
        }
      }
    }
    return null;
  }
}

/// Detector for Key constructor usage
class BasicKeyDetector extends KeyDetector {
  @override
  String get name => 'Key';

  @override
  DetectionResult? detect(MethodInvocation node) {
    if (node.methodName.name == 'Key') {
      final arg = node.argumentList.arguments.isNotEmpty == true
          ? node.argumentList.arguments.first
          : null;
      if (arg is StringLiteral) {
        return DetectionResult(
          key: arg.stringValue ?? '',
          detector: name,
        );
      }
    }
    return null;
  }

  @override
  DetectionResult? detectExpression(Expression expression) {
    if (expression is MethodInvocation) {
      return detect(expression);
    }
    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.toString();
      if (typeName == 'Key') {
        final arg = expression.argumentList.arguments.isNotEmpty
            ? expression.argumentList.arguments.first
            : null;
        if (arg is StringLiteral) {
          return DetectionResult(
            key: arg.stringValue ?? '',
            detector: name,
          );
        }
      }
    }
    return null;
  }
}

/// Detector for const Key usage
class ConstKeyDetector extends KeyDetector {
  @override
  String get name => 'ConstKey';

  @override
  DetectionResult? detect(MethodInvocation node) {
    // Check for const Key('...')
    final parent = node.parent;
    if (parent is NamedExpression && parent.name.label.name == 'key') {
      if (node.methodName.name == 'Key') {
        final arg = node.argumentList.arguments.isNotEmpty == true
            ? node.argumentList.arguments.first
            : null;
        if (arg is StringLiteral) {
          return DetectionResult(
            key: arg.stringValue ?? '',
            detector: name,
            tags: ['const'],
          );
        }
      }
    }
    return null;
  }

  @override
  DetectionResult? detectExpression(Expression expression) {
    // Check for const expressions
    if (expression is InstanceCreationExpression && expression.isConst) {
      final typeName = expression.constructorName.type.toString();
      if (typeName == 'Key' || typeName == 'ValueKey') {
        final arg = expression.argumentList.arguments.isNotEmpty
            ? expression.argumentList.arguments.first
            : null;
        if (arg is StringLiteral) {
          return DetectionResult(
            key: arg.stringValue ?? '',
            detector: name,
            tags: ['const'],
          );
        }
      }
    }
    return null;
  }
}

/// Detector for semantic keys (Semantics widget)
class SemanticKeyDetector extends KeyDetector {
  @override
  String get name => 'Semantics';

  @override
  DetectionResult? detect(MethodInvocation node) {
    // This detector doesn't handle method invocations
    // Semantics is a widget constructor, not a method
    return null;
  }

  @override
  DetectionResult? detectExpression(Expression expression) {
    // Semantics widgets are handled differently
    // They use identifier parameter, not key parameter
    // This is handled in the AST scanner's _checkSemanticsWidget method
    return null;
  }
}

/// Detector for test keys (testWidgets, find.byKey)
class TestKeyDetector extends KeyDetector {
  @override
  String get name => 'TestKey';

  @override
  DetectionResult? detect(MethodInvocation node) {
    // Check for find.byKey
    if (node.methodName.name == 'byKey') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'find') {
        final arg = node.argumentList.arguments.isNotEmpty == true
            ? node.argumentList.arguments.first
            : null;
        if (arg is InstanceCreationExpression) {
          final typeName = arg.constructorName.type.toString();
          if (typeName == 'Key' || typeName == 'ValueKey') {
            final keyArg = arg.argumentList.arguments.isNotEmpty
                ? arg.argumentList.arguments.first
                : null;
            if (keyArg is StringLiteral) {
              return DetectionResult(
                key: keyArg.stringValue ?? '',
                detector: name,
                tags: ['test', 'e2e'],
              );
            }
          }
        }
      }
    }
    return null;
  }

  @override
  DetectionResult? detectExpression(Expression expression) {
    if (expression is MethodInvocation) {
      return detect(expression);
    }
    return null;
  }
}
