# Flutter KeyCheck Architecture Documentation

## 🏗️ System Architecture

Flutter KeyCheck is designed as a modular, extensible CLI tool for analyzing Flutter widget keys in any Flutter project structure.

### Core Components

```
flutter_keycheck/
├── bin/
│   └── flutter_keycheck.dart          # CLI entry point
├── lib/
│   ├── src/
│   │   ├── analyzer/                  # AST analysis layer
│   │   │   ├── analyzer_compatibility.dart  # Analyzer 5.x-8.x compatibility
│   │   │   └── extensible_ast_analyzer.dart # Plugin-based analyzer
│   │   ├── cache/                     # Smart caching system
│   │   │   └── cache_manager.dart     # Cache management
│   │   ├── commands/                  # CLI commands
│   │   │   ├── base_command_v3.dart   # Base command class
│   │   │   ├── scan_command_v3.dart   # Scan implementation
│   │   │   └── validate_command_v3.dart # Validation
│   │   ├── models/                    # Data models
│   │   │   ├── scan_result.dart       # Scan results
│   │   │   └── validation_result.dart # Validation results
│   │   ├── reporter/                  # Report generation
│   │   │   ├── reporter_v3.dart       # Base reporter
│   │   │   ├── universal_premium_reporter.dart # Universal reporter
│   │   │   └── premium_dashboard_adapter.dart  # Adapter pattern
│   │   └── scanner/                   # Key detection
│   │       └── ast_scanner.dart       # AST-based scanner
│   └── flutter_keycheck.dart          # Public API
└── test/                              # Tests
```

## 🎯 Design Principles

### 1. **Universal Compatibility**
- Works with ANY Flutter project structure (app, package, monorepo)
- No hardcoded paths or project assumptions
- Automatic project type detection

### 2. **Analyzer Version Independence**
- Compatibility layer for analyzer 5.x through 8.x
- Version-agnostic AST traversal
- Graceful fallbacks for API changes

### 3. **Extensibility**
- Plugin architecture for custom analyzers
- Hook system for CI/CD integration
- Configurable ignore patterns

### 4. **Performance**
- Smart caching with dependency awareness
- Parallel file analysis
- Incremental scanning support

## 🔌 Extension Points

### 1. Custom AST Analyzer Plugins

```dart
class MyCustomPlugin extends AstAnalyzerPlugin {
  @override
  Finding? analyzeInstanceCreation(InstanceCreationExpression node, String filePath) {
    // Custom analysis logic
    if (isCustomPattern(node)) {
      return Finding(
        type: FindingType.custom,
        severity: Severity.warning,
        message: 'Custom pattern detected',
        filePath: filePath,
        line: getLineNumber(node),
      );
    }
    return null;
  }
  
  @override
  Map<String, dynamic> getMetrics() {
    return {'customMetric': value};
  }
}

// Register plugin
final analyzer = ExtensibleAstAnalyzer();
analyzer.registerPlugin(MyCustomPlugin());
```

### 2. Custom Reporters

```dart
class MyReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile,
  ) async {
    // Custom report generation
  }
}
```

### 3. Configuration Hooks

```yaml
# .flutter_keycheck.yaml
ignore_patterns:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/generated/**"

cache:
  enabled: true
  ttl: 3600

plugins:
  - custom_analyzer
  - security_checker

report:
  format: premium
  include_metrics: true
  include_locations: true
```

## 🚀 CI/CD Integration

### GitHub Actions

```yaml
name: Flutter Key Check

on: [push, pull_request]

jobs:
  key-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      
      - name: Install Flutter KeyCheck
        run: dart pub global activate flutter_keycheck
        
      - name: Run Key Analysis
        run: |
          flutter_keycheck scan \
            --project-root . \
            --report json \
            --out-dir reports
            
      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: key-report
          path: reports/
```

### GitLab CI

```yaml
flutter_key_check:
  stage: test
  script:
    - dart pub global activate flutter_keycheck
    - flutter_keycheck scan --report gitlab --out-dir reports
  artifacts:
    reports:
      junit: reports/key-snapshot.xml
    paths:
      - reports/
```

## 📊 Feature Detection

### Automatic Project Structure Detection

The analyzer automatically detects:
- **App Projects**: Contains lib/ and potentially test/
- **Package Projects**: Contains lib/, test/, and example/
- **Monorepo**: Contains packages/ or apps/ directories
- **Custom Structures**: Adapts to non-standard layouts

### Key Pattern Detection

