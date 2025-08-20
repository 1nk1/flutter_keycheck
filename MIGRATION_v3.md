# Migration Guide: v2 to v3

This guide covers the breaking changes in flutter_keycheck v3.0.0.

## 🚨 Critical Change: Exit Code Contract

### v2.x Exit Codes (Non-deterministic)
- `0`: Success
- `1`: Any error (validation, config, or internal)

### v3.0 Exit Codes (Deterministic)
- `0`: Success - all validations passed
- `1`: Policy violation - thresholds not met, critical keys missing  
- `2`: Configuration error - invalid config, missing files
- `3`: I/O or sync error - file access, git operations
- `4`: Internal error - unexpected failures

**CI/CD Impact**: Update your scripts to handle specific exit codes:

```bash
# OLD (v2) - Binary pass/fail
if flutter_keycheck --keys keys.yaml; then
  echo "Pass"
else
  echo "Fail"
  exit 1
fi

# NEW (v3) - Semantic exit codes
flutter_keycheck validate
EXIT_CODE=$?
case $EXIT_CODE in
  0) echo "✅ All validations passed" ;;
  1) echo "❌ Policy violation - review missing keys" ; exit 1 ;;
  2) echo "⚠️ Configuration error - check setup" ; exit 2 ;;
  3) echo "🔄 I/O error - retry operation" ; exit 3 ;;
  4) echo "💥 Internal error - report bug" ; exit 4 ;;
esac
```

## Command Structure Changes

### From Flags to Subcommands
```bash
# v2 (flag-based)
flutter_keycheck --keys expected_keys.yaml --strict

# v3 (subcommand-based)
flutter_keycheck validate --strict
```

### Command Mapping

| v2 Flag | v3 Command |
|---------|------------|
| `--keys file.yaml` | `validate` |
| `--generate-keys` | `scan` |
| `--key-constants-report` | `report --type constants` |

## Configuration File Changes

### New Schema (v3)
```yaml
version: 1  # Required
validate:
  thresholds:
    min_coverage: 0.8  # Fraction, not percentage!
    max_drift: 10
  fail_on_lost: true
  fail_on_extra: false
```

**Key Changes**:
- Add `version: 1` at the top (required)
- Metrics use fractions (0.95) not percentages (95)
- New threshold-based validation options

## Quick Migration

### 1. Update Dependency
```yaml
dev_dependencies:
  flutter_keycheck: ^3.0.0
```

### 2. Update CI Scripts
Replace flag-based calls with subcommands:
- `--keys file.yaml` → `validate`
- `--generate-keys` → `scan`
- Handle new exit codes (see above)

### 3. Add Config Version
Add `version: 1` to `.flutter_keycheck.yaml`

## Need Help?

- [Full Migration Guide](https://github.com/1nk1/flutter_keycheck/blob/main/docs/MIGRATION_FULL.md)
- [GitHub Issues](https://github.com/1nk1/flutter_keycheck/issues)
- [v3 Documentation](https://pub.dev/packages/flutter_keycheck)