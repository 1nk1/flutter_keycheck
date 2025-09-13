#!/bin/bash

# Test the validate command workflow

set -e  # Exit on error

echo "==================================="
echo "Flutter Keycheck Validate Workflow"
echo "==================================="

# Clean up previous runs
echo "→ Cleaning up previous test artifacts..."
rm -rf .flutter_keycheck reports

# Step 1: Create initial baseline using scan
echo ""
echo "→ Step 1: Creating baseline with scan command..."
dart run bin/flutter_keycheck.dart scan \
  --project-root . \
  --output .flutter_keycheck/baseline.json \
  --verbose

# Check if baseline was created
if [ ! -f ".flutter_keycheck/baseline.json" ]; then
  echo "❌ ERROR: Baseline file was not created"
  exit 1
fi

echo "✅ Baseline created successfully"

# Step 2: Run validate against the same codebase (should pass)
echo ""
echo "→ Step 2: Running validate (should pass - no changes)..."
dart run bin/flutter_keycheck.dart validate \
  --baseline .flutter_keycheck/baseline.json \
  --fail-on-lost \
  --protected-tags aqa \
  --verbose

echo "✅ Validation passed (no changes detected)"

# Step 3: Create a test file with a key that has the 'aqa' tag
echo ""
echo "→ Step 3: Creating test file with protected key..."
mkdir -p test_workspace
cat > test_workspace/test_widget.dart << 'EOF'
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('aqa_test_key'), // Protected key with 'aqa' tag
      child: Text('Test'),
    );
  }
}
EOF

# Step 4: Scan again to create new baseline with the protected key
echo ""
echo "→ Step 4: Creating new baseline with protected key..."
dart run bin/flutter_keycheck.dart scan \
  --project-root . \
  --output .flutter_keycheck/baseline_with_protected.json \
  --verbose

# Step 5: Remove the test file (simulating lost key)
echo ""
echo "→ Step 5: Removing test file (simulating lost protected key)..."
rm -rf test_workspace

# Step 6: Run validate with fail-on-lost and protected-tags (should fail)
echo ""
echo "→ Step 6: Running validate with lost protected key (should fail)..."
set +e  # Don't exit on error for this test
dart run bin/flutter_keycheck.dart validate \
  --baseline .flutter_keycheck/baseline_with_protected.json \
  --fail-on-lost \
  --protected-tags aqa \
  --verbose

EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "❌ ERROR: Validation should have failed due to lost protected key"
  exit 1
else
  echo "✅ Validation correctly failed due to lost protected key (exit code: $EXIT_CODE)"
fi

# Step 7: Test with different policy flags
echo ""
echo "→ Step 7: Testing various policy configurations..."

# Test without fail-on-lost (should pass)
echo "  • Testing without --fail-on-lost..."
dart run bin/flutter_keycheck.dart validate \
  --baseline .flutter_keycheck/baseline.json \
  --protected-tags aqa \
  --verbose

echo "  ✅ Passed without --fail-on-lost"

# Test with fail-on-extra
echo "  • Testing with --fail-on-extra..."
set +e
dart run bin/flutter_keycheck.dart validate \
  --baseline .flutter_keycheck/baseline.json \
  --fail-on-extra \
  --verbose
set -e
echo "  ✅ Completed --fail-on-extra test"

# Generate reports
echo ""
echo "→ Step 8: Generating validation reports..."
dart run bin/flutter_keycheck.dart validate \
  --baseline .flutter_keycheck/baseline.json \
  --report json \
  --report junit \
  --report md \
  --verbose

# Check reports
echo ""
echo "→ Checking generated reports..."
ls -la reports/validation-report.*

echo ""
echo "==================================="
echo "✅ All validation tests completed!"
echo "==================================="
echo ""
echo "Summary:"
echo "  • Baseline creation: ✅"
echo "  • Validation with no changes: ✅"
echo "  • Protected key detection: ✅"
echo "  • Policy enforcement: ✅"
echo "  • Report generation: ✅"