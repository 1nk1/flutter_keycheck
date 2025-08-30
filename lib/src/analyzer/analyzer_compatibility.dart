import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Analyzer compatibility layer for versions 5.x through 8.x
/// Provides version-agnostic API for AST analysis
abstract class AnalyzerCompatibility {
  static String getAnalyzerVersion() {
    // This would normally check the actual analyzer version
    // For now, we'll handle common patterns across versions
    return '5.x-8.x compatible';
  }

  /// Get element name safely across analyzer versions
  static String? getElementName(Element? element) {
    if (element == null) return null;

    // Handle different property names across versions
    try {
      // Try newer versions first (6.x+)
      return element.name;
    } catch (_) {
      try {
        // Fallback for older versions
        return element.displayName;
      } catch (_) {
        return null;
      }
    }
  }

  /// Get type name safely
  static String? getTypeName(DartType? type) {
    if (type == null) return null;

    try {
      // Newer versions (6.x+)
      final element = type.element;
      if (element != null) {
        return getElementName(element);
      }
    } catch (_) {
      // Older versions might have different structure
    }

    // Fallback to string representation
    return type.toString();
  }

  /// Check if node is a specific widget type
  static bool isWidgetType(AstNode node, String widgetName) {
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.name;

      // Handle both old and new AST structures
      if (typeName is SimpleIdentifier) {
        return typeName.name == widgetName;
      } else if (typeName is PrefixedIdentifier) {
        return typeName.identifier.name == widgetName;
      }

      // For analyzer 8.x with NamedType
      try {
        final name = typeName.toString();
        return name == widgetName;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Extract string literal value safely
  static String? getStringLiteralValue(Expression? expression) {
    if (expression == null) return null;

    if (expression is SimpleStringLiteral) {
      return expression.value;
    }

    if (expression is StringInterpolation) {
      // Try to extract if it's a simple interpolation
      final buffer = StringBuffer();
      for (final element in expression.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else {
          // Can't resolve interpolation at compile time
          return null;
        }
      }
      return buffer.toString();
    }

    return null;
  }

  /// Get function/method name safely
  static String? getFunctionName(FunctionDeclaration? function) {
    if (function == null) return null;

    try {
      // Standard approach for all versions
      return function.name.lexeme;
    } catch (_) {
      try {
        // Alternative for some versions
        return function.name.toString();
      } catch (_) {
        return null;
      }
    }
  }

  /// Check if expression is a Key constructor
  static bool isKeyConstructor(Expression? expression) {
    if (expression == null) return false;

    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.name;

      // Handle different AST structures
      final typeString = typeName.toString();
      return typeString == 'Key' ||
          typeString == 'ValueKey' ||
          typeString == 'GlobalKey' ||
          typeString == 'ObjectKey' ||
          typeString == 'UniqueKey';
    }

    return false;
  }

  /// Extract argument value from named expression
  static Expression? getNamedArgumentValue(
      ArgumentList? arguments, String name) {
    if (arguments == null) return null;

    for (final arg in arguments.arguments) {
      if (arg is NamedExpression) {
        final label = arg.name.label;
        if (label.name == name) {
          return arg.expression;
        }
      }
    }

    return null;
  }

  /// Get positional argument safely
  static Expression? getPositionalArgument(ArgumentList? arguments, int index) {
    if (arguments == null) return null;

    final positionalArgs =
        arguments.arguments.where((arg) => arg is! NamedExpression).toList();

    if (index < positionalArgs.length) {
      return positionalArgs[index];
    }

    return null;
  }
}

/// Universal AST visitor that works across analyzer versions
class UniversalAstVisitor extends RecursiveAstVisitor<void> {
  final List<KeyUsageInfo> keyUsages = [];
  final String filePath;

  UniversalAstVisitor(this.filePath);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check for Key constructors
    if (AnalyzerCompatibility.isKeyConstructor(node)) {
      final keyValue = _extractKeyValue(node);
      if (keyValue != null) {
        keyUsages.add(KeyUsageInfo(
          keyName: keyValue,
          file: filePath,
          line: node.offset,
          type: _getKeyType(node),
        ));
      }
    }

    // Check for widgets with key parameters
    final keyArg = AnalyzerCompatibility.getNamedArgumentValue(
      node.argumentList,
      'key',
    );

    if (keyArg != null && AnalyzerCompatibility.isKeyConstructor(keyArg)) {
      final keyValue = _extractKeyValue(keyArg as InstanceCreationExpression);
      if (keyValue != null) {
        keyUsages.add(KeyUsageInfo(
          keyName: keyValue,
          file: filePath,
          line: node.offset,
          type: 'widget_key',
        ));
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for find.byKey patterns
    final methodName = node.methodName.name;

    if (methodName == 'byKey' || methodName == 'byValueKey') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'find') {
        final keyArg = AnalyzerCompatibility.getPositionalArgument(
          node.argumentList,
          0,
        );

        if (keyArg != null) {
          String? keyValue;

          if (AnalyzerCompatibility.isKeyConstructor(keyArg)) {
            keyValue = _extractKeyValue(keyArg as InstanceCreationExpression);
          } else {
            keyValue = AnalyzerCompatibility.getStringLiteralValue(keyArg);
          }

          if (keyValue != null) {
            keyUsages.add(KeyUsageInfo(
              keyName: keyValue,
              file: filePath,
              line: node.offset,
              type: 'test_finder',
            ));
          }
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  String? _extractKeyValue(InstanceCreationExpression node) {
    final firstArg = AnalyzerCompatibility.getPositionalArgument(
      node.argumentList,
      0,
    );

    if (firstArg != null) {
      // Try to extract string literal
      final stringValue = AnalyzerCompatibility.getStringLiteralValue(firstArg);
      if (stringValue != null) {
        return stringValue;
      }

      // Handle const references
      if (firstArg is SimpleIdentifier) {
        return firstArg.name;
      }

      if (firstArg is PrefixedIdentifier) {
        return firstArg.identifier.name;
      }
    }

    return null;
  }

  String _getKeyType(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.toString();
    return typeName.toLowerCase();
  }
}

/// Key usage information
class KeyUsageInfo {
  final String keyName;
  final String file;
  final int line;
  final String type;

  KeyUsageInfo({
    required this.keyName,
    required this.file,
    required this.line,
    required this.type,
  });
}
