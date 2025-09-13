import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_keycheck/src/semantics/semantics_analyzer.dart';

/// Base class for semantic pattern detectors
abstract class SemanticsDetector {
  /// Check if this detector applies to the given widget type
  bool isApplicable(String widgetType);

  /// Check if the widget type is interactive (requires user accessibility)
  bool isInteractive(String widgetType);

  /// Analyze semantic properties of a widget node
  Map<String, dynamic> analyze(AstNode node, String widgetType);

  /// Check for semantic violations in the widget
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue);

  /// Get suggestions for improving semantics
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis);
}

/// Detector for button widgets
class ButtonSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType.contains('Button') ||
           widgetType == 'IconButton' ||
           widgetType == 'GestureDetector' ||
           widgetType == 'InkWell';
  }

  @override
  bool isInteractive(String widgetType) => true;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;
    bool hasAccessibilityHint = false;
    String? semanticLabel;
    String? tooltip;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'accessibilityLabel':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              semanticLabel = _extractStringValue(arg.expression);
              break;
            case 'tooltip':
              hasAccessibilityHint = true;
              hasSemantics = true;
              tooltip = _extractStringValue(arg.expression);
              break;
            case 'semantics':
              hasSemantics = true;
              break;
          }
        }
      }
    } else if (node is MethodInvocation) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'accessibilityLabel':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              break;
            case 'tooltip':
              hasAccessibilityHint = true;
              hasSemantics = true;
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': hasAccessibilityHint,
      'hasAccessibilityValue': false,
      'semanticLabel': semanticLabel,
      'tooltip': tooltip,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    final analysis = analyze(node, widgetType);

    if (!analysis['hasAccessibilityLabel']) {
      violations.add(SemanticViolation(
        type: ViolationType.missingLabel,
        severity: 'warning',
        message: '$widgetType missing accessibility label',
        suggestion: 'Add semanticLabel or tooltip parameter to describe the button action',
      ));
    }

    if (keyValue == null) {
      violations.add(SemanticViolation(
        type: ViolationType.interactiveWithoutKey,
        severity: 'warning',
        message: 'Interactive $widgetType without key makes testing difficult',
        suggestion: 'Add a unique key: Key(\'$widgetType-action-name\')',
      ));
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    
    if (!analysis['hasAccessibilityLabel']) {
      suggestions.add('Add semanticLabel: \'Descriptive button text\'');
      suggestions.add('Add tooltip: \'What happens when pressed\'');
    }
    
    return suggestions;
  }

  String? _extractStringValue(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }
}

/// Detector for text field widgets
class TextFieldSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType.contains('TextField') ||
           widgetType.contains('TextFormField') ||
           widgetType.contains('Input');
  }

  @override
  bool isInteractive(String widgetType) => true;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;
    bool hasAccessibilityHint = false;
    String? hintText;
    String? labelText;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'accessibilityLabel':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              break;
            case 'hintText':
              hasAccessibilityHint = true;
              hasSemantics = true;
              hintText = _extractStringValue(arg.expression);
              break;
            case 'labelText':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              labelText = _extractStringValue(arg.expression);
              break;
            case 'decoration':
              // Check InputDecoration properties
              if (arg.expression is InstanceCreationExpression) {
                final decoration = arg.expression as InstanceCreationExpression;
                for (final decorationArg in decoration.argumentList.arguments) {
                  if (decorationArg is NamedExpression) {
                    final decorationName = decorationArg.name.label.name;
                    if (decorationName == 'labelText' || decorationName == 'hintText') {
                      hasAccessibilityLabel = true;
                      hasSemantics = true;
                    }
                  }
                }
              }
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': hasAccessibilityHint,
      'hasAccessibilityValue': false,
      'hintText': hintText,
      'labelText': labelText,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    final analysis = analyze(node, widgetType);

    if (!analysis['hasAccessibilityLabel']) {
      violations.add(SemanticViolation(
        type: ViolationType.missingLabel,
        severity: 'error',
        message: '$widgetType missing label for screen readers',
        suggestion: 'Add labelText in InputDecoration or semanticLabel parameter',
      ));
    }

    if (!analysis['hasAccessibilityHint']) {
      violations.add(SemanticViolation(
        type: ViolationType.missingHint,
        severity: 'warning',
        message: '$widgetType missing input format hint',
        suggestion: 'Add hintText in InputDecoration to guide user input',
      ));
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    
    if (!analysis['hasAccessibilityLabel']) {
      suggestions.add('Add decoration: InputDecoration(labelText: \'Field Purpose\')');
    }
    
    if (!analysis['hasAccessibilityHint']) {
      suggestions.add('Add decoration: InputDecoration(hintText: \'Expected format\')');
    }
    
    return suggestions;
  }

  String? _extractStringValue(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }
}

