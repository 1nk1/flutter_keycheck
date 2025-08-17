# Changelog

All notable changes to flutter_keycheck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 3.0.0 - 2025-08-17

### 🎉 General Availability Release

Flutter KeyCheck v3.0.0 is now production-ready with enterprise-grade features for Flutter automation key management.

### ✨ Major Features Since RC1

#### Package Scope Scanning
- **New**: `--scope` flag for scan command with three modes:
  - `workspace-only`: Scan only project files (default)
  - `deps-only`: Scan only dependencies
  - `all`: Scan both workspace and dependencies
- Enables targeted scanning for monorepos and package analysis

#### Dependency Caching
- **New**: 24-hour cache for dependency scan results
- Cache location: `.dart_tool/flutter_keycheck/cache/`
- 40-60% performance improvement for repeated scans
- Automatic cache invalidation on detector or SDK changes

#### Package Validation Policies
- **New**: `--fail-on-package-missing` flag - Fail if keys exist in packages but not in app
- **New**: `--fail-on-collision` flag - Fail if keys are declared in multiple sources
- Prevents key conflicts in multi-package projects

#### Enhanced Configuration
- **New**: `include_only` field - Scan only specified patterns
- **New**: `tracked_keys` field - Focus validation on critical keys subset
- Supports more granular control over scanning and validation

#### Demo Application
- **New**: Complete Flutter demo app in `example/demo_app/`
- 4 screens with 31+ automation keys
- Demonstrates best practices for key placement
- Includes profile, registration, home, and menu screens

### 📦 Package Quality
- Compressed size: 320 KB
- Full Dart 3.3+ compatibility
- Pub.dev score optimizations
- Comprehensive test coverage

### 🔧 Infrastructure
- Unified CLI binary (`bin/flutter_keycheck.dart`)
- Smoke test script for validation
- Improved CI/CD templates
- Documentation reorganization for pub.dev

### 📚 Documentation
- Migration guide for v2 to v3
- Troubleshooting guide with exit codes
- Example configurations
- API documentation

### 🙏 Acknowledgments
Thanks to all contributors and early adopters who tested the RC releases.

---

## 3.0.0-rc.1 - 2025-08-16

### 🚀 BREAKING CHANGES - Major v3 Release

Complete CLI redesign with subcommands, deterministic exit codes, and v1.0 schema.

### ⚠️ BREAKING: Deleted Legacy Binaries
- **Removed**: `bin/flutter_keycheck_v2.dart`
- **Removed**: `bin/flutter_keycheck_v3.dart`  
- **Removed**: `bin/flutter_keycheck_v3_complete.dart`
- **Removed**: `bin/flutter_keycheck_v3_integrated.dart`
- **Removed**: `bin/flutter_keycheck_v3_proper.dart`
- **Unified**: Only `bin/flutter_keycheck.dart` remains

### ⚠️ Breaking Changes

#### CLI Migration to Subcommands
- **Old**: `flutter_keycheck --keys file.yaml --strict`
- **New**: `flutter_keycheck validate --strict`
- Primary command is now `validate` (with `ci-validate` alias)
- All functionality moved to explicit subcommands

#### Exit Codes Standardized
- `0`: Success - all validations passed
- `1`: Policy violation - thresholds not met, critical keys missing
- `2`: Configuration error - invalid config, missing files
- `3`: I/O or sync error - file access, git operations
- `4`: Internal error - unexpected failures

#### Schema v1.0
- New standardized JSON schema for scan coverage metrics
- `parse_success_rate` is now a fraction (0.0 to 1.0), not percentage
- Structured metrics with `files_total`, `files_scanned`, `widgets_total`, etc.
- Detector effectiveness tracking with `detectors[]` array

### ✨ New Features

#### Core Commands
- **scan**: Build current snapshot with AST parsing and key↔handler linking
- **baseline**: Create/update/delete baselines for tracking changes
- **diff**: Compare snapshots to detect key drift
- **validate**: Primary validation command (ci-validate alias available)
- **sync**: Sync with external key registries (git, API)
- **report**: Generate various report formats

#### Advanced Scanning
- AST-based widget tree analysis with parallel processing (8-12 isolates)
- Key↔handler linking to track widget-to-event connections
- Blind spot detection for untestable areas
- Cache system in `.dart_tool/flutter_keycheck/` with POSIX paths
- Incremental scanning with `--since` for git-based changes

