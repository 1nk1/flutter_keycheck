# Contributing to Flutter KeyCheck

Thank you for your interest in contributing to Flutter KeyCheck! This document provides guidelines for contributions.

## 🚀 Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/flutter_keycheck.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `dart test`
6. Submit a pull request

## 📝 Development Setup

```bash
# Install dependencies
dart pub get

# Run tests
dart test

# Check formatting
dart format --output=none --set-exit-if-changed .

# Analyze code
dart analyze --fatal-infos

# Run the CLI locally
dart run bin/flutter_keycheck.dart --help
```

## 🔄 Version Policy

We follow [Semantic Versioning](https://semver.org/):

### Version Format: MAJOR.MINOR.PATCH

- **MAJOR** (X.0.0): Breaking changes
  - Removing CLI flags or changing their behavior
  - Changing JSON output structure
  - Requiring newer Dart SDK version
  - Example: Removing `--strict` flag or changing its default behavior

- **MINOR** (0.X.0): New features (backward compatible)
  - Adding new CLI flags
  - Adding new fields to JSON output
  - Supporting new key patterns
  - Example: Adding `--validate-key-constants` flag

- **PATCH** (0.0.X): Bug fixes (backward compatible)
  - Fixing incorrect key detection
  - Improving error messages
  - Performance optimizations
  - Example: Fixing regex pattern for KeyConstants detection

### Version Checklist

Before releasing a new version:

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md` with release notes
3. Run all tests: `dart test`
4. Verify package: `dart pub publish --dry-run`
5. Create git tag: `git tag v{version}`
6. Push tag: `git push origin v{version}`

## 🎯 Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` before committing
- Keep line length under 80 characters where practical
- Write descriptive commit messages

## ✅ Testing

- Write tests for new features
- Maintain or improve code coverage
- Test files go in `test/` directory
- Use descriptive test names

Example test structure:
```dart
void main() {
  group('KeyChecker', () {
    test('should detect ValueKey patterns', () {
      // Test implementation
    });
    
    test('should handle KeyConstants patterns', () {
      // Test implementation
    });
  });
}
```

## 🐛 Reporting Issues

When reporting issues, please include:
- Flutter KeyCheck version (`flutter_keycheck --version`)
- Dart SDK version (`dart --version`)
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Sample code or configuration if applicable

## 💡 Feature Requests

Feature requests are welcome! Please:
- Check existing issues first
- Describe the use case
- Explain why it would be useful
- Provide examples if possible

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🤝 Code of Conduct

Please be respectful and constructive in all interactions. We aim to maintain a welcoming environment for all contributors.

## 📮 Contact

- GitHub Issues: [github.com/1nk1/flutter_keycheck/issues](https://github.com/1nk1/flutter_keycheck/issues)
- Package Page: [pub.dev/packages/flutter_keycheck](https://pub.dev/packages/flutter_keycheck)