# Flutter KeyCheck

[![pub package](https://img.shields.io/pub/v/flutter_keycheck.svg)](https://pub.dev/packages/flutter_keycheck)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/flutter_keycheck)](https://pub.dev/packages/flutter_keycheck)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A powerful CLI tool for validating Flutter automation keys in your codebase. Perfect for QA automation teams, CI/CD pipelines, and Flutter package development.

## ✨ Features

### 🎯 Tracked Keys Validation (NEW in v2.1.0)

- **Focus on critical UI elements** - Define a subset of keys to validate for QA automation
- **Flexible validation scope** - Choose which keys matter most for your testing workflow
- **Smart filtering** - Combine tracked keys with include/exclude patterns

### 🔍 Advanced Key Filtering

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

### Global Installation

```bash
dart pub global activate flutter_keycheck
```

### Project Dependency

```yaml
dev_dependencies:
  flutter_keycheck: ^2.1.0
```

## 🚀 Quick Start

### 1. Generate Keys from Your Project

```bash
# Generate all keys found in your project
flutter_keycheck --generate-keys > keys/expected_keys.yaml

# Generate only QA automation keys
flutter_keycheck --generate-keys --include-only="qa_,e2e_" > keys/qa_keys.yaml
```

### 2. Validate Keys

```bash
# Basic validation
flutter_keycheck --keys keys/expected_keys.yaml

# Strict validation for CI/CD
flutter_keycheck --keys keys/expected_keys.yaml --strict --fail-on-extra
```

### 3. Use Configuration File

Create `.flutter_keycheck.yaml` in your project root:

```yaml
keys: keys/expected_keys.yaml
strict: false
verbose: false
fail_on_extra: false

# Focus on critical QA automation keys
tracked_keys:
  - login_submit_button
  - signup_email_field
  - card_dropdown

# Filter patterns for key generation and validation
include_only:
  - qa_
  - e2e_
  - _button
  - _field

exclude:
  - user.id
  - token
  - temp_
```

Then run:

```bash
flutter_keycheck
```

## 📚 Comprehensive Guide

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
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      - name: Install flutter_keycheck
        run: dart pub global activate flutter_keycheck
      - name: Validate automation keys
        run: flutter_keycheck --strict --fail-on-extra
```

#### GitLab CI

```yaml
keycheck:
  stage: test
  image: dart:stable
  script:
    - dart pub global activate flutter_keycheck
    - flutter_keycheck --strict --fail-on-extra
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
flutter_keycheck --report json
```

```json
{
  "matched_keys": {
    "login_submit_button": ["lib/screens/login_screen.dart"],
    "signup_email_field": ["lib/screens/signup_screen.dart"]
  },
  "missing_keys": ["card_dropdown"],
  "extra_keys": [],
  "dependencies": {
    "integration_test": true,
    "appium_flutter_server": true
  },
  "integration_tests": true,
  "tracked_keys": ["login_submit_button", "signup_email_field", "card_dropdown"]
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
