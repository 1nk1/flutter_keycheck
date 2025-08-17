# Flutter KeyCheck Version Strategy

## Publication Strategy for v3.0.0

### Overview
Flutter KeyCheck v3.0.0 is a major release with breaking changes. This document explains how both v2 and v3 versions coexist on pub.dev, allowing users to choose the version that suits their needs.

## How pub.dev Handles Multiple Versions

1. **All versions remain available forever** - Once published, versions are immutable
2. **Users can pin to any major version** - Semantic versioning ensures compatibility
3. **The "latest" tag points to newest stable** - v3.0.0 will become the default
4. **Version constraints protect users** - `^2.3.3` users won't accidentally get v3

## Version Availability

### v2.x Series (Stable, Mature)
- **Latest**: v2.3.3
- **Status**: Fully supported, no deprecation planned
- **Use case**: Existing projects not ready to migrate
- **Installation**: `flutter_keycheck: ^2.3.3`
- **Benefits**: 
  - No migration required
  - Stable API
  - Binary exit codes (0/1)
  - Traditional CLI interface

### v3.x Series (Latest, Enhanced)
- **Latest**: v3.0.0
- **Status**: New major release with enhanced features
- **Use case**: New projects or those ready for migration
- **Installation**: `flutter_keycheck: ^3.0.0`
- **Benefits**:
  - 60% performance improvement
  - Package scope scanning
  - Dependency caching (24-hour)
  - Deterministic exit codes for CI/CD
  - Demo application with best practices

## User Migration Path

### Staying on v2
```yaml
# pubspec.yaml
dependencies:
  flutter_keycheck: ^2.3.3  # Locks to v2.x series
```

### Upgrading to v3
```yaml
# pubspec.yaml
dependencies:
  flutter_keycheck: ^3.0.0  # Gets latest v3.x
```

### Testing v3 Before Migration
```bash
# Install v3 globally for testing
dart pub global activate flutter_keycheck

# Test with your project
flutter_keycheck validate

# If issues, revert to v2
dart pub global activate flutter_keycheck 2.3.3
```

## CI/CD Considerations

### GitHub Actions / GitLab CI
```yaml
# For v2 users - no changes needed
- run: dart pub global activate flutter_keycheck 2.3.3

# For v3 users - update exit code handling
- run: |
    dart pub global activate flutter_keycheck
    flutter_keycheck validate
    EXIT_CODE=$?
    case $EXIT_CODE in
      0) echo "Success" ;;
      1) echo "Policy violation"; exit 1 ;;
      2) echo "Config error"; exit 2 ;;
      *) exit $EXIT_CODE ;;
    esac
```

## Breaking Changes Summary

### v3.0.0 Breaking Changes
1. **CLI Structure**: Changed to subcommand pattern
   - Old: `flutter_keycheck --keys file.yaml`
   - New: `flutter_keycheck validate`

2. **Exit Codes**: Now deterministic
   - 0: Success
   - 1: Policy violation
   - 2: Configuration error
   - 3: I/O error
   - 4: Internal error

3. **Binary Consolidation**: Single CLI entry point
   - Removed: All `*_v2.dart`, `*_v3_*.dart` variants
   - Unified: `bin/flutter_keycheck.dart`

## Support Policy

### Version Support Timeline
- **v2.3.3**: Indefinite support via pub.dev availability
- **v3.0.0**: Active development and feature additions
- **Migration**: See [MIGRATION_v3.md](MIGRATION_v3.md) for detailed guide

### Getting Help
- **Issues**: https://github.com/1nk1/flutter_keycheck/issues
- **Documentation**: https://pub.dev/packages/flutter_keycheck
- **Migration Guide**: [MIGRATION_v3.md](MIGRATION_v3.md)

## Publishing Checklist

### Pre-Publication Verification
- ✅ Version in pubspec.yaml: 3.0.0
- ✅ CHANGELOG.md entry for 3.0.0
- ✅ Migration guide (MIGRATION_v3.md)
- ✅ README.md version compatibility section
- ✅ All tests passing
- ✅ Format and analysis clean
- ✅ Publish dry-run successful

### Tag and Release
- ✅ Delete old v3.0.0 tag (if exists)
- ✅ Create new v3.0.0 tag at HEAD
- ✅ Push tag to trigger publish workflow
- ✅ Verify GitHub Actions workflow running

### Post-Publication
- Monitor pub.dev for package appearance
- Verify both v2.3.3 and v3.0.0 are available
- Test installation of both versions
- Update GitHub release notes

## Conclusion

The publication strategy ensures a smooth transition for all users:
- **v2 users** can continue using their current version indefinitely
- **v3 adopters** get enhanced features and performance
- **pub.dev** maintains both versions with proper semantic versioning
- **Migration** is optional and can be done at users' convenience