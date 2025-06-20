# Flutter Key Integration Validator

[![pub package](https://img.shields.io/pub/v/flutter_keycheck.svg)](https://pub.dev/packages/flutter_keycheck)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.2%2B-blue.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](https://pub.dev/packages/flutter_keycheck)

A CLI tool to validate Flutter automation keys and integration test dependencies. Ensures your Flutter app is ready for automated testing with proper key coverage.

> **Note:** This is a desktop CLI tool that uses `dart:io` for file system operations. It is not compatible with web/WASM environments by design.

## 🎯 Features

- **Key Validation**: Validates Flutter key usage in source code
  - `ValueKey` declarations
  - `Key` declarations
  - `find.byValueKey` finders
  - `find.bySemanticsLabel` finders
  - `find.byTooltip` finders
- **Dependency Check**: Verifies required test dependencies
- **Integration Test Setup**: Validates test file structure
- **Colorful Output**: Beautiful console output with emojis
- **Flexible Configuration**: YAML-based key definitions
- **CI/CD Ready**: Perfect for automation pipelines

## 📦 Installation

```bash
dart pub global activate flutter_keycheck
```

## 🚀 Quick Start

1. **Create a keys configuration file:**

```yaml
# expected_keys.yaml
keys:
  - login_button
  - password_field
  - submit_button
  - help_tooltip
  - user_profile_card
```

1. **Run the validator:**

```bash
flutter_keycheck --keys expected_keys.yaml
```

## 🔧 Configuration

### Configuration File (Recommended)

Create a `.flutter_keycheck.yaml` file in your project root for convenient configuration:

```yaml
# .flutter_keycheck.yaml
keys: keys/expected_keys.yaml
path: .
strict: true
verbose: false
```

Then simply run:

```bash
flutter_keycheck
```

**Benefits:**

- ✅ No need to remember CLI arguments
- ✅ Consistent team configuration
- ✅ Perfect for CI/CD pipelines
- ✅ Version control friendly

### Priority Order

1. **CLI arguments** (highest priority)
2. **`.flutter_keycheck.yaml` file**
3. **Default values** (lowest priority)

```bash
# Config file sets verbose: true, but CLI overrides it
flutter_keycheck --verbose false
```

### Command Line Options

| Option      | Short | Description                                          | Default      |
| ----------- | ----- | ---------------------------------------------------- | ------------ |
| `--keys`    | `-k`  | Path to keys file (.yaml)                            | **required** |
| `--path`    | `-p`  | Project source root                                  | `.`          |
| `--strict`  | `-s`  | Fail if integration_test/appium_test.dart is missing | `false`      |
| `--verbose` | `-v`  | Show detailed output                                 | `false`      |
| `--help`    | `-h`  | Show help message                                    | -            |

## 📋 Usage Examples

### Basic Usage

```bash
# Using config file (recommended)
flutter_keycheck

# Direct CLI usage
flutter_keycheck --keys expected_keys.yaml

# Check specific project path
flutter_keycheck --keys keys/production.yaml --path ./my_flutter_app

# Strict mode (fail on missing integration tests)
flutter_keycheck --keys expected_keys.yaml --strict

# Verbose output
flutter_keycheck --keys expected_keys.yaml --verbose
```

### With Configuration File

```bash
# 1. Create config file
cat > .flutter_keycheck.yaml << EOF
keys: keys/expected_keys.yaml
path: .
strict: true
verbose: false
EOF

# 2. Run with default config
flutter_keycheck

# 3. Override specific settings
flutter_keycheck --verbose  # Enable verbose while keeping other config
```

## 📊 Example Output

```md
🎯 [flutter_keycheck] 🔍 Scanning project...

🧩 Keys Check
────────────────────────────────────────────
❌ Missing Keys:
⛔️ login_button
⛔️ forgot_password_link

🧼 Extra Keys:
💡 debug_menu_button
💡 temp_test_key

🔎 Found Keys:
✔️ password_input_field
└── lib/screens/auth/login_screen.dart
✔️ submit_button
└── lib/widgets/forms/auth_form.dart
└── integration_test/auth_test.dart

📦 Dependencies
────────────────────────────────────────────
✔️ integration_test found in pubspec.yaml ✅
✔️ appium_flutter_server found in pubspec.yaml ✅

🧪 Integration Test Setup
────────────────────────────────────────────
✔️ Found integration_test/appium_test.dart ✅
✔️ Appium Flutter Driver initialized ✅

🚨 Final Verdict
────────────────────────────────────────────
❌ Project is NOT ready for automation build.
Missing 2 required keys. Please add them to your widgets.
```

## 🔑 Supported Key Types

### 1. Widget Keys

```dart
// ValueKey
TextField(key: const ValueKey('email_input'))
ElevatedButton(key: const ValueKey('login_button'))

// Regular Key
Container(key: const Key('user_avatar'))
```

### 2. Test Finders

```dart
// Integration tests
await tester.tap(find.byValueKey('login_button'));
await tester.enterText(find.byValueKey('email_input'), 'test@example.com');

// Semantic labels
await tester.tap(find.bySemanticsLabel('Submit Form'));

// Tooltips
await tester.tap(find.byTooltip('Help Information'));
```

## 📝 Configuration

### YAML Format

```yaml
keys:
  # Static keys
  - login_button
  - password_field
  - submit_button

  # Dynamic keys (with placeholders)
  - user_card_{userId}
  - game_level_{levelId}

  # Semantic labels
  - 'Welcome Message'
  - 'Error Dialog'

  # Tooltips
  - 'Help Button'
  - 'Settings Menu'
```

## 🧪 Appium Flutter Integration Setup

For complete Appium Flutter integration testing setup, follow the official documentation:

**📖 [Appium Flutter Integration Driver Setup Guide](https://github.com/AppiumTestDistribution/appium-flutter-integration-driver?tab=readme-ov-file)**

### Quick Setup Steps

1. Add dependency to pubspec.yaml:

```yaml
dev_dependencies:
  appium_flutter_server: '>=0.0.27 <1.0.0'
```

1. Create integration_test/appium_test.dart:

```dart
import 'package:appium_flutter_server/appium_flutter_server.dart';
import 'package:your_app/main.dart';

void main() {
  initializeTest(app: const MyApp());
}
```

1. Build your app for testing:

```bash
# Android
./gradlew app:assembleDebug -Ptarget=`pwd`/../integration_test/appium_test.dart

# iOS Simulator
flutter build ios integration_test/appium_test.dart --simulator
```

### What flutter_keycheck validates

✅ Widget Keys - ValueKey and Key declarations in your widgets
✅ Test Finders - find.byValueKey, find.bySemanticsLabel, find.byTooltip usage
✅ Dependencies - Required integration_test and appium_flutter_server packages
✅ Test Setup - Proper integration test file structure

## 🔧 Integration with CI/CD

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
      - name: Install flutter_keycheck
        run: dart pub global activate flutter_keycheck
      - name: Validate keys
        run: flutter_keycheck --keys expected_keys.yaml --strict
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
flutter_keycheck --keys expected_keys.yaml --strict
if [ $? -ne 0 ]; then
  echo "❌ Key validation failed. Please fix the issues above."
  exit 1
fi
```

## 🛠️ Development

### Running Tests

```bash
dart test
```

### Running from Source

```bash
dart run bin/flutter_keycheck.dart --keys keys/testing_keys.yaml
```

## 💡 Best Practices

1. **Organize Keys by Feature**

   ```yaml
   keys:
     # Authentication
     - login_button
     - signup_link
     - password_field

     # Profile
     - edit_profile_button
     - save_changes_button
   ```

2. **Use Descriptive Names**

   ```dart
   // ✅ Good
   ValueKey('user_profile_edit_button')

   // ❌ Avoid
   ValueKey('btn1')
   ```

3. **Keep Keys Consistent**

   ```dart
   // Use consistent naming convention
   ValueKey('login_email_field')
   ValueKey('login_password_field')
   ValueKey('login_submit_button')
   ```

## 🖥️ Platform Compatibility

This CLI tool is designed for **desktop environments only** and supports:

- ✅ **Linux** (x64)
- ✅ **macOS** (x64, ARM64)
- ✅ **Windows** (x64)

**Not supported:**

- ❌ **Web/Browser** - Uses `dart:io` for file system operations
- ❌ **WebAssembly (WASM)** - Not compatible with web runtime
- ❌ **Mobile platforms** - Designed as a development tool for desktop

> **Why not web/WASM?** This tool performs file system operations using `dart:io` to scan your Flutter project files, check dependencies in `pubspec.yaml`, and validate integration test setup. These operations are not available in web/WASM environments by design.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for Flutter automation testing
- Inspired by the need for reliable UI test coverage
- Perfect for CI/CD integration
- Works seamlessly with [Appium Flutter Integration Driver](https://github.com/AppiumTestDistribution/appium-flutter-integration-driver)

## 📚 Resources

- 📖 [Appium Flutter Integration Driver](https://github.com/AppiumTestDistribution/appium-flutter-integration-driver)
- 📦 [appium_flutter_server package](https://pub.dev/packages/appium_flutter_server)
- 🔧 [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- 🎯 [Flutter Testing Best Practices](https://docs.flutter.dev/testing)

## 🏗️ CI Integration

GitHub Actions

Create `.github/workflows/flutter_keycheck.yml`:

```yaml
name: Flutter KeyCheck

on:
  push:
    paths:
      - '**/*.dart'
      - 'pubspec.yaml'
      - '.flutter_keycheck.yaml'
      - '**/expected_keys.yaml'
  pull_request:

jobs:
  keycheck:
    runs-on: ubuntu-latest
    name: 🔍 Flutter Key Validation

    steps:
      - name: ⬇️ Checkout repository
        uses: actions/checkout@v4

      - name: ⚙️ Set up Dart SDK
        uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: 📦 Get dependencies
        run: dart pub get

      - name: 🔍 Activate flutter_keycheck
        run: dart pub global activate flutter_keycheck

      - name: 🕵️ Run flutter_keycheck (basic)
        run: flutter_keycheck

      - name: 🚨 Run flutter_keycheck (strict mode)
        run: flutter_keycheck --strict --fail-on-extra
```

### GitLab CI

Add to your `.gitlab-ci.yml`:

```yaml
flutter_keycheck:
  stage: test
  image: dart:stable
  script:
    - dart pub get
    - dart pub global activate flutter_keycheck
    - flutter_keycheck --strict
  only:
    changes:
      - '**/*.dart'
      - 'pubspec.yaml'
      - '.flutter_keycheck.yaml'
      - '**/expected_keys.yaml'
```

### Bitrise

Add step to your `bitrise.yml`:

```yaml
- script@1:
    title: Flutter KeyCheck
    inputs:
      - content: |
          #!/usr/bin/env bash
          set -ex
          dart pub global activate flutter_keycheck
          flutter_keycheck --strict --fail-on-extra
```

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Flutter KeyCheck') {
            steps {
                sh '''
                    dart pub get
                    dart pub global activate flutter_keycheck
                    flutter_keycheck --strict
                '''
            }
        }
    }
}
```

## 📊 Advanced Usage

### Generate Reports

```bash
# JSON report for automation
flutter_keycheck --report json > keycheck_report.json

# Markdown report for documentation
flutter_keycheck --report markdown > keycheck_report.md
```

### Custom Configuration Files

```bash
# Use custom config file
flutter_keycheck --config ci/keycheck_config.yaml

# Override config with CLI args
flutter_keycheck --config my_config.yaml --strict --verbose
```

### Multiple Environments

```bash
# Development environment (lenient)
flutter_keycheck --keys keys/dev_keys.yaml

# Production environment (strict)
flutter_keycheck --keys keys/prod_keys.yaml --strict --fail-on-extra
```

## 🎯 Best Practices

### 1. **Organize Your Keys**

```bash
keys/
├── expected_keys.yaml          # Main keys for production
├── dev_keys.yaml              # Development-only keys
├── test_keys.yaml             # Test-specific keys
└── generated_keys.yaml        # Auto-generated reference
```

### 2. **CI Strategy**

- Use basic validation on feature branches
- Use strict mode (`--strict --fail-on-extra`) on main/develop
- Generate reports for pull requests
- Auto-update keys on main branch pushes

### 3. **Configuration Management**

```yaml
# .flutter_keycheck.yaml for different environments
keys: keys/expected_keys.yaml
path: .
strict: false # Lenient for development
verbose: true # Detailed feedback
fail_on_extra: false # Don't fail on experimental keys
```

### 4. **Key Naming Conventions**

```yaml
keys:
  # Screen-based naming
  - login_screen_email_field
  - login_screen_password_field
  - login_screen_submit_button

  # Component-based naming
  - user_profile_avatar
  - user_profile_name_text
  - user_profile_edit_button

  # Action-based naming
  - save_document_action
  - delete_item_action
  - refresh_data_action
```

## 🔍 Troubleshooting

### Common Issues

**Issue**: `keys parameter is required`

```bash
# Solution: Provide keys file or create config
flutter_keycheck --keys keys/expected_keys.yaml
# OR
echo "keys: keys/expected_keys.yaml" > .flutter_keycheck.yaml
```

**Issue**: `Keys file does not exist`

```bash
# Solution: Generate keys from existing project
flutter_keycheck --generate-keys > keys/expected_keys.yaml
```

**Issue**: `No ValueKeys found in project`

```bash
# Solution: Check your search path
flutter_keycheck --generate-keys --path lib --verbose
```

### Debug Mode

```bash
# Enable verbose output for debugging
flutter_keycheck --verbose

# Check configuration loading
flutter_keycheck --config my_config.yaml --verbose
```

## 📝 Examples

Check the `example/` directory for:

- Sample Flutter app with ValueKeys
- Configuration file examples
- Expected keys file format
- CI workflow examples

🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤️ for Flutter developers who want reliable automation testing
