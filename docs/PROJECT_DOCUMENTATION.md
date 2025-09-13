# Flutter KeyCheck - Complete Project Documentation

## Project Overview

**Flutter KeyCheck** is an enterprise-grade static analysis tool for Flutter applications that validates widget keys for QA automation. It provides comprehensive scanning, validation, and reporting capabilities with premium HTML reports and CI/CD integration.

### Key Features
- 🔍 AST-based key detection (accurate parsing)
- 📊 Premium glassmorphism HTML reports
- 🎯 CI/CD integration with deterministic exit codes
- ⚡ 60% faster than v2
- 📦 Multiple output formats (HTML, JSON, Markdown, JUnit)
- 🔧 Configurable validation rules

## Installation & Setup

### Requirements
- Dart SDK: >=3.2.0 <4.0.0
- Flutter: Any version (for projects being scanned)
- Platform: Linux, macOS, Windows

### Installation Options

#### Global Installation
```bash
dart pub global activate flutter_keycheck
```

#### Project Dependency
```yaml
dev_dependencies:
  flutter_keycheck: ^3.2.0
```

### Basic Usage
```bash
# Scan project
flutter_keycheck scan --scope workspace-only --report html

# Validate against baseline
flutter_keycheck validate --baseline keys.yaml --strict

# Compare scan results
flutter_keycheck diff --baseline old.json --current new.json

# Generate standalone reports
flutter_keycheck report --input results.json --format html

# Synchronize team configurations
flutter_keycheck sync --source master.yaml --target local.yaml

# Fix duplicate keys
flutter_keycheck fix --key "duplicate_key" --strategy interactive

# Auto-fix common issues
flutter_keycheck fix --scope workspace-only --dry-run
```

For detailed CLI documentation, see [CLI Reference Guide](CLI_REFERENCE.md).

## Architecture Overview

### System Layers

```
┌─────────────────────────────────────┐
│         CLI Interface               │
│  (Commands, Arguments, Options)     │
├─────────────────────────────────────┤
│         Core Engine                 │
│  (AST Scanner, Key Detectors)       │
├─────────────────────────────────────┤
│         Data Layer                  │
│  (Models, Registry, Cache)          │
├─────────────────────────────────────┤
│         Output Layer                │
│  (Reporters, Formatters)            │
└─────────────────────────────────────┘
```

### Component Responsibilities

| Component | Purpose | Status |
|-----------|---------|--------|
| CLI Runner | Command orchestration | Stable |
| AST Scanner | Parse Dart files for keys | Stable (v3) |
| Key Detectors | Pattern matching | Stable |
| Cache Manager | Performance optimization | Stable |
| Reporters | Output generation | Stable (8 formats) |
| Registry | Key storage | Stable |
| Semantic Analyzer | Accessibility analysis | Stable |

## Configuration

### Configuration File (.flutter_keycheck.yaml)
```yaml
version: 1
validate:
  thresholds:
    min_coverage: 0.8
    max_drift: 10
    parse_success: 0.95
  protected_tags:
    - critical
    - aqa
  fail_on_lost: true

scan:
  packages: workspace
  include_tests: false
  cache: true
```

### Command Structure

Flutter KeyCheck v3 uses a subcommand architecture with six core commands:

| Command | Purpose | Example |
|---------|---------|---------|
| `scan` | Analyze project for keys | `flutter_keycheck scan --scope workspace-only` |
| `validate` | Check against baselines | `flutter_keycheck validate --strict` |
| `diff` | Compare scan results | `flutter_keycheck diff --baseline old.json --current new.json` |
| `report` | Generate standalone reports | `flutter_keycheck report --input data.json --format html` |
| `sync` | Synchronize configurations | `flutter_keycheck sync --source master.yaml --target local.yaml` |
| `fix` | Auto-repair issues | `flutter_keycheck fix --scope workspace-only --apply` |

### Global Options

| Option | Description | Example |
|--------|-------------|---------|
| --version, -V | Show version information | `flutter_keycheck --version` |
| --verbose, -v | Detailed output | `flutter_keycheck scan --verbose` |
| --config, -c | Config file path | `flutter_keycheck scan --config custom.yaml` |

For complete CLI documentation, see [CLI Reference Guide](CLI_REFERENCE.md).

## Key Detection Patterns

### Supported Patterns
```dart
// Traditional
Key('key_name')
ValueKey('value_key')

// Modern KeyConstants
Key(KeyConstants.loginButton)
ValueKey(KeyConstants.emailField)

// Dynamic methods
KeyConstants.userKey(userId)

// Test finders
find.byKey(Key('test_key'))
find.byValueKey('value_key')
```

## Reporting Capabilities

### Available Formats

