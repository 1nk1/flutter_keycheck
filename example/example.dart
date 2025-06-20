#!/usr/bin/env dart
// Example usage of flutter_keycheck CLI tool
// This demonstrates how to use flutter_keycheck to validate automation keys

void main() async {
  print('Flutter KeyCheck Example');
  print('=======================');

  // Example 1: Basic validation
  print('\n1. Basic key validation:');
  print('   flutter_keycheck --keys keys/expected_keys.yaml');

  // Example 2: Generate keys
  print('\n2. Generate keys from project:');
  print('   flutter_keycheck --generate-keys > keys/generated_keys.yaml');

  // Example 3: Advanced filtering
  print('\n3. Filter keys for QA automation:');
  print('   flutter_keycheck --generate-keys --include-only="qa_,e2e_"');

  // Example 4: Strict validation
  print('\n4. Strict validation for CI/CD:');
  print(
      '   flutter_keycheck --keys keys/expected_keys.yaml --strict --fail-on-extra');

  print('\nFor more examples, see: https://pub.dev/packages/flutter_keycheck');
}
