# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

### 🎉 Initial Release

#### ✨ Features

- **Key Validation Engine**: Comprehensive Flutter key detection and validation
  - Support for `ValueKey` and `Key` declarations
  - Support for `find.byValueKey`, `find.bySemanticsLabel`, `find.byTooltip` finders
  - Regex-based pattern matching for accurate key detection

- **Project Dependency Validation**
  - Automatic detection of `integration_test` dependency
  - Automatic detection of `appium_flutter_server` dependency
  - Validation of proper integration test setup

- **CLI Interface**
  - `--keys` flag for specifying YAML key definitions
  - `--path` flag for custom project paths
  - `--strict` mode for catching extra keys
  - `--verbose` flag for detailed output

- **YAML Configuration Support**
  - Simple key list format
  - Support for dynamic keys with placeholders
  - Comments and organization support

- **Beautiful Console Output**
  - Colorful ANSI output with emojis
  - Structured sections for different validation types
  - Clear success/failure indicators
  - File path reporting for found keys

#### 🛠️ Technical Features

- Cross-platform compatibility (Windows, macOS, Linux)
- Recursive directory scanning
- Efficient regex-based key detection
- Comprehensive error handling
- Unit test coverage

#### 📦 Package Structure

- Clean library API with `KeyChecker` class
- Separated CLI and core functionality
- Example project with integration tests
- Comprehensive documentation

#### 🧪 Testing & Quality

- Unit tests for core functionality
- Integration test examples
- Linting with `package:lints`
- Code coverage reporting

### 🚀 Getting Started

```bash
dart pub global activate flutter_keycheck
flutter_keycheck --keys expected_keys.yaml
```

### 📋 Requirements

- Dart SDK >= 3.2.0
- Flutter project with integration tests (for full validation)

---

## Future Roadmap

### 🔮 Planned Features (v1.1.0+)

- [ ] Auto-generation of `expected_keys.yaml` from existing code
- [ ] Support for additional finder methods (`find.text`, `find.byIcon`)
- [ ] HTML/Markdown report generation
- [ ] Monorepo support with multiple `pubspec.yaml` files
- [ ] Auto-fix capabilities for missing keys
- [ ] Plugin architecture for custom checkers
- [ ] Integration with popular CI/CD platforms

### 💡 Ideas Under Consideration

- JSON configuration format support
- Key usage analytics and statistics
- Integration with Flutter Inspector
- VS Code extension for real-time validation
- GitHub App for automated PR checks

---

*For the complete list of changes, see the [commit history](https://github.com/1nk1/flutter_keycheck/commits/main).*
