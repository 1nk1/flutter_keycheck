# Migration Guide: v2 to v3

This guide helps you migrate from flutter_keycheck v2.x to v3.0.

## Breaking Changes

### 1. CLI Command Structure

#### Old (v2.x) - Flag-based
```bash
# v2 - everything via flags
flutter_keycheck --keys expected_keys.yaml --strict --fail-on-extra
flutter_keycheck --generate-keys > keys.yaml
flutter_keycheck --key-constants-report
```

#### New (v3.0) - Subcommands
```bash
# v3 - explicit subcommands
flutter_keycheck validate --strict --fail-on-extra
flutter_keycheck scan --report json
flutter_keycheck baseline create
flutter_keycheck diff --from baseline.json --to current.json
```

### 2. Primary Command Changes

| v2 Flags | v3 Command | Notes |
|----------|------------|-------|
| `--keys file.yaml` | `validate` | Now the primary command |
| `--generate-keys` | `scan` | Generates snapshot, not just key list |
| `--key-constants-report` | `report --type constants` | Moved to report command |
| `--validate-key-constants` | `validate --check-constants` | Part of validate command |

### 3. Exit Codes

#### v2.x - Inconsistent
- `0`: Success
- `1`: Any error (validation, config, internal)

#### v3.0 - Deterministic
- `0`: Success - all validations passed
- `1`: Policy violation - thresholds not met, critical keys missing  
- `2`: Configuration error - invalid config, missing files
- `3`: I/O or sync error - file access, git operations
- `4`: Internal error - unexpected failures

Update your CI/CD scripts:
```bash
# v2 - check for non-zero
if flutter_keycheck --keys keys.yaml; then
  echo "Pass"
fi

# v3 - check specific exit codes
flutter_keycheck validate
EXIT_CODE=$?
case $EXIT_CODE in
  0) echo "✅ All validations passed" ;;
  1) echo "❌ Policy violation" ;;
  2) echo "⚠️ Configuration error" ;;
  3) echo "🔄 I/O or sync error" ;;
  4) echo "💥 Internal error" ;;
esac
```

### 4. Configuration File Changes

#### v2 - `.flutter_keycheck.yaml`
```yaml
keys: expected_keys.yaml
strict: true
fail_on_extra: true
include_only: 
  - qa_
  - e2e_
```

#### v3 - `.flutter_keycheck.yaml`
```yaml
version: 1  # Schema version
validate:
  thresholds:
    min_coverage: 0.8  # 80% coverage required
    max_drift: 10      # Max 10 keys can change
  protected_tags:
    - critical
    - aqa
  fail_on_lost: true
  fail_on_extra: false

scan:
  packages: workspace  # or 'resolve'
  include_tests: false
  include_generated: false
  cache: true
```

### 5. Report Format Changes

#### v2 - Simple JSON
```json
{
  "missing_keys": ["key1", "key2"],
  "extra_keys": ["key3"],
  "found_keys": {"key4": ["lib/main.dart:45"]}
}
```

#### v3 - Schema v1.0
```json
{
  "version": "1.0.0",
  "timestamp": "2025-01-15T10:00:00Z",
  "metrics": {
    "files_total": 100,
    "files_scanned": 95,
    "parse_success_rate": 0.95,  // Fraction, not percentage!
    "widgets_total": 500,
    "widgets_with_keys": 250,
    "handlers_total": 100,
    "handlers_linked": 80
  },
  "detectors": [
    {
      "name": "ValueKey",
      "hits": 150,
      "keys_found": 120,
      "effectiveness": 80.0
    }
  ]
}
```

### 6. CI/CD Pipeline Updates

#### GitLab CI - v2
```yaml
validate:
  script:
    - flutter_keycheck --keys keys.yaml --strict --report json
```

#### GitLab CI - v3
```yaml
validate:keycheck:
  script:
    - flutter_keycheck scan --report json,junit --out-dir reports
    - flutter_keycheck validate --threshold-file thresholds.yaml --strict
  artifacts:
    reports:
      junit: reports/junit.xml
```

#### GitHub Actions - v2
```yaml
- run: flutter_keycheck --keys keys.yaml --strict
```

#### GitHub Actions - v3
```yaml
- run: |
    flutter_keycheck scan --report json,junit,md --out-dir reports
    flutter_keycheck validate --strict --fail-on-lost
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 1 ]; then
      echo "::error::Policy violation detected"
      exit 1
    fi
```

## Migration Steps

### Step 1: Update Dependencies
```yaml
dev_dependencies:
  flutter_keycheck: ^3.0.0
```

### Step 2: Update Configuration File
1. Rename old config to `.flutter_keycheck.v2.yaml` for backup
2. Create new `.flutter_keycheck.yaml` with v3 format
3. Add `version: 1` at the top

### Step 3: Update Scripts
```bash
# Create migration script
cat > migrate_v3.sh << 'EOF'
#!/bin/bash
# Backup v2 config
cp .flutter_keycheck.yaml .flutter_keycheck.v2.yaml 2>/dev/null || true

# Update common patterns in scripts
find . -name "*.sh" -o -name "*.yml" -o -name "*.yaml" | while read file; do
  # Backup
  cp "$file" "$file.v2backup"
  
  # Replace common patterns
  sed -i 's/flutter_keycheck --keys/flutter_keycheck validate --keys-file/g' "$file"
  sed -i 's/flutter_keycheck --generate-keys/flutter_keycheck scan/g' "$file"
  sed -i 's/--fail-on-extra/--fail-on-extra --fail-on-lost/g' "$file"
done

echo "Migration complete. Review changes and test thoroughly."
EOF
chmod +x migrate_v3.sh
./migrate_v3.sh
```

### Step 4: Test Migration
```bash
# Test v3 commands
flutter_keycheck --version  # Should show 3.0.0-rc.1
flutter_keycheck scan --help
flutter_keycheck validate --help

# Run validation
flutter_keycheck validate --dry-run  # Test without failing
```

### Step 5: Update CI/CD
1. Update `.gitlab-ci.yml` or `.github/workflows/*.yml`
2. Handle new exit codes properly
3. Update artifact paths for new report locations

## Rollback Plan

If you need to rollback to v2:
```bash
# Revert to v2
dart pub global activate flutter_keycheck 2.3.3

# Restore v2 configs
mv .flutter_keycheck.v2.yaml .flutter_keycheck.yaml

# Restore v2 scripts
find . -name "*.v2backup" | while read backup; do
  original="${backup%.v2backup}"
  mv "$backup" "$original"
done
```

## Common Issues

### Issue: "Unknown command" error
**Solution**: Update to use subcommands (scan, validate, etc.)

### Issue: Exit code 2 in CI
**Solution**: Check configuration file format, ensure `version: 1` is present

### Issue: "parse_success_rate must be between 0 and 1"
**Solution**: v3 uses fractions (0.95), not percentages (95)

### Issue: Missing reports
**Solution**: Use `--out-dir reports` to specify output directory

## Getting Help

- [GitHub Issues](https://github.com/1nk1/flutter_keycheck/issues)
- [Migration Examples](https://github.com/1nk1/flutter_keycheck/tree/main/examples/migration)
- [v3 Documentation](https://pub.dev/packages/flutter_keycheck/versions/3.0.0)