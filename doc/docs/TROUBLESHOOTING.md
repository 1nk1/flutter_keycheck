# Flutter KeyCheck v3 Troubleshooting

## Exit Codes Reference

| Code | Meaning | Common Causes | Resolution |
|------|---------|---------------|------------|
| 0 | Success | All validations passed | — |
| 1 | Policy violation | • Coverage below threshold<br>• Critical keys missing<br>• Too many keys lost/renamed | • Check coverage thresholds<br>• Review baseline<br>• Update tracked keys |
| 2 | Configuration error | • Invalid YAML syntax<br>• Missing config file<br>• Invalid threshold values | • Fix YAML syntax<br>• Create `.flutter_keycheck.yaml`<br>• Check value ranges |
| 3 | I/O error | • Permission denied<br>• File not found<br>• Git operation failed | • Check file permissions<br>• Verify paths exist<br>• Check git status |
| 4 | Internal error | • Unexpected exception<br>• Parser failure<br>• Invalid state | • Report bug with stack trace<br>• Check Dart/Flutter versions |

## Common Issues

### Global command not found
```bash
# Fix: Ensure PATH includes pub cache
export PATH="$PATH:$HOME/.pub-cache/bin"

# Or use full path
~/.pub-cache/bin/flutter_keycheck --help
```

### Schema version mismatch
```bash
# Old baseline with v2 schema
Error: Expected schema 1.0, got 0.9

# Fix: Recreate baseline
flutter_keycheck baseline create --force
```

### Parse failures on large projects
```bash
# Increase memory if needed
dart --old_gen_heap_size=4096 run flutter_keycheck:flutter_keycheck scan
```

### Missing dependencies
```bash
# Ensure analyzer is available
dart pub get
dart pub deps | grep analyzer
```

## Performance Tuning

### Enable caching
```yaml
# .flutter_keycheck.yaml
cache:
  enabled: true
  ttl: 86400  # 24 hours
```

### Parallel processing
```bash
# Use all available cores (default)
flutter_keycheck scan --parallel

# Limit to specific count
flutter_keycheck scan --isolates 4
```

### Incremental scanning
```bash
# Only scan changed files since last commit
flutter_keycheck scan --since HEAD~1
```

## Debug Output

### Verbose mode
```bash
flutter_keycheck validate --verbose
```

### JSON output for debugging
```bash
flutter_keycheck scan --report json | jq '.detectors'
```

### Trace AST parsing
```bash
FLUTTER_KEYCHECK_DEBUG=ast flutter_keycheck scan
```