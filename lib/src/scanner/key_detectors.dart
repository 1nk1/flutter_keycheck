import 'package:analyzer/dart/ast/ast.dart';
import 'package:yaml/yaml.dart';

/// Base class for key detectors
abstract class KeyDetector {
  final String name;
  final String description;
  final int priority;
  final Map<String, dynamic> config;

  // Metrics
  int matchCount = 0;
  int extractCount = 0;
  final List<String> matchedPatterns = [];

  KeyDetector({
    required this.name,
    required this.description,
    this.priority = 0,
    this.config = const {},
  });

  /// Check if AST node matches this detector
  bool matches(AstNode node);

  /// Extract key value from matched node
  String? extractKey(AstNode node);

  /// Check if expression matches
  bool matchesExpression(Expression expr);

  /// Extract from expression
  String? extractFromExpression(Expression expr);

  /// Get detector metrics
  Map<String, dynamic> getMetrics() => {
        'name': name,
        'matches': matchCount,
        'extracted': extractCount,
        'patterns': matchedPatterns.toSet().toList(),
      };
}

/// Detector for ValueKey patterns
class ValueKeyDetector extends KeyDetector {
  ValueKeyDetector({Map<String, dynamic>? config})
      : super(
          name: 'ValueKey',
          description: 'Detects ValueKey(...) patterns',
          priority: 10,
          config: config ?? {},
        );

  @override
  bool matches(AstNode node) {
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.toString();
      if (typeName == 'ValueKey' || typeName.endsWith('.ValueKey')) {
        matchCount++;
        return true;
      }
    }
    return false;
  }

  @override
  String? extractKey(AstNode node) {
    if (node is InstanceCreationExpression) {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final key = _extractStringValue(args.first);
        if (key != null) {
          extractCount++;
          matchedPatterns.add('ValueKey("$key")');
        }
        return key;
      }
    }
    return null;
  }

  @override
  bool matchesExpression(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return matches(expr);
    }
    return false;
  }

  @override
  String? extractFromExpression(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return extractKey(expr);
    }
    return null;
  }

  String? _extractStringValue(Expression expr) {
    if (expr is SimpleStringLiteral) {
      return expr.value;
    }
    if (expr is StringInterpolation) {
      // Handle string interpolation
      final buffer = StringBuffer();
      for (final element in expr.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else if (element is InterpolationExpression) {
          buffer.write('\${...}');
        }
      }
      return buffer.toString();
    }
    if (expr is PrefixedIdentifier) {
      // Handle constants like KeyConstants.loginButton
      return '${expr.prefix}.${expr.identifier}';
    }
    if (expr is PropertyAccess) {
      // Handle property access
      return expr.toString();
    }
    return null;
  }
}

/// Detector for Key patterns
class BasicKeyDetector extends KeyDetector {
  BasicKeyDetector({Map<String, dynamic>? config})
      : super(
          name: 'Key',
          description: 'Detects Key(...) patterns',
          priority: 9,
          config: config ?? {},
        );

  @override
  bool matches(AstNode node) {
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.toString();
      if (typeName == 'Key' || typeName.endsWith('.Key')) {
        matchCount++;
        return true;
      }
    }
    return false;
  }

  @override
  String? extractKey(AstNode node) {
    if (node is InstanceCreationExpression) {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final key = _extractStringValue(args.first);
        if (key != null) {
          extractCount++;
          matchedPatterns.add('Key("$key")');
        }
        return key;
      }
    }
    return null;
  }

  @override
  bool matchesExpression(Expression expr) => matches(expr);

  @override
  String? extractFromExpression(Expression expr) => extractKey(expr);

  String? _extractStringValue(Expression expr) {
    // Same implementation as ValueKeyDetector
    if (expr is SimpleStringLiteral) {
      return expr.value;
    }
    // ... other cases
    return null;
  }
}

/// Detector for find.byKey patterns in tests
class FindByKeyDetector extends KeyDetector {
  FindByKeyDetector({Map<String, dynamic>? config})
      : super(
          name: 'FindByKey',
          description: 'Detects find.byKey(...) patterns in tests',
          priority: 8,
          config: config ?? {},
        );

  @override
  bool matches(AstNode node) {
    if (node is MethodInvocation) {
      final target = node.target?.toString();
      final method = node.methodName.name;
      if (target == 'find' && (method == 'byKey' || method == 'byValueKey')) {
        matchCount++;
        return true;
      }
    }
    return false;
  }

  @override
  String? extractKey(AstNode node) {
    if (node is MethodInvocation) {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final firstArg = args.first;

        // Handle direct string
        if (firstArg is SimpleStringLiteral) {
          extractCount++;
          final key = firstArg.value;
          matchedPatterns.add('find.byKey("$key")');
          return key;
        }

        // Handle Key/ValueKey creation
        if (firstArg is InstanceCreationExpression) {
          final innerArgs = firstArg.argumentList.arguments;
          if (innerArgs.isNotEmpty && innerArgs.first is SimpleStringLiteral) {
            extractCount++;
            final key = (innerArgs.first as SimpleStringLiteral).value;
            matchedPatterns.add('find.byKey(Key("$key"))');
            return key;
          }
        }
      }
    }
    return null;
  }

  @override
  bool matchesExpression(Expression expr) => false;

  @override
  String? extractFromExpression(Expression expr) => null;
}

