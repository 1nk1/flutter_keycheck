# Semantic Analysis & Accessibility Guide

Flutter KeyCheck v3 includes comprehensive semantic analysis capabilities to ensure your Flutter applications are both testable and accessible. This guide covers the semantic analyzer features, configuration options, and best practices for creating accessible Flutter apps.

## Overview

The semantic analyzer examines Flutter widgets for accessibility properties and provides detailed feedback on semantic completeness. It works alongside key detection to ensure your UI elements are both testable by automation tools and accessible to users with disabilities.

## Key Features

### Widget Semantic Detection

The analyzer supports comprehensive detection of semantic properties across all major Flutter widget types:

- **Button Widgets** - `ElevatedButton`, `TextButton`, `IconButton`, `FloatingActionButton`
- **Form Elements** - `TextField`, `TextFormField`, `Checkbox`, `Radio`, `Switch`, `Slider`
- **Images & Media** - `Image`, `Icon`, `NetworkImage`, `AssetImage`
- **Lists & Navigation** - `ListTile`, `ListView`, `GridView`, `BottomNavigationBar`
- **Interactive Elements** - `GestureDetector`, `InkWell`, `Dismissible`
- **Custom Widgets** - Any widget with semantic annotations

### Semantic Properties Analysis

For each widget, the analyzer examines:

```dart
// Properties analyzed by the semantic analyzer
Semantics(
  label: 'Submit form',              // ✅ Accessibility label
  hint: 'Submits the current form', // ✅ Usage hint
  value: 'Enabled',                 // ✅ Current state
  button: true,                     // ✅ Semantic role
  enabled: true,                    // ✅ Interaction state
  child: widget,
)
```

### Accessibility Scoring

The analyzer provides comprehensive scoring metrics:

- **Semantic Coverage** - Percentage of widgets with semantic annotations
- **Interactive Label Coverage** - Percentage of interactive elements with labels
- **Quality Score** - Overall accessibility score (0-100)
- **Key-Semantic Coverage** - Widgets with both keys and semantic properties

## Configuration

### Basic Configuration

Add semantic analysis configuration to your `.flutter_keycheck.yaml`:

```yaml
semantic_analysis:
  enabled: true
  strict_mode: false

  # Widget filtering
  exclude_widgets:
    - "Container"
    - "SizedBox"
    - "Padding"

  # Requirements by widget type
  require_hints:
    - "IconButton"
    - "TextField"
    - "TextFormField"

  # Violation severity levels
  violation_severity:
    missing_label: "warning"
    missing_hint: "info"
    missing_semantics: "warning"
    interactive_without_key: "error"
```

### Advanced Configuration

```yaml
semantic_analysis:
  enabled: true
  strict_mode: true  # Require semantics for all interactive widgets

  # Custom detector configuration
  detectors:
    - ButtonSemanticsDetector
    - TextFieldSemanticsDetector
    - ImageSemanticsDetector
    - CustomWidgetDetector

  # Quality gates
  thresholds:
    min_semantic_coverage: 80.0
    min_interactive_coverage: 95.0
    max_violations: 10

  # Reporting options
  include_suggestions: true
  group_by_severity: true
```

## Usage Examples

### Command Line Usage

```bash
# Basic semantic analysis
flutter_keycheck scan --semantic-analysis

# Generate HTML report with semantic analysis
flutter_keycheck scan --report html --semantic-analysis --out-dir reports

# JSON output with semantic metrics
flutter_keycheck scan --report json --semantic-analysis | jq '.semantics_analysis'

# Focus on interactive elements only
flutter_keycheck scan --include-only="*_button,*_field" --semantic-analysis
```

### Programmatic Usage

```dart
import 'package:flutter_keycheck/flutter_keycheck.dart';

// Create semantic analyzer
final analyzer = SemanticsAnalyzer(
  keyUsages: scanResult.keyUsages,
  customDetectors: [
    ButtonSemanticsDetector(),
    TextFieldSemanticsDetector(),
    CustomWidgetDetector(),
  ],
);

// Analyze file
final results = await analyzer.analyzeFile(filePath, compilationUnit);

// Get metrics
final metrics = analyzer.metrics;
print('Semantic coverage: ${metrics.semanticsCoverage}%');
print('Interactive coverage: ${metrics.interactiveLabelCoverage}%');
```

## Violation Types & Solutions

### Missing Semantic Label

**Issue**: Interactive widgets without accessibility labels

```dart
// ❌ Problem
IconButton(
  key: const Key('delete_button'),
  onPressed: _delete,
  icon: const Icon(Icons.delete),
)

// ✅ Solution
Semantics(
  label: 'Delete item',
  hint: 'Removes this item from the list',
  button: true,
  child: IconButton(
    key: const Key('delete_button'),
    onPressed: _delete,
    icon: const Icon(Icons.delete),
  ),
)
```

### Missing Form Hints

**Issue**: Form fields without input guidance

```dart
// ❌ Problem
TextField(
  key: const Key('email_field'),
  decoration: const InputDecoration(labelText: 'Email'),
)

// ✅ Solution
TextField(
  key: const Key('email_field'),
  decoration: const InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email address',
    helperText: 'We\'ll use this for account notifications',
  ),
)
```

### Interactive Without Key

**Issue**: Interactive elements missing keys for testing

```dart
// ❌ Problem
GestureDetector(
  onTap: _handleTap,
  child: Container(child: Text('Tap me')),
)

// ✅ Solution
Semantics(
  label: 'Custom action button',
  button: true,
  child: GestureDetector(
    key: const Key('custom_action_button'),
    onTap: _handleTap,
    child: Container(child: Text('Tap me')),
  ),
)
```

## Report Formats

### HTML Report

The HTML report includes a dedicated semantic analysis section with:

