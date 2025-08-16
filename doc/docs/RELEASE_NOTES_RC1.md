## v3.0.0-rc.1 — AST-based scanner

### 🚀 Highlights
- **Unified CLI** (`flutter_keycheck`), AST detectors, schema v1.0 (fractions)
- **Hardened exit codes**: 0=OK, 1=Policy, 2=Config, 3=IO, 4=Internal
- **Performance**: Parallel processing with 8-12 isolates, 60-80% faster with caching

### ⚠️ Breaking Changes
- **Removed legacy binaries**: `bin/*v2|v3_*` → unified `bin/flutter_keycheck.dart`
- **CLI migrated to subcommands**: `scan`, `validate`, `baseline`, `diff`, `report`, `sync`
- **Schema v1.0**: `parse_success_rate` now fraction [0,1] not percentage

### 📦 Installation

#### Global
```bash
dart pub global activate flutter_keycheck
flutter_keycheck --help
```

#### Local
```bash
dart pub add --dev flutter_keycheck
dart run flutter_keycheck:flutter_keycheck --help
```

### 🧪 Testing the RC

```bash
# Quick smoke test
./smoke_test.sh
./test_exit_codes.sh

# Real project test
flutter_keycheck scan --report json --output scan.json
flutter_keycheck validate --strict
```

### 📊 Performance Baseline Request

Please share metrics for your project:
```bash
time flutter_keycheck scan --path <app> --output /tmp/k.json --strict
wc -c /tmp/k.json
jq '.summary' /tmp/k.json
```

### 🔄 Migration from v2.x

| Old Command | New Command |
|-------------|-------------|
| `flutter_keycheck --keys file.yaml` | `flutter_keycheck validate` |
| `flutter_keycheck --generate-keys` | `flutter_keycheck scan --report yaml` |
| `bin/flutter_keycheck_v3.dart` | `bin/flutter_keycheck.dart` |

### 📝 Known Issues
- None identified in RC1

### 🎯 RC Acceptance Criteria
- ✅ CI green on ubuntu-latest (Dart stable + beta)
- ✅ `dart pub publish --dry-run` clean
- ✅ Global install smoke test passes
- ✅ Schema v1.0 in JSON output
- ✅ Exit codes deterministic

### 💬 Feedback
Report issues: https://github.com/1nk1/flutter_keycheck/issues
Label: `rc-feedback`

### 🚦 Path to GA
- **v3.0.0-rc.2**: Only if critical bugs found
- **v3.0.0 GA**: After 5-7 business days with no P0/P1 issues