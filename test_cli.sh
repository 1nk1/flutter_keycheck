#!/bin/bash
set -e

echo "Testing Flutter KeyCheck CLI"
echo "============================"

# Create a simple test directory
mkdir -p test_workspace
cd test_workspace

# Create a simple Dart file with keys
cat > main.dart << 'EOF'
// Test file with keys
class TestWidget {
  final key = const ValueKey('test_key');
  final button = ElevatedButton(
    key: const ValueKey('button_key'),
  );
}

// Mock classes
class ValueKey {
  const ValueKey(this.value);
  final String value;
}

class ElevatedButton {
  const ElevatedButton({this.key});
  final ValueKey? key;
}
EOF

# Test commands
echo "Testing scan command..."
dart ../bin/flutter_keycheck.dart scan --report json

echo "Testing baseline command..."
dart ../bin/flutter_keycheck.dart baseline create

echo "Testing validate command..."
# Create threshold file first
cat > coverage-thresholds.yaml << 'EOF'
version: 1
thresholds:
  file_coverage: 0.8
  widget_coverage: 0.7
EOF
dart ../bin/flutter_keycheck.dart validate || true

echo "Testing diff command..."
dart ../bin/flutter_keycheck.dart diff

echo "Testing report command..."
dart ../bin/flutter_keycheck.dart report --format json

echo "Testing version..."
dart ../bin/flutter_keycheck.dart --version

echo "Testing help..."
dart ../bin/flutter_keycheck.dart --help

# Cleanup
cd ..
rm -rf test_workspace

echo "============================"
echo "CLI tests completed!"