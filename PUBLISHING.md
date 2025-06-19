# 📦 Publishing Guide for flutter_keycheck

This document contains step-by-step instructions for publishing the `flutter_keycheck` package to pub.dev.

## 🚀 Pre-Publishing Checklist

### ✅ Code Quality

- [ ] All tests pass: `dart test`
- [ ] Code is properly formatted: `dart format .`
- [ ] No linting issues: `dart analyze`
- [ ] Documentation is complete and accurate

### ✅ Package Configuration

- [ ] `pubspec.yaml` has correct version number
- [ ] All URLs in `pubspec.yaml` are correct and accessible
- [ ] `CHANGELOG.md` is updated with new version
- [ ] `README.md` has current examples and badges
- [ ] `LICENSE` file is present

### ✅ Testing

- [ ] Unit tests cover core functionality
- [ ] Example project works correctly
- [ ] CLI tool works as expected: `dart run bin/flutter_keycheck.dart --keys example/expected_keys.yaml`

## 🔧 Publishing Steps

### 1. Final Validation

```bash
# Run all tests
dart test

# Check formatting
dart format --set-exit-if-changed .

# Analyze code
dart analyze --fatal-infos

# Test the CLI
dart run bin/flutter_keycheck.dart --keys example/expected_keys.yaml --path example --verbose
```

### 2. Dry Run

```bash
# This will validate everything without actually publishing
dart pub publish --dry-run
```

**Expected output should show:**

- ✅ Package validation passed
- ✅ All required files are included
- ✅ No warnings or errors

### 3. Authenticate with pub.dev

```bash
# Login to pub.dev (will open browser)
dart pub login
```

**Requirements:**

- Use Gmail account: `1nk1.dev@gmail.com`
- Ensure you have publishing rights

### 4. Publish the Package

```bash
# Final publish command
dart pub publish
```

**This will:**

- Upload the package to pub.dev
- Make it available for `dart pub global activate flutter_keycheck`
- Update the pub.dev listing

## 📋 Post-Publishing Tasks

### 1. Verify Publication

- [ ] Check package appears on [pub.dev/packages/flutter_keycheck](https://pub.dev/packages/flutter_keycheck)
- [ ] Test installation: `dart pub global activate flutter_keycheck`
- [ ] Test CLI works: `flutter_keycheck --help`

### 2. Update Repository

- [ ] Create and push Git tag: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] Create GitHub release with changelog
- [ ] Update any documentation that references the package

### 3. Announce Release

- [ ] Update README badges to show published version
- [ ] Share on relevant Flutter/Dart communities
- [ ] Consider writing a blog post about the tool

## 🐛 Troubleshooting

### Common Issues

**\_"\_"Package validation failed"\_\_**

- Check all required fields in `pubspec.yaml`
- Ensure all URLs are accessible
- Verify LICENSE file exists

**\*"Authentication failed"\***

- Run `dart pub logout` then `dart pub login`
- Ensure using the correct Gmail account
- Check internet connection

\*_"Version already exists"_\*

- Update version in `pubspec.yaml`
- Follow semantic versioning (major.minor.patch)
- Update `CHANGELOG.md` with new version

\*\*"\Analysis issues found"\*\*

- Run `dart analyze` and fix all issues
- Check that all imports are correct
- Ensure no unused variables or imports

## 📞 Support

If you encounter issues during publishing:

1. Check the [pub.dev publishing guide](https://dart.dev/tools/pub/publishing)
2. Review [pub.dev policy](https://pub.dev/policy)
3. Check [GitHub Issues](https://github.com/1nk1/flutter_keycheck/issues)

## 🔄 Version Management

### Semantic Versioning

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.0.1): Bug fixes, backwards compatible

### Release Process

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Commit changes: `git commit -m "Release v1.0.0"`
4. Create tag: `git tag v1.0.0`
5. Push: `git push origin main --tags`
6. Publish: `dart pub publish`

---

Ready to publish? Follow the steps above and make flutter_keycheck available to the Flutter community! 🚀
