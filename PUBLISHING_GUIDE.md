# Publishing Guide for flutter_keycheck v2.1.7

## Current Status

✅ **Version 2.1.7 prepared and ready**
✅ **All validation checks passed**
✅ **GitHub Actions workflows updated**
✅ **Documentation enhanced with CI/CD examples**
✅ **prepublish validator created**

❌ **Waiting for pub.dev rate limit reset (12 publications/day exceeded)**

## When Rate Limit Resets

### Option 1: Automatic Publishing (Recommended)

```bash
# Push the tag to trigger GitHub Actions publishing
git push origin v2.1.7
```

This will automatically:

- Run all tests
- Validate the package
- Publish to pub.dev via OIDC (no manual tokens needed)

### Option 2: Manual Publishing

```bash
# Final validation
dart bin/prepublish.dart

# Dry run check
dart pub publish --dry-run

# Publish
dart pub publish
```

## Pre-publish Checklist

Run this before publishing:

```bash
# 1. Validate everything is ready
dart bin/prepublish.dart

# 2. Run tests
dart test

# 3. Check formatting
dart format --output=none --set-exit-if-changed .

# 4. Analyze code
dart analyze --fatal-infos

# 5. Dry run publish
dart pub publish --dry-run
```

## What's New in v2.1.7

- ✅ Added prepublish validator (`bin/prepublish.dart`)
- ✅ Enhanced GitHub Actions with validate-publish workflow
- ✅ Expanded README with comprehensive CI/CD examples
- ✅ Added pub.dev badges and GitHub Actions badge
- ✅ Ready for publishing after rate limit reset

## Rate Limit Info

- **Current limit**: 12 publications per day per publisher
- **Reset time**: ~24 hours from first publication attempt
- **Check status**: Monitor GitHub Actions or try `dart pub publish --dry-run`

## Post-Publication Tasks

After successful publication:

1. ✅ Verify package appears on [pub.dev](https://pub.dev/packages/flutter_keycheck)
2. ✅ Check that all links work correctly
3. ✅ Update global installation: `dart pub global activate flutter_keycheck`
4. ✅ Test the published version works as expected
5. ✅ Consider preparing next version if needed

## Emergency Fixes

If something goes wrong after publishing:

1. **Fix the issue** in code
2. **Bump version** (e.g., 2.1.8)
3. **Update CHANGELOG.md**
4. **Wait for rate limit** if needed
5. **Republish**

## Contact

- GitHub Issues: <https://github.com/1nk1/flutter_keycheck/issues>
- Repository: <https://github.com/1nk1/flutter_keycheck>
