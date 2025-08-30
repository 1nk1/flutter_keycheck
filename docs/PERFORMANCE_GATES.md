# Performance Gates for CI/CD

## Overview

The flutter_keycheck project implements performance regression detection to ensure the scanner maintains consistent runtime and memory usage across releases. This system automatically fails CI builds if performance degrades by more than 20% compared to the established baseline.

## Key Metrics Tracked

1. **Runtime (milliseconds)**: Total execution time for scanning
2. **Peak RSS Memory (MB)**: Maximum resident set size during execution
3. **JSON Output Size (KB)**: Size of the generated key-snapshot.json file
4. **Files Scanned**: Number of Dart files analyzed
5. **Keys Found**: Number of Flutter keys detected

## Performance Baseline

Current baseline metrics (on flutter_casino_demo):
- **Runtime**: ~10,100ms (±40ms std dev)
- **Memory**: ~1,004MB peak RSS (±15MB std dev)
- **Output**: 33.3KB JSON file
- **Coverage**: 29 files scanned, 15 keys found

## Usage

### Establishing a Baseline

Run the performance profiler to create or update the baseline:

```bash
dart test/performance_baseline.dart
```

This will:
1. Run the scanner 5 times on the test project
2. Calculate statistical metrics (mean, median, stddev)
3. Save results to `performance_baseline.json`

### Running Regression Checks

Check current performance against the baseline:

```bash
dart test/performance_baseline.dart --compare
```

Or use the CI-specific script:

```bash
dart test/ci_performance_check.dart
```

### CI Integration

Add to your GitHub Actions workflow:

```yaml
- name: Performance Regression Check
  run: dart test/ci_performance_check.dart
  continue-on-error: false
```

Add to your GitLab CI pipeline:

```yaml
performance-check:
  stage: test
  script:
    - dart test/ci_performance_check.dart
  allow_failure: false
```

## Regression Thresholds

The system fails CI if any metric regresses by >20%:

| Metric | Threshold | Example Failure |
|--------|-----------|-----------------|
| Runtime | +20% | 10,100ms → 12,120ms |
| Memory | +20% | 1,004MB → 1,205MB |
| JSON Size | +20% | 33.3KB → 40KB |

## Architecture

### Performance Profiler (`test/performance_baseline.dart`)

- Runs scanner multiple times (default: 5)
- Monitors process metrics using `/proc/[pid]/status` on Linux
- Calculates statistical measures for stability
- Stores baseline in JSON format

### CI Check Script (`test/ci_performance_check.dart`)

- Wrapper for CI environments
- Returns exit code 0 for pass, 1 for regression
- Provides clear output for build logs

### Baseline File (`performance_baseline.json`)

```json
{
  "metrics": {
    "runtime_ms": {
      "mean": 10099.6,
      "median": 10110.0,
      "stddev": 38.32,
      "min": 10031,
      "max": 10139
    },
    "peak_rss_mb": {
      "mean": 1004.37,
      "median": 1000.87,
      "stddev": 14.58,
      "min": 989.52,
      "max": 1030.71
    },
    "json_size_kb": {
      "mean": 33.3,
      "median": 33.3,
      "stddev": 0.0,
      "min": 33.3,
      "max": 33.3
    },
    "files_scanned": 29,
    "keys_found": 15
  },
  "metadata": {
    "timestamp": "2025-08-31T01:10:00.000Z",
    "dart_version": "Dart SDK version: 3.2.0",
    "platform": "linux",
    "target_project": "example/flutter_casino_demo",
    "run_count": 5
  }
}
```

## Updating the Baseline

When performance improvements are made or expected regressions are acceptable:

1. Review the regression report to ensure changes are intentional
2. Run `dart test/performance_baseline.dart` to create new baseline
3. Commit the updated `performance_baseline.json` file
4. Document the reason for the baseline update in the commit message

## Troubleshooting

### No Baseline Found

If CI reports "No performance baseline found":
1. Run `dart test/performance_baseline.dart` locally
2. Commit the generated `performance_baseline.json`
3. Re-run CI

### False Positives

If experiencing false positives due to CI environment variations:
1. Consider increasing the threshold (e.g., to 25% or 30%)
2. Add more runs to reduce variance
3. Use dedicated CI runners for consistency

### Platform Differences

The memory monitoring is Linux-specific. For other platforms:
- macOS: Consider using `vm_stat` or Activity Monitor APIs
- Windows: Use Windows Performance Counters
- Fallback: Estimates based on Dart heap usage

## Best Practices

1. **Regular Baselines**: Update baseline after major refactoring
2. **Environment Consistency**: Use same hardware/OS for baseline and checks
3. **Multiple Runs**: Use 5+ runs to reduce variance
4. **Document Changes**: Always document why baselines are updated
5. **Monitor Trends**: Track performance over time, not just regression gates

## Future Enhancements

- [ ] Support for incremental scan performance tracking
- [ ] Memory profiling breakdown (heap vs RSS)
- [ ] Per-operation performance metrics
- [ ] Historical trend visualization
- [ ] Automatic baseline updates for improvements