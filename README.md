# Flutter Key Integration Validator

[![pub package](https://img.shields.io/pub/v/flutter_keycheck.svg)](https://pub.dev/packages/flutter_keycheck)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.2%2B-blue.svg)](https://dart.dev)

A CLI tool to validate Flutter automation keys and integration test dependencies. Ensures your Flutter app is ready for automated testing with proper key coverage.

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

2. **Run the validator:**

```bash
flutter_keycheck --keys expected_keys.yaml
```

## 📋 Usage

### Basic Usage

```bash
# Check keys in current directory
flutter_keycheck --keys expected_keys.yaml

# Check specific project path
flutter_keycheck --keys keys/production.yaml --path ./my_flutter_app

# Strict mode (fail on extra keys)
flutter_keycheck --keys expected_keys.yaml --strict

# Verbose output
flutter_keycheck --keys expected_keys.yaml --verbose
```

### Command Line Options

| Option      | Short | Description                                          | Default      |
| ----------- | ----- | ---------------------------------------------------- | ------------ |
| `--keys`    | `-k`  | Path to keys file (.yaml)                            | **required** |
| `--path`    | `-p`  | Project source root                                  | `.`          |
| `--strict`  | `-s`  | Fail if integration_test/appium_test.dart is missing | `false`      |
| `--verbose` | `-v`  | Show detailed output                                 | `false`      |
| `--help`    | `-h`  | Show help message                                    | -            |

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

2. Create integration_test/appium_test.dart:

```dart
import 'package:appium_flutter_server/appium_flutter_server.dart';
import 'package:your_app/main.dart';

void main() {
  initializeTest(app: const MyApp());
}
```

3. Build your app for testing:

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
