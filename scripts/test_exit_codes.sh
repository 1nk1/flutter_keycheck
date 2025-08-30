#!/bin/bash
# Test exit codes for v3.0.0-rc.1

echo "Testing Exit Codes for flutter_keycheck v3.0.0-rc.1"
echo "===================================================="

# Test 0: Success
echo "Test: --version should return 0"
dart run bin/flutter_keycheck.dart --version
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && echo "✅ Exit code 0 (success)" || echo "❌ Expected 0, got $EXIT_CODE"

# Test 1: Policy violation (validate without baseline)
echo -e "\nTest: validate without baseline should return 1 or 2"
dart run bin/flutter_keycheck.dart validate 2>/dev/null
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ] || [ $EXIT_CODE -eq 2 ]; then
    echo "✅ Exit code $EXIT_CODE (policy/config error)"
else
    echo "❌ Expected 1 or 2, got $EXIT_CODE"
fi

# Test 2: Config error (invalid config file)
echo -e "\nTest: invalid config should return 2"
echo "invalid: yaml: {{{" > bad_config.yaml
dart run bin/flutter_keycheck.dart --config bad_config.yaml scan 2>/dev/null
EXIT_CODE=$?
[ $EXIT_CODE -eq 2 ] && echo "✅ Exit code 2 (config error)" || echo "⚠️ Expected 2, got $EXIT_CODE"
rm -f bad_config.yaml

# Test 3: Help should return 0
echo -e "\nTest: --help should return 0"
dart run bin/flutter_keycheck.dart --help >/dev/null
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && echo "✅ Exit code 0 (help)" || echo "❌ Expected 0, got $EXIT_CODE"

echo -e "\n===================================================="
echo "Exit code testing complete"