# Changelog

All notable changes to flutter_keycheck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.2] - 2024-12-19

Fixed

- Fixed repository URLs in package metadata to point to correct GitHub repository (1nk1/flutter_keycheck)

## [2.1.1] - 2024-12-19

Fixed

- Fixed repository URLs in package metadata to point to correct GitHub repository (1nk1/flutter_keycheck)

## [2.1.0] - 2024-12-19

### Added

#### 🎯 Tracked Keys Feature

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

#### 🔧 Enhanced Configuration Management

- **Complete configuration file rewrite** with improved YAML parsing and error handling
- **New configuration hierarchy**: CLI arguments > Config file > Defaults
- **Enhanced error messages** with clear guidance for configuration issues
- **Comprehensive configuration validation** with helpful warnings

#### 📊 Advanced Key Generation

- **Enhanced `--generate-keys` command** now respects all filtering options
- **Tracked keys support** in key generation - only generates specified tracked keys
- **Improved YAML output** with descriptive comments showing applied filters
- **Better formatting** with sorted keys and clear structure

#### 🎨 Beautiful CLI Output

- **Redesigned human-readable output** with improved formatting and colors
- **Tracked keys status indicators** - shows "✅ Matched tracked key" vs "❌ Missing tracked key"
- **Enhanced verbose mode** with detailed configuration display
- **Better error reporting** with actionable suggestions

#### 🏗️ Package Development Support

- **Automatic example/ folder detection** for Flutter packages published to pub.dev
- **Intelligent project path resolution** - works from root or example/ directory
- **Comprehensive scanning** of both main project and example application code
- **Dual dependency validation** - checks both main and example pubspec.yaml files

### Enhanced

#### 🔍 Improved Key Detection

- **Better regex patterns** for finding ValueKey and Key instances in Dart code
- **Enhanced file scanning** with recursive directory traversal
- **Optimized performance** for large codebases
- **More accurate key extraction** with improved parsing logic

#### ⚙️ Configuration System Overhaul

- **Type-safe configuration classes** with proper null safety
- **Immutable configuration objects** with builder pattern for merging
- **Comprehensive getter methods** for accessing configuration values
- **Better default value handling** with explicit fallbacks

#### 🧪 Robust Testing Infrastructure

- **45 comprehensive test cases** covering all functionality
- **8 new tracked keys tests** validating the new feature
- **12 enhanced configuration tests** with edge case coverage
- **8 example folder tests** ensuring package development support
- **17 core feature tests** with improved reliability

#### 📦 Package Publishing Optimization

- **Enhanced .pubignore** to exclude development files from published package
- **Clean package structure** following pub.dev best practices
- **Comprehensive metadata** with topics, funding, and platform support
- **Example folder included** in repository but excluded from package

### Fixed

#### 🐛 Configuration Loading Issues

- **Fixed YAML parsing errors** with better error handling and recovery
- **Resolved null safety issues** in configuration merging
- **Fixed CLI argument precedence** to properly override config file values
- **Improved file path resolution** for relative and absolute paths

#### 🔧 CLI Argument Processing

- **Fixed comma-separated value parsing** for include-only and exclude options
- **Resolved boolean flag handling** for proper true/false detection
- **Enhanced argument validation** with better error messages
- **Fixed help output formatting** with proper alignment and examples

#### 📁 Project Structure Detection

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

## [2.0.1] - 2024-12-18

Fixed

- Fixed configuration loading for edge cases
- Improved error messages for missing dependencies
- Enhanced file path resolution

Enhanced

- Better documentation and examples
- Improved CLI help output
- More robust YAML parsing

---

## [2.0.0] - 2024-12-17

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

## [1.0.0] - 2024-12-16

Added

- Initial release
- Basic key validation functionality
- Integration test dependency checking
- Simple CLI interface

---

For more information and detailed usage examples, visit [pub.dev/packages/flutter_keycheck](https://pub.dev/packages/flutter_keycheck).