Supports multiple key patterns:
- `Key('string')`
- `ValueKey('string')`
- `GlobalKey()`
- `ObjectKey(object)`
- `UniqueKey()`
- `const Key('string')`
- `KeyConstants.keyName`
- Dynamic key generation

## 🔧 Configuration

### Environment Variables

```bash
# Disable caching
FLUTTER_KEYCHECK_NO_CACHE=1

# Custom config path
FLUTTER_KEYCHECK_CONFIG=path/to/config.yaml

# Parallel processing threads
FLUTTER_KEYCHECK_THREADS=4
```

### Programmatic Configuration

```dart
import 'package:flutter_keycheck/flutter_keycheck.dart';

final analyzer = ExtensibleAstAnalyzer(
  ignorePatterns: {
    '**/*.g.dart',
    '**/generated/**',
  },
  parallel: true,
);

// Add custom plugins
analyzer.registerPlugin(SecurityKeyPlugin());
analyzer.registerPlugin(AccessibilityKeyPlugin());

// Analyze project
final result = await analyzer.analyzeProject('/path/to/project');
```

## 🎨 Report Formats

### Supported Formats
- **JSON**: Machine-readable format for CI/CD
- **HTML**: Interactive dashboard with charts
- **Premium**: Advanced HTML with glassmorphic UI
- **Markdown**: Documentation-friendly format
- **JUnit XML**: Test result format
- **GitLab**: GitLab-specific format
- **Text**: Human-readable console output
- **CI**: Optimized for CI environments

### Report Customization

```dart
final reporter = UniversalPremiumReporter(
  enableCache: true,
  ignorePatterns: customPatterns,
  customConfig: {
    'theme': 'dark',
    'includeCharts': true,
    'exportFormats': ['json', 'csv', 'markdown'],
  },
);
```

## 📈 Performance Optimization

### Caching Strategy
- File-level caching with content hashing
- Dependency-aware cache invalidation
- TTL-based expiration
- Memory and disk cache tiers

### Parallel Processing
- Concurrent file analysis
- Thread pool management
- Work stealing for load balancing
- Memory-efficient streaming

## 🔒 Security Considerations

### Input Validation
- Path traversal prevention
- Injection attack protection
- Resource limit enforcement

### Output Sanitization
- HTML escaping in reports
- JSON encoding safety
- File system permission checks

## 🧪 Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Pattern matching accuracy
- Cache behavior

### Integration Tests
- Multiple project structures
- Analyzer version compatibility
- Report generation

### E2E Tests
- Full CLI workflow
- CI/CD integration
- Performance benchmarks

## 📚 API Documentation

### Public API

```dart
// Main analyzer
class ExtensibleAstAnalyzer {
  void registerPlugin(AstAnalyzerPlugin plugin);
  Future<AnalysisResult> analyzeProject(String path);
}

// Plugin interface
abstract class AstAnalyzerPlugin {
  void beforeAnalysis(CompilationUnit unit, String filePath);
  List<Finding> afterAnalysis(CompilationUnit unit, String filePath);
  Finding? analyzeInstanceCreation(InstanceCreationExpression node, String filePath);
  Map<String, dynamic> getMetrics();
}

// Reporter interface
abstract class ReporterV3 {
  Future<void> generateScanReport(ScanResult result, File outputFile);
  Future<void> generateValidationReport(ValidationResult result, File outputFile);
}
```

## 🚦 Architectural Decisions

### ADR-001: Plugin Architecture
**Decision**: Use plugin architecture for extensibility
**Rationale**: Allows custom analyzers without modifying core
**Consequences**: Slight performance overhead, better maintainability

### ADR-002: Analyzer Compatibility Layer
**Decision**: Create abstraction layer for analyzer versions
**Rationale**: Support multiple Dart/Flutter versions
**Consequences**: Additional complexity, broader compatibility

### ADR-003: Universal Reporter
**Decision**: Single reporter works with any project structure
**Rationale**: Eliminate project-specific assumptions
**Consequences**: More complex detection logic, better UX

## 🎯 Future Roadmap

### v4.0 Features
- [ ] LSP integration for IDE support
- [ ] Real-time key validation
- [ ] Machine learning for key pattern suggestions
- [ ] Cloud-based report storage
- [ ] Team collaboration features

### v5.0 Vision
- [ ] Multi-language support (Swift, Kotlin)
- [ ] Cross-platform key analysis
- [ ] AI-powered key generation
- [ ] Automated key migration tools

## 📞 Support

- **Issues**: https://github.com/yourusername/flutter_keycheck/issues
- **Discussions**: https://github.com/yourusername/flutter_keycheck/discussions
- **Documentation**: https://flutter-keycheck.dev/docs