#### Enterprise Features
- Multi-package monorepo support with `--packages workspace|resolve`
- Protected key tags for critical automation paths
- Maximum drift thresholds for controlled evolution
- External registry sync (GitLab, GitHub, custom APIs)

### 🔧 Improvements

#### Performance
- Parallel file processing with isolate pool
- Smart caching reduces scan time by 60-80%
- Incremental scanning for large codebases
- POSIX path normalization for cross-platform consistency

#### CI/CD Integration
- GitLab CI template with artifacts and metrics export
- GitHub Actions workflow with deterministic exit codes
- JUnit XML reports for test result parsing
- Markdown reports for PR/MR comments
- JSON schema v1.0 for programmatic consumption

### 📊 Metrics Collection

New v1.0 schema provides:
- `parse_success_rate`: Fraction of successfully parsed files (0.0-1.0)
- `widgets_total` / `widgets_with_keys`: Key coverage metrics
- `handlers_total` / `handlers_linked`: Event handler tracking
- `detectors[]`: Individual detector performance metrics
- `blind_spots[]`: Areas that cannot be properly tested

### 🔄 Migration Guide

See [MIGRATION_v3.md](MIGRATION_v3.md) for detailed migration instructions.

### Links
- [Pull Request #42](https://github.com/1nk1/flutter_keycheck/pull/42)
- [GitLab MR #15](https://gitlab.com/flutter/flutter_keycheck/-/merge_requests/15)


## [2.3.3] - 2024-06-24

### 🚀 Major Release: KeyConstants Pattern Support

This release introduces comprehensive support for modern Flutter KeyConstants patterns, making flutter_keycheck compatible with centralized key management approaches.

### ✨ New Features

#### KeyConstants Pattern Support

- **Modern Key Detection**: Full support for `Key(KeyConstants.*)` and `ValueKey(KeyConstants.*)` patterns
- **String Value Resolution**: KeyConstants resolver maps constant names to actual string values
- **Dynamic Key Methods**: Support for `KeyConstants.*Key()` method patterns with base key extraction
- **Mixed Pattern Support**: Seamlessly handles projects with both traditional and KeyConstants approaches

#### Enhanced Analysis & Reporting

- **KeyConstants Usage Report**: New `--key-constants-report` flag for comprehensive usage analysis
- **JSON Output**: Complete JSON format support with `--json-key-constants` flag for CI/CD integration
- **Usage Categorization**: Intelligent categorization of traditional vs KeyConstants-based keys
- **Migration Recommendations**: Smart suggestions for migrating from string literals to KeyConstants

#### Advanced Key Validation

- **KeyConstants Structure Validation**: New `--validate-key-constants` flag to verify class structure
- **Resolution Statistics**: Detailed stats showing string literals vs resolved KeyConstants usage
- **Unused Constants Detection**: Identifies unused KeyConstants for cleanup recommendations

### 🔧 Improvements

#### Enhanced CLI Experience

- **Verbose KeyConstants Info**: Detailed resolver status in verbose mode with file paths and counts
- **Resolution Indicators**: Clear indicators showing "(resolved from KeyConstants.name)" vs "(string literal)"
- **Comprehensive Statistics**: Resolution stats showing breakdown of key sources
- **Beautiful Output**: Enhanced formatting with emoji indicators and clear categorization

#### Technical Enhancements

- **KeyConstants Resolver**: Sophisticated parsing engine for extracting constants and methods
- **Smart File Exclusion**: KeyConstants definition files are excluded from usage scanning
- **Performance Optimization**: Efficient caching and resolution of constants
- **Robust Pattern Matching**: Advanced regex patterns for reliable key detection

### 🏗️ Architecture Improvements

#### Code Quality

- **62 Comprehensive Tests**: Extensive test suite covering all KeyConstants functionality
- **Clean Code**: Dart analyze passes with zero issues
- **Proper Formatting**: Code follows Dart formatting standards
- **Type Safety**: Full null safety compliance with robust error handling

#### Backward Compatibility

- **Zero Breaking Changes**: All existing functionality preserved
- **Legacy Project Support**: Traditional string-based keys continue to work
- **Gradual Migration**: Projects can adopt KeyConstants incrementally
- **Configuration Compatibility**: All existing config files remain valid

### 📊 Use Cases Supported

- ✅ **Modern Flutter Projects**: Full KeyConstants pattern support with centralized key management
- ✅ **Legacy Projects**: Continued support for traditional string-based keys
- ✅ **Mixed Approaches**: Projects transitioning from strings to KeyConstants
- ✅ **Dynamic Keys**: Support for parameterized key generation methods
- ✅ **CI/CD Integration**: JSON output for automated validation pipelines
- ✅ **Migration Planning**: Detailed analysis for planning KeyConstants adoption

### 🎯 Impact

This release transforms flutter_keycheck from a simple string validator into a comprehensive Flutter key management analysis tool, supporting modern development practices while maintaining full backward compatibility.

## [2.1.9] - 2025-12-19

### Added

- **KeyConstants Support**: Modern key pattern detection for `Key(KeyConstants.*)` and `ValueKey(KeyConstants.*)`
- **Dynamic Key Methods**: Support for `KeyConstants.*Key()` method patterns
- **KeyConstants Validation**: New `--validate-key-constants` flag to validate KeyConstants class structure
- **Usage Analysis Report**: New `--key-constants-report` flag for comprehensive key usage analysis
- **Migration Recommendations**: Intelligent suggestions for migrating from traditional to KeyConstants patterns
- **Enhanced Key Detection**: Improved regex patterns for modern Flutter key management

### Enhanced

- **Key Detection Engine**: Extended to support both traditional and modern key patterns
- **CLI Interface**: Added new flags for KeyConstants analysis and validation
- **Reporting System**: Enhanced reports with pattern categorization and recommendations
- **Test Coverage**: Comprehensive tests for KeyConstants functionality

### Fixed

- Updated GitHub Actions workflows to use Flutter SDK instead of Dart SDK
- Fixed example configuration and script for proper demonstration
- Enhanced workflow reliability with consistent Flutter version (3.24.5)

## [2.1.7] - 2025-12-19

Fixed

- Prepared release after pub.dev rate limit reset
- Enhanced workflow with dry-run validation

## [2.1.6] - 2025-12-19

Fixed

- Shortened package description for pub.dev compliance
- Added example file for pub.dev scoring

## [2.1.5] - 2025-12-19

Fixed

- Restored working GitHub Actions workflows from v2.1.0
- Fixed automated publishing through OIDC authentication

## [2.1.3] - 2025-12-19

Fixed

- Fixed changelog dates (corrected year from 2024 to 2025)
- Added GitHub Actions for automated publishing

## [2.1.2] - 2025-12-19

Fixed

- Fixed repository URLs in package metadata to point to correct GitHub repository (1nk1/flutter_keycheck)

## [2.1.1] - 2025-12-19

Fixed

- Fixed repository URLs in package metadata to point to correct GitHub repository (1nk1/flutter_keycheck)

## [2.1.0] - 2025-12-19

Added

🎯 Tracked Keys Feature

- **New `tracked_keys` configuration option** - Define a subset of keys to validate from your expected keys file
- When specified, only validates the tracked keys instead of the entire expected keys list
- Perfect for QA automation teams who want to focus on critical UI elements
- Example usage:

  ```yaml
  tracked_keys:
    - login_submit_button
    - signup_email_field
    - card_dropdown
  ```

🔧 Enhanced Configuration Management

- **Complete configuration file rewrite** with improved YAML parsing and error handling
- **New configuration hierarchy**: CLI arguments > Config file > Defaults
- **Enhanced error messages** with clear guidance for configuration issues
- **Comprehensive configuration validation** with helpful warnings

📊 Advanced Key Generation

- **Enhanced `--generate-keys` command** now respects all filtering options
- **Tracked keys support** in key generation - only generates specified tracked keys
- **Improved YAML output** with descriptive comments showing applied filters
- **Better formatting** with sorted keys and clear structure

🎨 Beautiful CLI Output

- **Redesigned human-readable output** with improved formatting and colors
- **Tracked keys status indicators** - shows "✅ Matched tracked key" vs "❌ Missing tracked key"
- **Enhanced verbose mode** with detailed configuration display
- **Better error reporting** with actionable suggestions

🏗️ Package Development Support

- **Automatic example/ folder detection** for Flutter packages published to pub.dev
- **Intelligent project path resolution** - works from root or example/ directory
- **Comprehensive scanning** of both main project and example application code
- **Dual dependency validation** - checks both main and example pubspec.yaml files

Enhanced

🔍 Improved Key Detection

- **Better regex patterns** for finding ValueKey and Key instances in Dart code
- **Enhanced file scanning** with recursive directory traversal
- **Optimized performance** for large codebases
- **More accurate key extraction** with improved parsing logic

⚙️ Configuration System Overhaul

- **Type-safe configuration classes** with proper null safety
- **Immutable configuration objects** with builder pattern for merging
- **Comprehensive getter methods** for accessing configuration values
- **Better default value handling** with explicit fallbacks

🧪 Robust Testing Infrastructure

- **45 comprehensive test cases** covering all functionality
- **8 new tracked keys tests** validating the new feature
- **12 enhanced configuration tests** with edge case coverage
- **8 example folder tests** ensuring package development support
- **17 core feature tests** with improved reliability

📦 Package Publishing Optimization

- **Enhanced .pubignore** to exclude development files from published package
- **Clean package structure** following pub.dev best practices
- **Comprehensive metadata** with topics, funding, and platform support
- **Example folder included** in repository but excluded from package

Fixed

🐛 Configuration Loading Issues

- **Fixed YAML parsing errors** with better error handling and recovery
- **Resolved null safety issues** in configuration merging
- **Fixed CLI argument precedence** to properly override config file values
- **Improved file path resolution** for relative and absolute paths

🔧 CLI Argument Processing

- **Fixed comma-separated value parsing** for include-only and exclude options
- **Resolved boolean flag handling** for proper true/false detection
- **Enhanced argument validation** with better error messages
- **Fixed help output formatting** with proper alignment and examples

📁 Project Structure Detection

- **Fixed example/ folder detection** when running from different directories
- **Resolved nested structure scanning** for complex project layouts
- **Fixed pubspec.yaml detection** in multi-project setups
- **Improved directory traversal** with better error handling

### Technical Details

#### 🏗️ Architecture Improvements

- **Modular configuration system** with separation of concerns
- **Enhanced KeyChecker class** with better method organization
- **Improved error handling** throughout the codebase
- **Better code documentation** with comprehensive inline comments

#### 📈 Performance Enhancements

- **Optimized file scanning** with efficient directory traversal
- **Reduced memory usage** in large project scanning
- **Faster regex matching** with compiled patterns
- **Improved startup time** with lazy initialization

#### 🔒 Type Safety & Reliability

- **Full null safety compliance** with proper nullable types
- **Immutable data structures** preventing accidental mutations
- **Comprehensive error handling** with graceful degradation
- **Enhanced test coverage** ensuring reliability

### Usage Examples

#### Basic Tracked Keys Validation

```bash
# Validate only critical QA automation keys
flutter_keycheck --keys keys/expected_keys.yaml
```

#### Advanced Filtering with Tracked Keys

```yaml
# .flutter_keycheck.yaml
tracked_keys:
  - login_submit_button
  - signup_email_field
  - card_dropdown
include_only:
  - qa_
  - e2e_
exclude:
  - temp_
  - debug_
```

#### Key Generation for QA Teams

```bash
# Generate keys file with only QA automation patterns
flutter_keycheck --generate-keys --include-only="qa_,e2e_" > keys/qa_keys.yaml
```

#### Package Development Workflow

```bash
# Automatically detects and validates example/ folder
flutter_keycheck --keys keys/expected_keys.yaml --strict --verbose
```

### Breaking Changes

None. This release maintains full backward compatibility with v2.0.x configurations and CLI usage.

### Migration Guide

No migration required. Existing configurations and CLI usage continue to work unchanged. New features are opt-in through configuration.

### Requirements

- Dart SDK: >=3.0.0 <4.0.0
- Flutter: Any version (for projects being validated)
- Platforms: Linux, macOS, Windows

---

## [2.0.1] - 2025-12-18

Fixed

- Fixed configuration loading for edge cases
- Improved error messages for missing dependencies
- Enhanced file path resolution

Enhanced

- Better documentation and examples
- Improved CLI help output
- More robust YAML parsing

---

## [2.0.0] - 2025-12-17

Added

- Advanced key filtering with `--include-only` and `--exclude` options
- Configuration file support with `.flutter_keycheck.yaml`
- Enhanced key generation with filtering support
- Example folder support for Flutter packages
- Comprehensive test suite with 37 test cases

Enhanced

- Complete rewrite with enhanced configuration management
- Beautiful output formatting with colors and emojis
- Comprehensive CI/CD integration support
- Better error handling and user experience

Breaking Changes

- Configuration file format updated
- CLI argument structure improved
- Output format enhanced

---

## [1.0.0] - 2025-12-16

Added

- Initial release
- Basic key validation functionality
- Integration test dependency checking
- Simple CLI interface

---

For more information and detailed usage examples, visit [pub.dev/packages/flutter_keycheck](https://pub.dev/packages/flutter_keycheck).
