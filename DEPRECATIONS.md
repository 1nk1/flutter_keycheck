# Deprecations & Migration Guide

## v3.0.0 Deprecations

### Removed Binaries (Effective: v3.0.0-rc.1)

The following legacy binaries have been **permanently removed**:

| Removed File | Migration Path | EOL Date |
|--------------|----------------|----------|
| `bin/flutter_keycheck_v2.dart` | Use `bin/flutter_keycheck.dart` | 2025-01-16 |
| `bin/flutter_keycheck_v3.dart` | Use `bin/flutter_keycheck.dart` | 2025-01-16 |
| `bin/flutter_keycheck_v3_complete.dart` | Use `bin/flutter_keycheck.dart` | 2025-01-16 |
| `bin/flutter_keycheck_v3_integrated.dart` | Use `bin/flutter_keycheck.dart` | 2025-01-16 |
| `bin/flutter_keycheck_v3_proper.dart` | Use `bin/flutter_keycheck.dart` | 2025-01-16 |

### CLI Command Migration

| v2.x Command | v3.0 Command | Notes |
|--------------|--------------|-------|
| `flutter_keycheck --keys file.yaml` | `flutter_keycheck validate` | Primary validation command |
| `flutter_keycheck --generate-keys` | `flutter_keycheck scan --report yaml` | Generate keys file |
| `flutter_keycheck --strict` | `flutter_keycheck validate --strict` | Strict mode validation |
| `flutter_keycheck --verbose` | `flutter_keycheck --verbose <command>` | Global flag before command |
| `flutter_keycheck --json` | `flutter_keycheck scan --report json` | JSON output |

### Configuration Changes

| v2.x Config | v3.0 Config | Notes |
|-------------|-------------|-------|
| `expected_keys_file` | Removed | Use `--baseline` or registry |
| `percentage_threshold` | `coverage_threshold` | Now fraction [0,1] not percentage |
| N/A | `schema_version: 1.0` | Required in v3 configs |

### API Changes

| v2.x API | v3.0 API | Migration |
|----------|----------|-----------|
| `KeyChecker.checkKeys()` | `KeyChecker.scan()` | Returns `ScanResult` not bool |
| `Config.fromFile()` | `ConfigLoader.load()` | New config system |
| `generateKeysYaml()` | `Reporter.generate()` | Multi-format support |

## Downstream Repository Updates

If you have scripts or CI/CD pipelines using flutter_keycheck, update them by **2025-02-01**:

### GitHub Actions
```yaml
# Old
- run: dart run bin/flutter_keycheck_v3.dart --keys expected.yaml

# New
- run: flutter_keycheck validate --baseline expected.yaml
```

### GitLab CI
```yaml
# Old
script:
  - dart bin/flutter_keycheck_v2.dart --strict

# New
script:
  - flutter_keycheck validate --strict
```

### Shell Scripts
```bash
# Old
#!/bin/bash
dart run bin/flutter_keycheck_v3.dart scan

# New
#!/bin/bash
flutter_keycheck scan
```

## Support Timeline

- **v2.x branch**: Archived (read-only) as of 2025-01-16
- **v3.0.0-rc.1**: Testing phase until GA
- **v3.0.0 GA**: Full support starting ~2025-01-23
- **Migration deadline**: 2025-02-01 for all downstream repos

## Getting Help

- Migration issues: https://github.com/1nk1/flutter_keycheck/issues
- Documentation: https://github.com/1nk1/flutter_keycheck/blob/main/README.md
- Examples: See `smoke_test.sh` and `test_exit_codes.sh`