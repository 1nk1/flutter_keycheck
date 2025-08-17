# Flutter KeyCheck v3

[![CI Status](https://github.com/1nk1/flutter_keycheck/actions/workflows/ci.yml/badge.svg)](https://github.com/1nk1/flutter_keycheck/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/flutter_keycheck.svg)](https://pub.dev/packages/flutter_keycheck)
[![pub points](https://img.shields.io/pub/points/flutter_keycheck)](https://pub.dev/packages/flutter_keycheck/score)
[![Performance](https://img.shields.io/badge/Performance-60%25%20faster-brightgreen)](https://github.com/1nk1/flutter_keycheck/releases/tag/v3.0.0)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/flutter_keycheck)](https://pub.dev/packages/flutter_keycheck)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart 3.5+](https://img.shields.io/badge/Dart-3.5%2B-blue)](https://dart.dev)

**v3.0.0**: 🚀 60% faster • 📦 Scoped scanning • 🎯 CI/CD exit codes • ⚡ 84KB package • [Migration Guide](./MIGRATION_v3.md)

A comprehensive Flutter widget key coverage analyzer with AST parsing, key↔handler linking, and enterprise CI/CD integration. Perfect for QA automation teams, Flutter development teams, and DevOps engineers.

## 👥 Who is it for?

**QA Automation Engineers** - Generate baseline keys, track critical UI elements, validate in CI/CD pipelines

**Flutter Development Teams** - Ensure consistent key naming, manage technical debt, maintain testability

**DevOps & CI Engineers** - Implement quality gates, automate validation, generate compliance reports

**Package Maintainers** - Validate example apps, ensure demo completeness, maintain documentation accuracy

## ⚡ What's New in v3

### Scan Coverage vs Runtime Coverage
**Important**: Flutter KeyCheck provides "Scan Coverage" - static analysis of which widgets have keys in your codebase. This is different from runtime code coverage that measures executed code during tests. Scan Coverage helps identify testability gaps before runtime.

### Breaking Changes
- **CLI redesigned** with subcommands: `scan`, `validate`, `baseline`, `diff`, `sync`, `report`
- **Deterministic exit codes**: 0 (success), 1 (policy), 2 (config), 3 (I/O), 4 (internal)
- **Schema v1.0** with standardized metrics (parse_success_rate as fraction 0.0-1.0)

### Migration from v2.x

**CLI entrypoints:** Legacy bins removed (`*_v2.dart`, `*_v3_*.dart`). Use the unified CLI:
```bash
# Old (v2.x)
flutter_keycheck --keys file.yaml --strict

# New (v3.0)
flutter_keycheck validate --strict
dart run flutter_keycheck:flutter_keycheck scan --path <project_root> --output keycheck.json
```

**Exit codes:** Now deterministic (0=OK, 1=Policy, 2=Config, 3=IO, 4=Internal)

See [MIGRATION_v3.md](MIGRATION_v3.md) for detailed upgrade instructions.

## ✨ Features

### 🚀 AST-Based Analysis (NEW in v3.0)

- **Modern key patterns** - Detects `Key(KeyConstants.*)` and `ValueKey(KeyConstants.*)` usage
- **Dynamic key methods** - Supports `KeyConstants.*Key()` method patterns
- **KeyConstants validation** - Validates KeyConstants class structure and usage
- **Usage analysis** - Comprehensive reports on traditional vs modern key patterns
- **Migration recommendations** - Suggests improvements for key management

### 🎯 Tracked Keys Validation (NEW in v2.1.0)

- **Focus on critical UI elements** - Define a subset of keys to validate for QA automation
- **Flexible validation scope** - Choose which keys matter most for your testing workflow
- **Smart filtering** - Combine tracked keys with include/exclude patterns

### 🔍 Advanced Key Filtering & Tagging

- **AQA/E2E tagging support** - Organize keys by testing purpose (`aqa_*` for general automation, `e2e_*` for critical flows)
- **Include-only patterns** - Focus on specific key types like `qa_*`, `e2e_*`, `*_button`
- **Exclude patterns** - Filter out noise like dynamic IDs, tokens, and business logic keys
- **Regex support** - Use complex patterns for precise filtering
- **Substring matching** - Simple pattern matching for common use cases

### 🏗️ Flutter Package Support

- **Automatic example/ folder detection** - Seamlessly handles pub.dev package structure
- **Intelligent path resolution** - Works from root, example/, or nested directories
- **Comprehensive scanning** - Validates both main project and example code
- **Dual dependency checking** - Verifies test dependencies in all relevant pubspec.yaml files

### ⚙️ Flexible Configuration

- **YAML configuration files** - Store settings in `.flutter_keycheck.yaml`
- **CLI argument override** - Command-line arguments take priority over config files
- **Multiple output formats** - Human-readable or JSON output for automation

### 🧪 Integration Test Validation

- **Dependency verification** - Ensures `integration_test` and `appium_flutter_server` are present
- **Test setup validation** - Checks for proper Appium Flutter Driver initialization
- **Strict mode** - Enforce complete test setup for CI/CD environments

## 📦 Installation

### Version Compatibility

**v3.0.0** (Latest) - Major release with breaking changes:
- Package scope scanning, dependency caching
- Deterministic exit codes for CI/CD
- Unified CLI with subcommands
- Requires migration from v2.x (see [MIGRATION_v3.md](MIGRATION_v3.md))

**v2.3.3** (Stable) - Previous major version:
- Traditional CLI interface
- Binary exit codes (0/1)
- Stable and fully supported
- No migration required

### Choosing Your Version

```yaml
# For new projects or those ready to migrate:
dependencies:
  flutter_keycheck: ^3.0.0

# To stay on v2 (fully supported):
dependencies:
  flutter_keycheck: ^2.3.3
```

### Global Installation

```bash
# Install latest v3:
dart pub global activate flutter_keycheck

# Or explicitly install v2:
dart pub global activate flutter_keycheck 2.3.3
```

### Project Dependency

```yaml
dev_dependencies:
  flutter_keycheck: ^3.0.0-rc.1
```

## 🚀 Quick Start

### Global Installation
```bash
# Install globally
dart pub global activate flutter_keycheck

# Run commands
flutter_keycheck scan --report json
flutter_keycheck validate --strict
flutter_keycheck baseline create
```

### Local Installation
```bash
# Add to dev_dependencies
dart pub add --dev flutter_keycheck

# Run with dart run
dart run flutter_keycheck:flutter_keycheck scan --report json
dart run flutter_keycheck:flutter_keycheck validate --strict
```

### 1. Scan Your Project

```bash
# Scan and generate coverage report
flutter_keycheck scan --report json,junit,md --out-dir reports

# Scan with specific packages mode
flutter_keycheck scan --packages workspace --report json
```

### 2. Validate Coverage

```bash
# Primary validation command
flutter_keycheck validate --strict

# CI/CD validation (alias)
flutter_keycheck ci-validate --fail-on-lost --protected-tags critical,aqa

# With thresholds
flutter_keycheck validate --threshold-file coverage-thresholds.yaml
```

### 3. Use Configuration File

Create `.flutter_keycheck.yaml` in your project root:

```yaml
version: 1  # Schema version (required for v3)

validate:
  thresholds:
    min_coverage: 0.8    # 80% widgets must have keys
    max_drift: 10        # Max 10 keys can change
    parse_success: 0.95  # 95% files must parse successfully
  protected_tags:
    - critical           # Critical user journeys
    - aqa               # Automation test keys
  fail_on_lost: true    # Fail if protected keys are removed
  fail_on_extra: false  # Don't fail on new keys

scan:
  packages: workspace    # 'workspace' or 'resolve'
  include_tests: false   # Skip test files
  include_generated: false  # Skip .g.dart files
  cache: true           # Enable caching
```

Then run:

```bash
# Uses configuration file automatically
flutter_keycheck validate
```

### 4. CI/CD Integration

```bash
# GitLab CI example
flutter_keycheck scan --report json,junit --out-dir reports
flutter_keycheck validate --strict --fail-on-lost
# Artifacts available in reports/

# GitHub Actions example
flutter_keycheck ci-validate --protected-tags critical,aqa
if [ $? -eq 1 ]; then echo "Policy violation!"; exit 1; fi
```

## 🏷️ AQA/E2E Tagging Strategy

Flutter KeyCheck supports organized tagging for different testing purposes, making it easier to manage keys across QA automation workflows.

### Tagging Conventions

#### AQA Tags (`aqa_*`)

- **Purpose**: General UI testing, validation, regression testing
- **Scope**: All testable UI elements
- **Examples**: `aqa_email_field`, `aqa_submit_button`, `aqa_error_message`

#### E2E Tags (`e2e_*`)

- **Purpose**: Critical user journeys, smoke testing
- **Scope**: Key business process elements only
- **Examples**: `e2e_login_flow`, `e2e_checkout_process`, `e2e_payment_button`

### Implementation Example

```dart
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AQA: General UI testing
        TextField(
          key: const ValueKey('aqa_email_field'),
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          key: const ValueKey('aqa_password_field'),
          decoration: const InputDecoration(labelText: 'Password'),
        ),

        // E2E: Critical business flow
        ElevatedButton(
          key: const ValueKey('e2e_login_submit_button'),
          onPressed: _handleLogin,
          child: const Text('Login'),
        ),

        // AQA: Error state testing
        if (_hasError)
          Container(
            key: const ValueKey('aqa_error_message_container'),
            child: const Text('Login failed'),
          ),
      ],
    );
  }
}
```

### Configuration by Tags

Create separate configurations for different testing scenarios:

```yaml
# .flutter_keycheck_aqa.yaml - For comprehensive UI testing
keys: keys/aqa_keys.yaml
include_only: [aqa_]
strict: false
fail_on_extra: false

# .flutter_keycheck_e2e.yaml - For critical flow testing
keys: keys/e2e_keys.yaml
include_only: [e2e_]
strict: true
fail_on_extra: true
```

### Usage Commands

```bash
# Generate keys by testing purpose
flutter_keycheck --generate-keys --include-only="aqa_" > keys/aqa_keys.yaml
flutter_keycheck --generate-keys --include-only="e2e_" > keys/e2e_keys.yaml

# Validate by configuration
flutter_keycheck --config .flutter_keycheck_aqa.yaml
flutter_keycheck --config .flutter_keycheck_e2e.yaml --strict

# JSON reports for CI/CD
flutter_keycheck --config .flutter_keycheck_e2e.yaml --report json
```

For detailed examples and best practices, see [AQA/E2E Usage Guide](example/AQA_E2E_USAGE.md).

## 📚 Comprehensive Guide

### KeyConstants Support

Flutter KeyCheck now supports modern KeyConstants patterns for better key management and organization.

#### Supported Patterns

```dart
// KeyConstants class definition
class KeyConstants {
  // Static constants
  static const String loginButton = 'login_button';
  static const String emailField = 'email_field';

  // Dynamic key methods
  static Key gameCardKey(String gameId) => Key('game_card_$gameId');
  static Key userProfileKey(int userId) => Key('user_profile_$userId');
}

// Usage in widgets
Widget build(BuildContext context) {
  return Column(
    children: [
      // Modern KeyConstants usage (detected)
      TextField(key: const Key(KeyConstants.emailField)),
      ElevatedButton(
        key: const ValueKey(KeyConstants.loginButton),
        onPressed: () {},
        child: Text('Login'),
      ),

      // Traditional usage (still supported)
      TextField(key: const ValueKey('old_style_key')),
    ],
  );
}

// Usage in tests
testWidgets('login test', (tester) async {
  // Modern finder usage (detected)
  await tester.tap(find.byValueKey(KeyConstants.loginButton));

  // Traditional finder usage (still supported)
  await tester.tap(find.byValueKey('old_style_key'));
});
```

#### KeyConstants Validation

```bash
# Validate KeyConstants class structure
flutter_keycheck --validate-key-constants
```

Output:

```bash
🔍 KeyConstants Validation

✅ KeyConstants class found
   📁 Location: lib/constants/key_constants.dart

📋 Static constants (8):
   • loginButton
   • emailField
   • passwordField
   • signupButton
   • logoutButton
   • homeTab
   • profileTab
   • settingsTab

⚙️  Dynamic methods (4):
   • gameCardKey
   • userProfileKey
   • categoryButtonKey
   • notificationKey
```

#### Usage Analysis Report

```bash
# Generate comprehensive usage report
flutter_keycheck --key-constants-report
```

Output:

```bash
🔑 KeyConstants Analysis Report

📊 Total keys found: 25

📝 Traditional string-based keys (15):
   • old_login_button
   • legacy_email_field
   • temp_password_input
   ...

🏗️  KeyConstants static keys (8):
   • loginButton
   • emailField
   • passwordField
   ...

⚡ KeyConstants dynamic methods (2):
   • gameCardKey
   • userProfileKey

💡 Recommendations:
   • Found 15 traditional string-based keys that could be migrated to KeyConstants
   • Consider standardizing dynamic key method naming patterns
```

### Tracked Keys Feature

The tracked keys feature allows you to focus validation on a critical subset of your UI automation keys. This is perfect for QA teams who want to ensure specific elements are always present without being overwhelmed by every key in the codebase.

#### Example Workflow

1. **Generate all keys** from your project:

```bash
flutter_keycheck --generate-keys > keys/all_keys.yaml
```

1. **Create a tracked keys configuration** focusing on critical elements:

```yaml
# .flutter_keycheck.yaml
keys: keys/all_keys.yaml
tracked_keys:
  - login_submit_button
  - signup_email_field
  - payment_confirm_button
  - logout_button
```

1. **Validate only tracked keys**:

```bash
flutter_keycheck
```

Output:

```bash
🔍 Flutter KeyCheck Results

📌 Tracking 4 specific keys

✅ Matched tracked keys (3):
  - login_submit_button
  - signup_email_field
  - logout_button

❌ Missing tracked keys (1):
  - payment_confirm_button

🎉 All checks passed!
```

### Advanced Filtering

#### Include-Only Patterns

Focus on specific key types:

```bash
# Only QA automation keys
flutter_keycheck --include-only="qa_,e2e_"

# Only buttons and fields
flutter_keycheck --include-only="_button,_field"

# Regex patterns
flutter_keycheck --include-only="^qa_.*_button$"
```

#### Exclude Patterns

Filter out noise and dynamic content:

```bash
# Exclude dynamic user data
flutter_keycheck --exclude="user.id,token,session"

# Exclude temporary and debug keys
flutter_keycheck --exclude="temp_,debug_,dev_"

# Exclude template variables (regex)
flutter_keycheck --exclude="\$\{.*\}"
```

#### Combined Filtering

```yaml
# .flutter_keycheck.yaml
include_only:
  - qa_
  - e2e_
  - automation_
exclude:
  - temp_
  - debug_
  - user\..*
tracked_keys:
  - qa_login_button
  - qa_signup_field
  - e2e_checkout_flow
```

### Flutter Package Development

Flutter KeyCheck automatically detects and handles packages with example/ folders, which is the standard structure for packages published to pub.dev.

#### Supported Structures

```bash
my_package/
├── lib/                    # Main package code
├── example/
│   ├── lib/               # Example app code
│   ├── integration_test/  # Example integration tests
│   └── pubspec.yaml       # Example dependencies
├── integration_test/      # Package integration tests
├── pubspec.yaml           # Package dependencies
└── .flutter_keycheck.yaml # Configuration
```

#### Automatic Detection

- **Run from anywhere**: Works from root directory or example/ subdirectory
- **Comprehensive scanning**: Validates keys in both main package and example app
- **Dependency validation**: Checks test dependencies in both pubspec.yaml files
- **Integration test detection**: Finds tests in both locations

#### Example Commands

```bash
# From package root - scans both main and example
flutter_keycheck --generate-keys

# From example directory - automatically detects package structure
cd example && flutter_keycheck --config=../.flutter_keycheck.yaml

# Validate package for publishing
flutter_keycheck --strict --fail-on-extra
```

### Integration Test Validation

Flutter KeyCheck validates your Appium Flutter Driver setup:

#### Requirements

- `integration_test` dependency in `dev_dependencies`
- `appium_flutter_server` dependency in `dev_dependencies`
- Integration test files in `integration_test/` directory
- Proper Appium Flutter Driver initialization

#### Example Integration Test Setup

```dart
// integration_test/appium_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:appium_flutter_server/appium_flutter_server.dart';
import 'package:my_app/main.dart' as app;

void main() {
  group('App Integration Tests', () {
    setUpAll(() async {
      await initializeTest();
    });

    testWidgets('login flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Your test code using ValueKey elements
      await tester.tap(find.byValueKey('login_submit_button'));
      await tester.pumpAndSettle();
    });
  });
}
```

### CLI Reference

#### Command-Line Options

| Option            | Description                               | Example                           |
| ----------------- | ----------------------------------------- | --------------------------------- |
| `--keys`          | Path to expected keys YAML file           | `--keys keys/expected_keys.yaml`  |
| `--path`          | Project path to scan                      | `--path ./my_flutter_app`         |
| `--strict`        | Fail if integration test setup incomplete | `--strict`                        |
| `--verbose`       | Show detailed output                      | `--verbose`                       |
| `--fail-on-extra` | Fail if extra keys found                  | `--fail-on-extra`                 |
| `--generate-keys` | Generate keys file from project           | `--generate-keys`                 |
| `--include-only`  | Include only matching patterns            | `--include-only="qa_,e2e_"`       |
| `--exclude`       | Exclude matching patterns                 | `--exclude="temp_,debug_"`        |
| `--config`        | Configuration file path                   | `--config .flutter_keycheck.yaml` |
| `--report`        | Output format (human/json)                | `--report json`                   |

#### Configuration File Reference

```yaml
# Basic settings
keys: keys/expected_keys.yaml # Path to expected keys file
path: . # Project path to scan
strict: false # Strict validation mode
verbose: false # Verbose output
fail_on_extra: false # Fail on extra keys
report: human # Output format

# Advanced filtering
include_only: # Include only matching patterns
  - qa_
  - e2e_
  - _button
  - _field

exclude: # Exclude matching patterns
  - user.id
  - token
  - temp_
  - debug_

# Tracked keys (NEW in v2.1.0)
tracked_keys: # Focus on specific keys
  - login_submit_button
  - signup_email_field
  - card_dropdown
```

## Usage Examples

### QA Automation Workflow

```bash
# 1. Generate QA-specific keys
flutter_keycheck --generate-keys --include-only="qa_,e2e_" > keys/qa_keys.yaml

# 2. Create tracked keys config for critical elements
cat > .flutter_keycheck.yaml << EOF
keys: keys/qa_keys.yaml
tracked_keys:
  - qa_login_button
  - qa_signup_field
  - qa_payment_button
fail_on_extra: true
EOF

# 3. Validate in CI/CD pipeline
flutter_keycheck --strict
```

### CI/CD Integration

#### GitHub Actions

```yaml
name: Flutter KeyCheck

on: [push, pull_request]

jobs:
  keycheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - name: Install flutter_keycheck
        run: dart pub global activate flutter_keycheck
      - name: Validate automation keys
        run: flutter_keycheck --strict --fail-on-extra
      - name: Upload key validation report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: keycheck-report
          path: keycheck-report.json
```

#### GitLab CI

```yaml
stages:
  - validate

variables:
  PUB_CACHE: "$CI_PROJECT_DIR/.pub-cache"

cache:
  key: "${CI_PROJECT_NAME}"
  paths:
    - .pub-cache/

validate:keycheck:
  stage: validate
  image: dart:stable
  before_script:
    - dart --version
    - dart pub global activate flutter_keycheck
  script:
    - flutter_keycheck --config .flutter_keycheck_e2e.yaml --strict --fail-on-extra --report json || EXIT=$?
    - mkdir -p reports && mv keycheck-report.json reports/ || true
    - exit ${EXIT:-0}
  artifacts:
    when: always
    paths:
      - reports/
    reports:
      junit: reports/keycheck-report.json
    expire_in: 1 week
  only:
    - merge_requests
    - main
```

#### Azure DevOps

```yaml
- task: DartInstaller@0
  displayName: 'Install Dart SDK'
  inputs:
    dartVersion: 'stable'

- script: |
    dart pub global activate flutter_keycheck
    flutter_keycheck --strict --fail-on-extra
  displayName: 'Validate Flutter Keys'
  continueOnError: false

- task: PublishTestResults@2
  condition: always()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'keycheck-report.xml'
    testRunTitle: 'Flutter KeyCheck Results'
```

#### CircleCI

```yaml
version: 2.1

orbs:
  dart: circleci/dart@1.0.0

jobs:
  keycheck:
    executor: dart/dart
    steps:
      - checkout
      - dart/install-dart
      - run:
          name: Install flutter_keycheck
          command: dart pub global activate flutter_keycheck
      - run:
          name: Validate automation keys
          command: flutter_keycheck --strict --fail-on-extra
      - store_artifacts:
          path: keycheck-report.json
          destination: keycheck-report

workflows:
  test-and-validate:
    jobs:
      - keycheck
```

### Package Development

```bash
# Generate keys for package and example
flutter_keycheck --generate-keys > keys/expected_keys.yaml

# Validate package structure
flutter_keycheck --strict --verbose

# Test from example directory
cd example && flutter_keycheck --config=../.flutter_keycheck.yaml
```

## 🎨 Output Examples

### Human-Readable (Default)

```bash
🔍 Flutter KeyCheck Results

📌 Tracking 3 specific keys

✅ Matched tracked keys (2):
  - login_submit_button
    📍 lib/screens/login_screen.dart
  - signup_email_field
    📍 lib/screens/signup_screen.dart

❌ Missing tracked keys (1):
  - card_dropdown

✅ Required dependencies found
✅ Integration test setup complete

💥 Some checks failed
```

### JSON Output

```bash
# Standard key validation in JSON format
flutter_keycheck --report json

# KeyConstants analysis in JSON format
flutter_keycheck --key-constants-report --json-key-constants
flutter_keycheck --validate-key-constants --json-key-constants
```

#### Standard Validation JSON Structure

```json
{
  "timestamp": "2025-12-23T10:05:59.811115",
  "summary": {
    "total_expected_keys": 18,
    "found_keys": 10,
    "missing_keys": 8,
    "extra_keys": 2,
    "validation_passed": false
  },
  "missing_keys": ["avatar_image", "edit_profile_button"],
  "extra_keys": ["emailField", "passwordField"],
  "found_keys": {
    "login_button": {
      "key": "login_button",
      "locations": ["lib/main.dart", "lib/widgets.dart"],
      "location_count": 2
    }
  },
  "dependencies": {
    "integration_test": false,
    "appium_flutter_server": false,
    "all_dependencies_present": false
  },
  "integration_test_setup": {
    "has_integration_tests": false,
    "setup_complete": false
  },
  "tracked_keys": null
}
```

#### KeyConstants Analysis JSON Structure

```json
{
  "timestamp": "2025-12-23T10:06:11.364861",
  "analysis_type": "key_constants_report",
  "summary": {
    "total_keys_found": 10,
    "traditional_keys_count": 7,
    "constant_keys_count": 3,
    "dynamic_keys_count": 0
  },
  "traditional_keys": ["email_field", "password_field", "login_button"],
  "constant_keys": ["loginButton", "emailField", "passwordField"],
  "dynamic_keys": [],
  "key_constants_validation": {
    "hasKeyConstants": true,
    "constantsFound": ["loginButton", "emailField", "passwordField"],
    "methodsFound": [],
    "filePath": "lib/key_constants.dart"
  },
  "recommendations": [
    "Found 7 traditional string-based keys that could be migrated to KeyConstants"
  ]
}
```

## 🛠️ Troubleshooting

### Common Issues

#### "No keys found in project"

- Ensure your Flutter widgets use `ValueKey` or `Key` with string values
- Check that you're scanning the correct directory with `--path`
- Use `--verbose` to see which files are being scanned

#### "Missing dependencies"

Add required dependencies to your `pubspec.yaml`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  appium_flutter_server: ^0.0.27
```

#### "Integration test setup incomplete"

Ensure your integration tests import and initialize Appium Flutter Server:

```dart
import 'package:appium_flutter_server/appium_flutter_server.dart';

void main() {
  setUpAll(() async {
    await initializeTest();
  });
}
```

### Best Practices

1. **Use descriptive key names**: `login_submit_button` instead of `button1`
2. **Consistent naming patterns**: Use prefixes like `qa_`, `e2e_`, `test_`
3. **Avoid dynamic keys**: Don't use variables in key values
4. **Regular validation**: Run in CI/CD to catch missing keys early
5. **Track critical paths**: Use tracked_keys for essential user journeys

## 🔒 Security & Safety

Flutter KeyCheck is designed with security in mind:

- **Read-only operations**: Only scans source code files, never modifies them
- **No network access**: Works entirely offline, no data is sent anywhere
- **No secrets exposure**: Does not read environment variables or configuration files with sensitive data
- **Path restrictions**: Use `--path` to limit scanning to specific directories
- **Exclude patterns**: Use `--exclude` to skip sensitive directories or files
- **Safe for CI/CD**: Designed for automated environments with strict security policies

Example of restricting scan scope:
```bash
# Scan only specific directories
flutter_keycheck --path lib --exclude="lib/internal,lib/generated"

# Exclude sensitive patterns
flutter_keycheck --exclude="*.env,*.secret,config/"
```

## 📦 Package Information

### Excluded from Package

The published package excludes development files to keep it lightweight:

```bash
example/         # Example code (repo only)
test/            # Test files
.github/         # CI workflows
.vscode/         # Editor settings
.dart_tool/      # Build artifacts
```

Requirements

- **Dart SDK**: >=3.0.0 <4.0.0
- **Platforms**: Linux, macOS, Windows
- **Flutter**: Any version (for projects being validated)

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) and submit pull requests to our [GitHub repository](https://github.com/1nk1/flutter_keycheck).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [pub.dev package](https://pub.dev/packages/flutter_keycheck)
- [GitHub repository](https://github.com/1nk1/flutter_keycheck)
- [Issue tracker](https://github.com/1nk1/flutter_keycheck/issues)
- [Changelog](CHANGELOG.md)

---

Made with ❤️ for the Flutter community
