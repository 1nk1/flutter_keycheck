# 🎯 Flutter KeyCheck: AQA/E2E Tagging Examples

## 📖 Overview

This document demonstrates how to use Flutter KeyCheck with AQA (Automated Quality Assurance) and E2E (End-to-End) tagging for effective test automation.

## 🏷️ Tagging Strategy

### AQA Tags (`aqa_*`)

- **Purpose**: General UI testing, validation, regression testing
- **Scope**: All testable UI elements
- **Example**: `aqa_email_field`, `aqa_submit_button`, `aqa_error_message`

### E2E Tags (`e2e_*`)

- **Purpose**: Critical user journeys, smoke testing
- **Scope**: Key business process elements only
- **Example**: `e2e_login_flow`, `e2e_checkout_process`, `e2e_payment_button`

## 🎨 Code Examples

### Login Screen with Tags

```dart
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('aqa_login_app_bar'),
        title: const Text('Login'),
      ),
      body: Column(
        children: [
          // AQA: General UI testing
          TextField(
            key: const ValueKey('aqa_email_field'),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            key: const ValueKey('aqa_password_field'),
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
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
      ),
    );
  }
}
```

### Dashboard with Navigation Tags

```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('e2e_dashboard_app_bar'),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            key: const ValueKey('aqa_profile_button'),
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          // AQA: UI component testing
          _buildCard('aqa_orders_card', 'Orders', Icons.list),
          _buildCard('aqa_products_card', 'Products', Icons.inventory),

          // E2E: Critical business actions
          _buildCard('e2e_checkout_card', 'Checkout', Icons.shopping_cart),
          _buildCard('e2e_payment_card', 'Payments', Icons.payment),
        ],
      ),
    );
  }

  Widget _buildCard(String key, String title, IconData icon) {
    return Card(
      key: ValueKey(key),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          Text(title),
        ],
      ),
    );
  }
}
```

## ⚙️ Configuration Examples

### AQA Configuration

```yaml
# .flutter_keycheck_aqa.yaml
keys: keys/aqa_keys.yaml
path: .
strict: false
verbose: true
fail_on_extra: false

include_only:
  - aqa_

exclude:
  - debug_
  - temp_

tracked_keys:
  - aqa_email_field
  - aqa_password_field
  - aqa_error_message_container
```

### E2E Configuration

```yaml
# .flutter_keycheck_e2e.yaml
keys: keys/e2e_keys.yaml
path: .
strict: true
verbose: true
fail_on_extra: true

include_only:
  - e2e_

tracked_keys:
  - e2e_login_submit_button
  - e2e_dashboard_app_bar
  - e2e_checkout_card
```

## 🚀 Usage Commands

### Generate Keys by Tags

```bash
# Generate AQA keys only
flutter_keycheck --generate-keys --include-only="aqa_" > keys/aqa_keys.yaml

# Generate E2E keys only
flutter_keycheck --generate-keys --include-only="e2e_" > keys/e2e_keys.yaml

# Generate with exclusions
flutter_keycheck --generate-keys --exclude="debug_,temp_" > keys/clean_keys.yaml
```

### Validate with Configurations

```bash
# AQA validation (lenient for development)
flutter_keycheck --config .flutter_keycheck_aqa.yaml

# E2E validation (strict for production)
flutter_keycheck --config .flutter_keycheck_e2e.yaml --strict

# JSON output for CI/CD
flutter_keycheck --config .flutter_keycheck_e2e.yaml --report json
```

## 📊 Example Reports

### AQA Validation Report

```json
{
  "timestamp": "2025-06-23T10:31:18.128517",
  "summary": {
    "total_expected_keys": 15,
    "found_keys": 13,
    "missing_keys": 2,
    "validation_passed": false
  },
  "missing_keys": ["aqa_email_field", "aqa_error_message_container"],
  "tracked_keys": ["aqa_email_field", "aqa_password_field", "aqa_error_message_container"]
}
```

### E2E Validation Report

```json
{
  "timestamp": "2025-06-23T10:31:18.128517",
  "summary": {
    "total_expected_keys": 5,
    "found_keys": 5,
    "missing_keys": 0,
    "validation_passed": true
  },
  "found_keys": {
    "e2e_login_submit_button": ["lib/login_screen.dart:42"],
    "e2e_dashboard_app_bar": ["lib/dashboard_screen.dart:12"],
    "e2e_checkout_card": ["lib/dashboard_screen.dart:28"]
  }
}
```

## 🔧 CI/CD Integration

### GitHub Actions Example

```yaml
name: Key Validation

on: [push, pull_request]

jobs:
  validate-keys:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1

      - name: Install Flutter KeyCheck
        run: dart pub global activate flutter_keycheck

      - name: Validate AQA Keys
        run: flutter_keycheck --config .flutter_keycheck_aqa.yaml --report json > aqa_report.json

      - name: Validate E2E Keys (Critical)
        run: flutter_keycheck --config .flutter_keycheck_e2e.yaml --strict --report json > e2e_report.json

      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: key-validation-reports
          path: |
            aqa_report.json
            e2e_report.json
```

## 🎯 Best Practices

### 1. Tagging Guidelines

- **AQA tags**: Use for all UI elements that need testing
- **E2E tags**: Use only for critical business flows
- **Consistency**: Use consistent naming patterns
- **Prefixes**: Consider screen-based prefixes: `aqa_login_`, `e2e_checkout_`

### 2. Team Workflows

- **QA Team**: Focus on AQA configuration for comprehensive testing
- **DevOps Team**: Use E2E configuration for smoke tests and monitoring
- **Developers**: Validate both before commits

### 3. Configuration Management

- **Development**: Use lenient AQA configuration
- **Staging**: Use strict E2E configuration
- **Production**: Monitor with E2E critical keys only

## 🛠️ Automation Scripts

### Key Generation Script

```bash
#!/bin/bash
# generate_keys.sh

echo "🔄 Generating test keys..."

# AQA keys for comprehensive testing
flutter_keycheck --generate-keys --include-only="aqa_" > keys/aqa_keys.yaml
echo "✅ AQA keys generated"

# E2E keys for critical flows
flutter_keycheck --generate-keys --include-only="e2e_" > keys/e2e_keys.yaml
echo "✅ E2E keys generated"

# Validation reports
flutter_keycheck --config .flutter_keycheck_aqa.yaml --report json > reports/aqa_report.json
flutter_keycheck --config .flutter_keycheck_e2e.yaml --report json > reports/e2e_report.json

echo "🎉 Key generation complete!"
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "🔍 Validating keys before commit..."

# Check critical E2E keys
if ! flutter_keycheck --config .flutter_keycheck_e2e.yaml --strict; then
    echo "❌ Critical E2E key validation failed!"
    exit 1
fi

echo "✅ Key validation passed!"
```

## 📈 Monitoring and Metrics

### Key Coverage Tracking

```bash
# Check AQA coverage
flutter_keycheck --config .flutter_keycheck_aqa.yaml --report json | jq '.summary.validation_passed'

# Monitor E2E critical keys
flutter_keycheck --config .flutter_keycheck_e2e.yaml --report json | jq '.summary.found_keys'

# Track missing keys
flutter_keycheck --config .flutter_keycheck_e2e.yaml --report json | jq '.missing_keys | length'
```

---

**Flutter KeyCheck v2.2.0** - Making Flutter testing more organized and reliable! 🚀