/// Detector for image widgets
class ImageSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType == 'Image' ||
           widgetType == 'NetworkImage' ||
           widgetType == 'AssetImage' ||
           widgetType == 'Icon';
  }

  @override
  bool isInteractive(String widgetType) => false;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;
    String? semanticLabel;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              semanticLabel = _extractStringValue(arg.expression);
              break;
            case 'excludeFromSemantics':
              // If explicitly excluded, don't require semantics
              if (arg.expression is BooleanLiteral) {
                final excluded = (arg.expression as BooleanLiteral).value;
                if (excluded) {
                  hasSemantics = true; // Consider as handled
                }
              }
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': false,
      'semanticLabel': semanticLabel,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    final analysis = analyze(node, widgetType);

    if (!analysis['hasAccessibilityLabel'] && widgetType == 'Image') {
      violations.add(SemanticViolation(
        type: ViolationType.missingLabel,
        severity: 'warning',
        message: 'Image without semantic label is inaccessible to screen readers',
        suggestion: 'Add semanticLabel: \'Description of image content\'',
      ));
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    
    if (!analysis['hasAccessibilityLabel']) {
      suggestions.add('Add semanticLabel: \'Describe the image content\'');
      suggestions.add('Or add excludeFromSemantics: true if decorative');
    }
    
    return suggestions;
  }

  String? _extractStringValue(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }
}

/// Detector for list widgets
class ListSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType.contains('List') ||
           widgetType.contains('Grid') ||
           widgetType == 'ListView' ||
           widgetType == 'GridView' ||
           widgetType == 'ListTile';
  }

  @override
  bool isInteractive(String widgetType) {
    return widgetType == 'ListTile';
  }

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'title':
            case 'subtitle':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': false,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    
    if (widgetType == 'ListTile') {
      final analysis = analyze(node, widgetType);
      if (!analysis['hasAccessibilityLabel']) {
        violations.add(SemanticViolation(
          type: ViolationType.missingLabel,
          severity: 'warning',
          message: 'ListTile without title makes navigation difficult',
          suggestion: 'Add title: Text(\'Item description\')',
        ));
      }
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    
    if (widgetType == 'ListTile' && !analysis['hasAccessibilityLabel']) {
      suggestions.add('Add title: Text(\'Descriptive item title\')');
    }
    
    return suggestions;
  }
}

/// Detector for general interactive widgets
class InteractiveSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType == 'GestureDetector' ||
           widgetType == 'InkWell' ||
           widgetType == 'InkResponse' ||
           widgetType == 'Dismissible';
  }

  @override
  bool isInteractive(String widgetType) => true;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;

    // These widgets don't have built-in semantic properties,
    // so we need to check for wrapped Semantics widget
    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': false,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];

    violations.add(SemanticViolation(
      type: ViolationType.missingSemantics,
      severity: 'warning',
      message: '$widgetType needs semantic wrapper for accessibility',
      suggestion: 'Wrap with Semantics(label: \'Action description\', child: ...)',
    ));

    if (keyValue == null) {
      violations.add(SemanticViolation(
        type: ViolationType.interactiveWithoutKey,
        severity: 'warning',
        message: 'Interactive $widgetType without key makes testing difficult',
        suggestion: 'Add key: Key(\'$widgetType-action\')',
      ));
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    return [
      'Wrap with Semantics widget to provide accessibility information',
      'Add key for automated testing identification',
    ];
  }
}

