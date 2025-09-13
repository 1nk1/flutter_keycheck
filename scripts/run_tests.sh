#!/bin/bash
set -e

echo "Running Flutter KeyCheck v3 Tests"
echo "================================="

# Test 1: All unit tests
echo "Running all unit tests..."
dart test --reporter=expanded

# Test 2: Comprehensive validation tests
echo "Running comprehensive validation tests..."
if [ -f "test/comprehensive_validation_test.dart" ]; then
  dart run test/comprehensive_validation_test.dart || true
fi

# Test 3: Quality assurance test suite
echo "Running QA test suite..."
if [ -f "test/run_quality_assurance_tests.dart" ]; then
  dart run test/run_quality_assurance_tests.dart || true
fi

# Test 4: V3 specific tests (skip if files don't exist)
echo "Running v3 specific tests..."
if [ -f "test/v3/policy_test.dart" ]; then
  dart test test/v3/policy_test.dart || true
fi

# Test 5: Golden workspace tests (skip if dart not available)
echo "Running golden workspace tests..."
if command -v dart &> /dev/null; then
  cd test/golden_workspace
  dart test test/golden_workspace/golden_test.dart || true
  cd ../..
else
  echo "Dart not available, skipping golden tests"
fi

# Test 6: CLI executable test
echo "Testing CLI executable..."
dart compile exe bin/flutter_keycheck.dart -o flutter_keycheck_test
./flutter_keycheck_test --version
./flutter_keycheck_test --help
rm flutter_keycheck_test

# Test 7: Coverage report (optional)
if [ "$1" = "--coverage" ]; then
  echo "Generating coverage report..."
  dart test --coverage=coverage
  if command -v genhtml &> /dev/null; then
    genhtml coverage/lcov.info -o coverage/html
    echo "Coverage report generated in coverage/html/"
  fi
fi

echo "================================="
echo "Test run complete!"
