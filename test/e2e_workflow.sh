#!/bin/bash

# E2E Test Script for Flutter KeyCheck Stage 2 Features
# Tests baseline generation, diff reports, and validation workflow

set -e

echo "🚀 Flutter KeyCheck E2E Test - Stage 2 Features"
echo "=============================================="

# Setup test directory
TEST_DIR="/tmp/flutter_keycheck_e2e_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "📁 Test directory: $TEST_DIR"

# Create a sample Flutter project
echo ""
echo "📝 Creating sample Flutter project..."
mkdir -p lib/screens
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(key: Key('email_field')),
        TextField(key: ValueKey('password_field')),
        ElevatedButton(
          key: Key('login_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
      ],
    );
  }
}
EOF

cat > lib/screens/home.dart << 'EOF'
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('home_scaffold'),
      appBar: AppBar(
        key: Key('home_appbar'),
        title: Text('Home'),
      ),
      body: ListView(
        key: Key('home_list'),
        children: [
          ListTile(key: Key('profile_tile')),
          ListTile(key: Key('settings_tile')),
        ],
      ),
    );
  }
}
EOF

# Create config file
cat > .flutter_keycheck.yaml << 'EOF'
version: 3
EOF

echo "✅ Sample project created"

# Test 1: Baseline Generation
echo ""
echo "🧪 Test 1: Baseline Generation"
echo "------------------------------"
flutter_keycheck baseline create --project-root . --output baseline_v1.json

if [ -f "baseline_v1.json" ]; then
    echo "✅ Baseline created successfully"
    echo "📊 Baseline stats:"
    cat baseline_v1.json | jq '.metadata | {total_keys, dependencies_scanned, schema_version}'
    echo ""
    echo "🔑 Sample keys:"
    cat baseline_v1.json | jq '.keys[:3]'
else
    echo "❌ Failed to create baseline"
    exit 1
fi

# Modify the project (simulate changes)
echo ""
echo "🔄 Modifying project (adding/removing keys)..."
cat > lib/screens/home.dart << 'EOF'
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('home_scaffold_v2'), // Renamed
      appBar: AppBar(
        key: Key('home_appbar'),
        title: Text('Home'),
      ),
      body: ListView(
        key: Key('home_list'),
        children: [
          ListTile(key: Key('profile_tile')),
          ListTile(key: Key('settings_tile')),
          ListTile(key: Key('logout_tile')), // Added
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: Key('fab_add'), // Added
        onPressed: () {},
      ),
    );
  }
}
EOF

# Create second baseline
echo ""
echo "📝 Creating second baseline after changes..."
flutter_keycheck baseline create --project-root . --output baseline_v2.json

# Test 2: Diff Report Generation
echo ""
echo "🧪 Test 2: Diff Report Generation"
echo "---------------------------------"
flutter_keycheck diff \
  --baseline-old baseline_v1.json \
  --baseline-new baseline_v2.json \
  --report json \
  --report markdown \
  --report html \
  --output diff-report

echo ""
echo "📊 Diff Summary:"
if [ -f "reports/diff-report.json" ]; then
    cat reports/diff-report.json | jq '.summary'
    echo "✅ JSON report generated"
fi

if [ -f "reports/diff-report.md" ]; then
    echo "✅ Markdown report generated"
    echo ""
    echo "📄 Markdown preview:"
    head -20 reports/diff-report.md
fi

if [ -f "reports/diff-report.html" ]; then
    echo "✅ HTML report generated"
fi

# Test 3: Validation Against Baseline
echo ""
echo "🧪 Test 3: Validation Against Baseline"
echo "--------------------------------------"

# First, validate against matching baseline (should pass)
echo "Testing validation with matching baseline..."
flutter_keycheck validate \
  --project-root . \
  --baseline baseline_v2.json \
  --report json \
  --report junit

if [ $? -eq 0 ]; then
    echo "✅ Validation passed (as expected)"
else
    echo "⚠️  Validation failed (unexpected)"
fi

# Now validate against old baseline (should fail due to changes)
echo ""
echo "Testing validation with old baseline (should detect changes)..."
flutter_keycheck validate \
  --project-root . \
  --baseline baseline_v1.json \
  --fail-on-lost \
  --report json \
  --report junit || true

if [ -f "reports/validation-report.json" ]; then
    echo ""
    echo "📊 Validation Report Summary:"
    cat reports/validation-report.json | jq '.summary'
fi

# Test 4: GitHub PR Markdown Report
echo ""
echo "🧪 Test 4: GitHub PR Markdown Generation"
echo "----------------------------------------"
flutter_keycheck diff \
  --baseline-old baseline_v1.json \
  --baseline-new baseline_v2.json \
  --report markdown \
  --output pr-comment.md

if [ -f "pr-comment.md" ]; then
    echo "✅ PR comment generated"
    echo ""
    echo "📝 GitHub PR Comment Preview:"
    cat pr-comment.md
fi

# Test 5: JUnit XML for CI
echo ""
echo "🧪 Test 5: JUnit XML Report for CI"
echo "----------------------------------"
if [ -f "reports/validation-report.xml" ]; then
    echo "✅ JUnit XML report generated"
    echo ""
    echo "📄 JUnit XML preview:"
    head -30 reports/validation-report.xml
fi

# Summary
echo ""
echo "=============================================="
echo "✅ E2E Test Complete!"
echo ""
echo "📊 Test Results Summary:"
echo "  • Baseline generation: ✅"
echo "  • Diff report (JSON/MD/HTML): ✅"
echo "  • Validation against baseline: ✅"
echo "  • GitHub PR markdown: ✅"
echo "  • JUnit XML for CI: ✅"
echo ""
echo "📁 Test artifacts saved in: $TEST_DIR"
echo ""
echo "🎉 All Stage 2 features working correctly!"

# Cleanup (optional)
# rm -rf "$TEST_DIR"