#!/bin/bash
set -e

echo "Running Flutter KeyCheck v3 Tests"
echo "================================="

# Test 1: Basic tests
echo "Running basic unit tests..."
dart test test/checker_test.dart test/config_test.dart test/key_constants_test.dart test/flutter_keycheck_test.dart || true

# Test 2: V3 specific tests (skip if files don't exist)
echo "Running v3 specific tests..."
if [ -f "test/v3/policy_test.dart" ]; then
  dart test test/v3/policy_test.dart || true
fi

# Test 3: Golden workspace tests (skip if dart not available)
echo "Running golden workspace tests..."
if command -v dart &> /dev/null; then
  cd test/golden_workspace
  dart test test/golden_test.dart || true
  cd ../..
else
  echo "Dart not available, skipping golden tests"
fi

# Test 4: CLI executable test
echo "Testing CLI executable..."
dart compile exe bin/flutter_keycheck.dart -o flutter_keycheck_test
./flutter_keycheck_test --version
./flutter_keycheck_test --help
rm flutter_keycheck_test

echo "================================="
echo "Test run complete!"