/// Detector for form widgets
class FormSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType == 'Form' ||
           widgetType == 'Checkbox' ||
           widgetType == 'Radio' ||
           widgetType == 'Switch' ||
           widgetType == 'Slider' ||
           widgetType == 'DropdownButton';
  }

  @override
  bool isInteractive(String widgetType) => widgetType != 'Form';

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;
    bool hasAccessibilityValue = false;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'label':
            case 'title':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              break;
            case 'value':
              hasAccessibilityValue = true;
              hasSemantics = true;
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': hasAccessibilityValue,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    
    if (widgetType != 'Form') {
      final analysis = analyze(node, widgetType);
      
      if (!analysis['hasAccessibilityLabel']) {
        violations.add(SemanticViolation(
          type: ViolationType.missingLabel,
          severity: 'error',
          message: '$widgetType missing label for accessibility',
          suggestion: 'Add title or semanticLabel parameter',
        ));
      }
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    
    if (!analysis['hasAccessibilityLabel']) {
      suggestions.add('Add title or semanticLabel to describe the form element');
    }
    
    return suggestions;
  }
}

/// Detector for navigation widgets
class NavigationSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType == 'BottomNavigationBar' ||
           widgetType == 'NavigationRail' ||
           widgetType == 'TabBar' ||
           widgetType == 'Drawer' ||
           widgetType == 'AppBar';
  }

  @override
  bool isInteractive(String widgetType) => true;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    bool hasSemantics = false;
    bool hasAccessibilityLabel = false;

    if (node is InstanceCreationExpression) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          switch (name) {
            case 'semanticLabel':
            case 'title':
            case 'tooltip':
              hasAccessibilityLabel = true;
              hasSemantics = true;
              break;
          }
        }
      }
    }

    return {
      'hasSemantics': hasSemantics,
      'hasAccessibilityLabel': hasAccessibilityLabel,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': false,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];
    final analysis = analyze(node, widgetType);

    if (!analysis['hasAccessibilityLabel']) {
      violations.add(SemanticViolation(
        type: ViolationType.missingLabel,
        severity: 'info',
        message: '$widgetType could benefit from semantic labeling',
        suggestion: 'Add semanticLabel for better screen reader experience',
      ));
    }

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    return [
      'Consider adding semanticLabel for navigation context',
    ];
  }
}

/// Detector for media widgets
class MediaSemanticsDetector extends SemanticsDetector {
  @override
  bool isApplicable(String widgetType) {
    return widgetType == 'Video' ||
           widgetType == 'Audio' ||
           widgetType == 'Player';
  }

  @override
  bool isInteractive(String widgetType) => true;

  @override
  Map<String, dynamic> analyze(AstNode node, String widgetType) {
    // Media widgets typically need custom accessibility handling
    return {
      'hasSemantics': false,
      'hasAccessibilityLabel': false,
      'hasAccessibilityHint': false,
      'hasAccessibilityValue': false,
    };
  }

  @override
  List<SemanticViolation> checkViolations(AstNode node, String widgetType, String? keyValue) {
    final violations = <SemanticViolation>[];

    violations.add(SemanticViolation(
      type: ViolationType.missingSemantics,
      severity: 'info',
      message: '$widgetType requires custom accessibility implementation',
      suggestion: 'Wrap with Semantics and provide media controls descriptions',
    ));

    return violations;
  }

  @override
  List<String> getSuggestions(String widgetType, Map<String, dynamic> analysis) {
    return [
      'Implement custom media accessibility with Semantics wrapper',
      'Provide controls labeling for play/pause/seek actions',
    ];
  }
}