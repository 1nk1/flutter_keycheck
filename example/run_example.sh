#!/bin/bash

echo "🎯 Flutter KeyCheck Example"
echo "=========================="
echo ""

# Check if flutter_keycheck is installed
if ! command -v flutter_keycheck &> /dev/null; then
    echo "❌ flutter_keycheck is not installed globally"
    echo "💡 Install it with: dart pub global activate flutter_keycheck"
    exit 1
fi

echo "✅ flutter_keycheck is installed"
echo ""

# Run the validation
echo "🔍 Running key validation..."
echo "Command: flutter_keycheck --keys expected_keys.yaml --path sample_flutter_app --verbose"
echo ""

flutter_keycheck --keys expected_keys.yaml --path sample_flutter_app --verbose

echo ""
echo "📝 This example demonstrates how flutter_keycheck works:"
echo "   • It scans sample_flutter_app/ for ValueKey usage"
echo "   • Compares found keys with expected_keys.yaml"
echo "   • Reports missing keys, extra keys, and dependency status"
