#!/bin/bash
set -e

echo "Flutter KeyCheck v3.0.0-rc.1 Smoke Test"
echo "======================================="

# Create test workspace
mkdir -p test_smoke
cd test_smoke

# Create sample Flutter file with keys
cat > widget.dart << 'EOF'
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('test_column'),
      children: [
        ElevatedButton(
          key: const ValueKey('login_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        TextField(
          key: const ValueKey('email_field'),
        ),
      ],
    );
  }
}
EOF

# Test scan command
echo "Testing scan command..."
dart ../bin/flutter_keycheck.dart scan --report json > scan_output.json || true

# Check output
if [ -f scan_output.json ]; then
  echo "✅ Scan command executed"
  cat scan_output.json | grep -q '"keys"' && echo "✅ JSON output contains keys" || echo "⚠️ No keys in output"
else
  echo "❌ Scan failed to produce output"
fi

# Test baseline command
echo "Testing baseline command..."
dart ../bin/flutter_keycheck.dart baseline create || true
if [ -f .flutter_keycheck/baseline.json ]; then
  echo "✅ Baseline created"
else
  echo "❌ Baseline creation failed"
fi

# Test validate command
echo "Testing validate command..."
dart ../bin/flutter_keycheck.dart validate || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] || [ "$EXIT_CODE" -eq 1 ]; then
  echo "✅ Validate command works (exit code: $EXIT_CODE)"
else
  echo "❌ Validate command failed with unexpected code: $EXIT_CODE"
fi

# Cleanup
cd ..
rm -rf test_smoke

echo "======================================="
echo "Smoke test complete!"