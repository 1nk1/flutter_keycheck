# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-03

### 🚀 Major Release - Advanced Configuration & CI Integration

#### 🎉 New Features

- **Custom Configuration Files**: `--config` flag for specifying custom config files
- **Key Generation**: `--generate-keys` flag to auto-generate expected keys from existing project
- **Fail on Extra Keys**: `--fail-on-extra` flag for strict validation in CI environments
- **Report Generation**: `--report json|markdown` for generating structured reports
- **Advanced CI Integration**: Ready-to-use GitHub Actions, GitLab CI, Bitrise, and Jenkins examples

#### ✨ Enhanced Configuration Support

- Added support for `.flutter_keycheck.yaml` configuration files
- New `FlutterKeycheckConfig` class with `fail_on_extra` support
- Beautiful colored output when config file is loaded: `📄 Loaded config from .flutter_keycheck.yaml ✅`
- CLI arguments take priority over config file settings
- Path validation for keys files and source directories

#### 🔧 CI/CD Ready

- Comprehensive GitHub Actions workflows with security scanning
- Performance impact analysis for key count
- Automated key generation and updates
- Pull request reporting with detailed analysis
- Multi-environment support (dev/staging/prod)

#### 📊 Advanced Validation

- Enhanced verbose output with configuration details
- Better error messages with actionable suggestions
- Graceful handling of missing files and invalid configurations
- Support for custom config file paths

#### 🧪 Quality Improvements

- Expanded test suite with 19+ comprehensive test cases
- Documentation for all edge cases and error scenarios
- Real-world CI integration examples
- Best practices guide for key organization

#### 📚 Documentation

- Complete CI integration guide with multiple platforms
- Advanced usage examples and troubleshooting
- Key naming conventions and organizational patterns
- Security considerations for sensitive key detection

## [1.0.7] - 2025-01-03

### ✨ Enhanced Dependency Reporting

- Added detailed dependency status reporting with individual checks
- New `DependencyStatus` class for granular dependency information
- Improved dependency output showing specific status for each dependency
- Enhanced error messages to show exactly which dependencies are missing vs found

🔧 Technical Improvements

- Better user experience with clear dependency status indicators
- Updated tests to work with new dependency status structure
- Cleaned up temporary test files and improved gitignore

🐛 Bug Fixes

- Fixed dependency checking to show individual status instead of generic "missing dependencies"
- Resolved linting version conflicts (upgraded to lints ^4.0.0)

## [1.0.6] - 2025-01-03

### 🔧 Platform Compatibility

- Added explicit documentation about web/WASM incompatibility
- Clarified that this is a CLI tool designed for desktop platforms only
- Improved pub.dev platform support documentation

## [1.0.5] - 2025-01-03

### 🤖 Automation

- Added automated publishing workflow for pub.dev
- Now supports publishing via git tags (e.g., `git tag v1.0.5`)
- Streamlined release process with GitHub Actions

## [1.0.4] - 2025-01-03

### 🔧 Platform Support

- Added explicit platform constraints in pubspec.yaml (Linux, macOS, Windows)
- Clarified that this CLI tool is not compatible with Web/WASM by design (uses dart:io)
- Improved pub.dev platform support scoring

## [1.0.3] - 2025-01-03

📚 Documentation

- Added comprehensive dartdoc comments for better API documentation
- Created example/ directory with sample usage
- Added example Flutter app with ValueKey usage
- Improved pub.dev score compliance

## [1.0.2] - 2025-01-03

### 🐛 Bug Fixes

- Fixed dependency version conflict: downgraded lints from ^5.0.0 to ^3.0.0 for Dart 3.2.0 compatibility
- Fixed GitHub Actions workflow paths and YAML syntax

## [1.0.1] - 2025-01-03

🐛 Bug Fixes

- Fixed release date in changelog from placeholder to actual date

## [1.0.0] - 2025-01-03

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

_For the complete list of changes, see the [commit history](https://github.com/1nk1/flutter_keycheck/commits/main)._