| Format | Use Case | Features |
|--------|----------|----------|
| HTML | Visual reports | Glassmorphism UI, charts, interactive |
| JSON | API integration | Structured data, machine-readable |
| Markdown | Documentation | Tables, readable, version control |
| CI | Terminal output | ANSI colors, progress bars |
| JUnit | CI/CD integration | Test report format |

### Report Contents
- Coverage metrics
- Found/missing keys
- File-level analysis
- Duplicate detection
- Quality scoring
- Performance metrics

## CI/CD Integration

### GitHub Actions
```yaml
- name: Flutter KeyCheck
  run: |
    dart pub global activate flutter_keycheck
    flutter_keycheck scan --report junit --out-dir reports
    flutter_keycheck validate --strict
```

### GitLab CI
```yaml
keycheck:
  script:
    - flutter_keycheck scan --report ci
    - flutter_keycheck validate --fail-on-lost
  artifacts:
    reports:
      junit: reports/*.xml
```

### Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Policy violation |
| 2 | Configuration error |
| 3 | I/O error |
| 4 | Internal error |

## Development Guide

### Project Structure
```
flutter_keycheck/
├── bin/              # CLI entry point
├── lib/
│   ├── src/
│   │   ├── cli/      # CLI implementation (CliRunner)
│   │   ├── commands/ # Command handlers (scan, validate, diff, report, sync, fix)
│   │   ├── scanner/  # AST scanning
│   │   ├── reporter/ # Report generation
│   │   ├── cache/    # Caching system
│   │   └── models/   # Data models
│   └── flutter_keycheck.dart  # Public API
├── test/             # Test suites
│   ├── cli_import_test.dart    # CLI structure validation
│   ├── integration/            # Integration tests
│   └── ...                     # Other test files
├── example/          # Example applications
└── docs/             # Documentation
    ├── CLI_REFERENCE.md        # Complete CLI documentation
    └── ...                     # Other documentation
```

### Building from Source
```bash
# Clone repository
git clone https://github.com/1nk1/flutter_keycheck.git
cd flutter_keycheck

# Install dependencies
dart pub get

# Run tests
dart test

# Build executable
dart compile exe bin/flutter_keycheck.dart
```

### Contributing
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Run `dart format` and `dart analyze`
5. Submit pull request

## API Reference

### Core Classes

#### ScanResult
```dart
class ScanResult {
  final Set<String> foundKeys;
  final Map<String, List<Location>> keyLocations;
  final Duration scanDuration;
  final List<String> errors;
}
```

#### ValidationResult
```dart
class ValidationResult {
  final Set<String> missingKeys;
  final Set<String> extraKeys;
  final double coverage;
  final bool passed;
}
```

#### ReporterFactory
```dart
class ReporterFactory {
  static BaseReporter create(String format);
}
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| No keys found | Check Key() usage, verify --scope |
| Test failures | Update dependencies, check analyzer version |
| Slow scanning | Enable caching, reduce scope |
| Report generation fails | Check write permissions, disk space |

### Debug Mode
```bash
# Enable verbose logging
flutter_keycheck scan --verbose

# Check configuration
flutter_keycheck scan --config .flutter_keycheck.yaml --verbose
```

## Migration Guide

### From v2 to v3

#### Breaking Changes
1. **CLI Structure**: Commands now use subcommands
   ```bash
   # v2
   flutter_keycheck --generate-keys

   # v3
   flutter_keycheck scan --report json
   ```

2. **Exit Codes**: Now deterministic (0-4)

3. **Configuration**: New YAML schema
   ```yaml
   # v3 requires version field
   version: 1
   ```

4. **Scope Flag**: New scanning scope
   ```bash
   --scope workspace-only  # Only project files
   --scope deps-only       # Only dependencies
   --scope all            # Everything
   ```

### Upgrade Steps
1. Update dependency to ^3.2.0
2. Update CI/CD scripts for new CLI
3. Migrate configuration files
4. Update exit code handling

## Performance Considerations

### Optimization Tips
- Use `--scope workspace-only` for faster scans
- Enable caching with `cache: true`
- Exclude test files if not needed
- Use specific report formats

### Benchmarks
| Metric | Current | Target |
|--------|---------|--------|
| 1000 files scan | 30s | 20s |
| Memory usage | 500MB | 400MB |
| Cache hit rate | 80% | 85% |

## Support & Resources

### Links
- [GitHub Repository](https://github.com/1nk1/flutter_keycheck)
- [pub.dev Package](https://pub.dev/packages/flutter_keycheck)
- [Issue Tracker](https://github.com/1nk1/flutter_keycheck/issues)

### Getting Help
1. Check documentation
2. Search existing issues
3. Create detailed bug report
4. Include version and environment

## License

MIT License - See LICENSE file for details

---

*Documentation Version: 3.2.0*
*Last Updated: 2024-12-29*
*Generated by: Winston - BMAD Architect*