/// Detector for custom key patterns
class CustomPatternDetector extends KeyDetector {
  final String pattern;
  final String extraction;
  final RegExp? regex;

  CustomPatternDetector({
    required super.name,
    required this.pattern,
    required this.extraction,
    Map<String, dynamic>? config,
  })  : regex = RegExp(pattern),
        super(
          description: 'Custom pattern: $pattern',
          priority: 5,
          config: config ?? {},
        );

  @override
  bool matches(AstNode node) {
    final nodeString = node.toString();
    if (regex != null && regex!.hasMatch(nodeString)) {
      matchCount++;
      return true;
    }
    return false;
  }

  @override
  String? extractKey(AstNode node) {
    final nodeString = node.toString();
    if (regex != null) {
      final match = regex!.firstMatch(nodeString);
      if (match != null) {
        // Use extraction pattern to get key
        if (extraction == 'group1' && match.groupCount >= 1) {
          extractCount++;
          final key = match.group(1);
          matchedPatterns.add(key ?? '');
          return key;
        }
      }
    }
    return null;
  }

  @override
  bool matchesExpression(Expression expr) => matches(expr);

  @override
  String? extractFromExpression(Expression expr) => extractKey(expr);
}

/// Detector for Semantics labels (accessibility)
class SemanticsDetector extends KeyDetector {
  SemanticsDetector({Map<String, dynamic>? config})
      : super(
          name: 'Semantics',
          description: 'Detects Semantics labels for accessibility',
          priority: 7,
          config: config ?? {},
        );

  @override
  bool matches(AstNode node) {
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.toString();
      if (typeName == 'Semantics' || typeName.endsWith('.Semantics')) {
        // Check for label parameter
        final hasLabel = node.argumentList.arguments
            .whereType<NamedExpression>()
            .any((arg) => arg.name.label.name == 'label');
        if (hasLabel) {
          matchCount++;
          return true;
        }
      }
    }
    return false;
  }

  @override
  String? extractKey(AstNode node) {
    if (node is InstanceCreationExpression) {
      final labelArg =
          node.argumentList.arguments.whereType<NamedExpression>().firstWhere(
                (arg) => arg.name.label.name == 'label',
                orElse: () => null as NamedExpression,
              );

      if (labelArg.expression is SimpleStringLiteral) {
        extractCount++;
        final label = (labelArg.expression as SimpleStringLiteral).value;
        matchedPatterns.add('Semantics(label: "$label")');
        return 'semantics:$label';
      }
    }
    return null;
  }

  @override
  bool matchesExpression(Expression expr) => false;

  @override
  String? extractFromExpression(Expression expr) => null;
}

/// Factory for creating detectors from configuration
class DetectorFactory {
  static List<KeyDetector> createFromConfig(YamlMap? config) {
    final detectors = <KeyDetector>[];

    // Always include built-in detectors
    detectors.add(ValueKeyDetector());
    detectors.add(BasicKeyDetector());
    detectors.add(FindByKeyDetector());
    detectors.add(SemanticsDetector());

    // Add custom detectors from config
    if (config != null && config['custom_detectors'] != null) {
      final customList = config['custom_detectors'] as YamlList;
      for (final custom in customList) {
        if (custom is YamlMap) {
          detectors.add(CustomPatternDetector(
            name: custom['name'] as String,
            pattern: custom['pattern'] as String,
            extraction: custom['extraction'] as String? ?? 'group1',
            config: custom['config'] as Map<String, dynamic>? ?? {},
          ));
        }
      }
    }

    // Sort by priority
    detectors.sort((a, b) => b.priority.compareTo(a.priority));

    return detectors;
  }

  /// Create detectors for specific testing frameworks
  static List<KeyDetector> createTestDetectors() {
    return [
      FindByKeyDetector(),
      CustomPatternDetector(
        name: 'PatrolFinder',
        pattern: r'''\$\((["'])(.*?)\1\)''',
        extraction: 'group2',
      ),
      CustomPatternDetector(
        name: 'IntegrationTestKey',
        pattern: r'''key:\s*["']([^"']+)["']''',
        extraction: 'group1',
      ),
    ];
  }

  /// Create detectors for specific UI frameworks
  static List<KeyDetector> createFrameworkDetectors(String framework) {
    switch (framework) {
      case 'material':
        return [
          CustomPatternDetector(
            name: 'MaterialKey',
            pattern: r'''key:\s*MaterialKey\(["']([^"']+)["']\)''',
            extraction: 'group1',
          ),
        ];
      case 'cupertino':
        return [
          CustomPatternDetector(
            name: 'CupertinoKey',
            pattern: r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''',
            extraction: 'group1',
          ),
        ];
      default:
        return [];
    }
  }
}
