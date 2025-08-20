# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Flutter KeyCheck is a CLI tool for validating Flutter automation keys in codebases. It's designed for QA automation teams, CI/CD pipelines, and Flutter package development.

## Development Commands

### Building and Running

```bash
# Install dependencies
dart pub get

# Run the CLI tool directly
dart run bin/flutter_keycheck.dart --keys keys/expected_keys.yaml

# Compile to executable
dart compile exe bin/flutter_keycheck.dart -o flutter_keycheck

# Run tests
dart test

# Run specific test file
dart test test/checker_test.dart
dart test test/key_constants_test.dart

# Format code
dart format .

# Analyze code
dart analyze --fatal-infos

# Generate coverage
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
```

### Publishing

```bash
# Verify package before publishing
dart pub publish --dry-run

# Publish to pub.dev (requires authentication)
dart pub publish --force
```

## Architecture

### Core Components

**lib/src/checker.dart** - Main validation engine
- `KeyChecker` class: Scans projects for Flutter keys, validates against expected keys
- `KeyConstantsResolver` class: Resolves KeyConstants patterns to actual string values
- Supports both traditional string keys and modern KeyConstants patterns

**lib/src/cli.dart** - Command-line interface
- Argument parsing using `args` package
- Supports configuration files (.flutter_keycheck.yaml)
- Multiple output formats (human-readable, JSON)

**lib/src/config.dart** - Configuration management
- Loads settings from YAML files
- CLI arguments override config file settings
- Supports include/exclude patterns and tracked keys

### Key Detection Patterns

The tool detects various Flutter key patterns:
- Traditional: `Key('string')`, `ValueKey('string')`
- KeyConstants: `Key(KeyConstants.fieldName)`, `ValueKey(KeyConstants.fieldName)`
- Dynamic methods: `KeyConstants.someKey()`, `KeyConstants.keyMethod(param)`
- Test finders: `find.byKey()`, `find.byValueKey()`

### Project Structure Detection

Automatically handles Flutter package structures:
- Detects `example/` folders for pub.dev packages
- Scans both main project and example directories
- Validates dependencies in all relevant pubspec.yaml files

## Testing Strategy

Tests are organized by functionality:
- **checker_test.dart**: Core validation logic
- **key_constants_test.dart**: KeyConstants pattern support
- **config_test.dart**: Configuration loading and overrides
- **flutter_keycheck_test.dart**: Integration tests

## CI/CD Integration

GitHub Actions workflows:
- **dart.yml**: Main CI pipeline (test, analyze, format)
- **publish.yml**: Automated publishing on version tags

The tool supports JSON output for CI/CD integration:
```bash
flutter_keycheck --report json
```

## Version Management

Version is maintained in pubspec.yaml. When releasing:
1. Update version in pubspec.yaml
2. Update CHANGELOG.md with release notes
3. Create git tag `v{version}` to trigger automated publishing

## Key Features to Maintain

1. **KeyConstants Support**: Modern pattern detection and resolution
2. **Tracked Keys**: Focus validation on critical subset of keys
3. **Filter Patterns**: Include/exclude capabilities with regex support
4. **Package Support**: Automatic example/ folder detection
5. **Multiple Output Formats**: Human-readable and JSON outputs
6. **Integration Test Validation**: Checks for Appium Flutter Driver setup