- **Semantic Coverage Dashboard** - Visual metrics and charts
- **Violation Summary** - Grouped by severity with suggestions
- **Widget Analysis Table** - Detailed breakdown by widget type
- **Quality Score** - Overall accessibility assessment

### JSON Report

```json
{
  "semantics_analysis": {
    "totalWidgets": 45,
    "widgetsWithSemantics": 32,
    "interactiveWidgets": 18,
    "interactiveWithLabels": 15,
    "semanticsCoverage": 71.1,
    "interactiveLabelCoverage": 83.3,
    "qualityScore": 77.2,
    "violations": [
      {
        "type": "missingLabel",
        "severity": "warning",
        "count": 3,
        "examples": [
          {
            "file": "lib/screens/home.dart",
            "line": 42,
            "widget": "IconButton",
            "suggestion": "Add semantic label for screen reader users"
          }
        ]
      }
    ]
  }
}
```

### CI/CD Integration

```bash
# CI pipeline example
flutter_keycheck scan --semantic-analysis --report ci
if [ $? -eq 1 ]; then
  echo "Semantic analysis failed - accessibility issues found"
  exit 1
fi
```

## Best Practices

### 1. Comprehensive Widget Semantics

Always provide meaningful semantic information for interactive elements:

```dart
// Good semantic annotation
Semantics(
  label: 'Add item to shopping cart',
  hint: 'Double tap to add this item to your cart',
  value: isInCart ? 'Already in cart' : 'Not in cart',
  button: true,
  enabled: !isLoading,
  child: ElevatedButton(
    key: const Key('add_to_cart_button'),
    onPressed: isLoading ? null : _addToCart,
    child: Text(isLoading ? 'Adding...' : 'Add to Cart'),
  ),
)
```

### 2. Context-Aware Labels

Provide context-specific information in semantic labels:

```dart
// Include item context in semantic label
Semantics(
  label: 'Delete ${item.name}',
  hint: 'This action cannot be undone',
  button: true,
  child: IconButton(
    key: Key('delete_${item.id}'),
    onPressed: () => _deleteItem(item),
    icon: const Icon(Icons.delete),
  ),
)
```

### 3. Form Field Accessibility

Ensure form fields have comprehensive accessibility information:

```dart
// Complete form field semantics
Semantics(
  label: 'Email address',
  hint: 'Required field for account creation',
  textField: true,
  child: TextFormField(
    key: const Key('email_field'),
    decoration: const InputDecoration(
      labelText: 'Email',
      hintText: 'you@example.com',
      helperText: 'We\'ll never share your email',
    ),
    validator: _validateEmail,
  ),
)
```

### 4. Exclude Decorative Elements

Use `ExcludeSemantics` for purely decorative elements:

```dart
// Exclude decorative images from semantic tree
ExcludeSemantics(
  child: Image.asset(
    'assets/decorative_pattern.png',
    key: const Key('decorative_background'),
  ),
)
```

## Integration with Testing

### Combining Keys and Semantics

The semantic analyzer works best when widgets have both keys for testing and semantic properties for accessibility:

```dart
// Ideal widget with both key and semantics
Semantics(
  label: 'Submit login form',
  hint: 'Attempts to log in with the provided credentials',
  button: true,
  child: ElevatedButton(
    key: const Key('login_submit_button'),  // For testing
    onPressed: _handleLogin,
    child: const Text('Login'),
  ),
)
```

### Test Integration

```dart
// Test can use both key and semantic information
testWidgets('login button is accessible', (tester) async {
  await tester.pumpWidget(MyApp());

  // Find by key (for reliable testing)
  final button = find.byKey(const Key('login_submit_button'));
  expect(button, findsOneWidget);

  // Verify semantic properties
  final semantics = tester.getSemantics(button);
  expect(semantics.label, 'Submit login form');
  expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
});
```

## Troubleshooting

### Common Issues

1. **High violation count**: Start with `strict_mode: false` and gradually improve
2. **False positives**: Use `exclude_widgets` to filter out non-interactive elements
3. **Missing custom widgets**: Implement custom detectors for your widget library
4. **Performance impact**: Use incremental scanning with `--since` option

### Debug Mode

Enable verbose logging to understand analyzer behavior:

```bash
flutter_keycheck scan --semantic-analysis --verbose
```

This will show:
- Which detectors are being applied
- Semantic properties found for each widget
- Violation detection logic
- Performance metrics

## Migration Guide

### From Key-Only Analysis

If you're currently using Flutter KeyCheck for key detection only:

1. **Enable semantic analysis** in your configuration
2. **Start with warnings only** to assess current state
3. **Gradually increase requirements** as you improve accessibility
4. **Integrate into CI/CD** once violations are under control

### Incremental Adoption

```yaml
# Phase 1: Assessment only
semantic_analysis:
  enabled: true
  strict_mode: false
  violation_severity:
    missing_label: "info"
    missing_hint: "info"

# Phase 2: Enforce critical violations
semantic_analysis:
  enabled: true
  violation_severity:
    missing_label: "warning"
    interactive_without_key: "error"

# Phase 3: Full enforcement
semantic_analysis:
  enabled: true
  strict_mode: true
  thresholds:
    min_semantic_coverage: 80.0
```

## Related Documentation

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Semantics Research](./SEMANTICS_RESEARCH.md) - Comprehensive technical research
- [Testing Guide](./TEST_SUITE_DOCUMENTATION.md) - Integration testing patterns
- [CI/CD Integration](./CI_CD_INTEGRATION_SUMMARY.md) - Pipeline setup examples

## Support

For questions about semantic analysis:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review the [semantics research document](./SEMANTICS_RESEARCH.md)
3. Open an issue on GitHub with semantic analysis logs
4. Join the Flutter accessibility community discussions
