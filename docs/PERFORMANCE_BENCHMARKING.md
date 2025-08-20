# Performance Benchmarking System

This document describes the comprehensive performance benchmarking system for flutter_keycheck, designed to ensure optimal performance across different project sizes and usage scenarios.

## Overview

The performance benchmarking system provides:

- **Multi-scale Testing**: Small, medium, large, and enterprise project sizes
- **Comprehensive Metrics**: Scan time, memory usage, throughput, accuracy
- **Regression Detection**: Automated performance regression analysis
- **CI/CD Integration**: Continuous performance monitoring
- **Interactive Dashboards**: Visual performance insights and trends
- **Automated Alerts**: Performance degradation notifications

## Architecture

```
Performance Benchmarking System
├── Core Components
│   ├── BenchmarkCommand           # CLI command interface
│   ├── PerformanceBenchmark       # Core benchmarking engine
│   └── ComprehensiveBenchmarkSuite # Multi-scenario testing
├── Testing Infrastructure
│   ├── TestDataGenerator          # Realistic test project generation
│   ├── RegressionAnalyzer         # Performance regression detection
│   └── PerformanceAnalyzer        # Detailed performance analysis
├── Monitoring & Reporting
│   ├── PerformanceDashboard       # Interactive HTML dashboards
│   ├── MarkdownReporter          # CI-friendly reports
│   └── MetricsExporter           # JSON/CSV data export
└── CI/CD Integration
    ├── GitHub Actions Workflow    # Automated benchmarking
    ├── Performance Monitoring     # Continuous tracking
    └── Baseline Management        # Performance baseline updates
```

## Getting Started

### Running Basic Benchmarks

```bash
# Run comprehensive benchmarks
dart run flutter_keycheck benchmark

# Run with specific scenarios
dart run flutter_keycheck benchmark --scenarios scanning,baseline,diff

# Generate test data and run benchmarks
dart run flutter_keycheck benchmark --generate-data --project-size large

# Run in CI mode with memory profiling
dart run flutter_keycheck benchmark --ci-mode --memory-profile
```

### Advanced Performance Suite

```bash
# Run complete performance workflow
dart run scripts/performance_suite.dart complete --project-size enterprise

# Generate test data only
dart run scripts/performance_suite.dart generate --project-size large

# Run regression tests
dart run scripts/performance_suite.dart regression --baseline baseline.json --threshold 15

# Generate performance reports
dart run scripts/performance_suite.dart report --output reports/
```

### Performance Dashboard

```bash
# Generate HTML dashboard
dart run tools/performance_dashboard.dart --input performance_results --format html

# Generate markdown report for CI
dart run tools/performance_dashboard.dart --format markdown --output reports/

# Generate dashboard with 60-day trends
dart run tools/performance_dashboard.dart --days 60 --baseline baseline.json
```

## Benchmark Scenarios

### 1. Scanning Performance

Tests AST scanning performance across different configurations:

- **Sequential Processing**: Single-threaded baseline performance
- **Parallel Processing**: Multi-core optimization performance
- **Cached Scanning**: Performance with warm cache
- **Incremental Scanning**: Performance with incremental updates
- **Memory Optimized**: Low-memory configuration performance

**Key Metrics:**
- Scan time (milliseconds)
- Files processed per second
- Memory usage (MB)
- Cache hit rate (%)
- Error count

### 2. Baseline Operations

Tests baseline command performance:

- **Baseline Creation**: Initial baseline generation time
- **Baseline Updates**: Incremental baseline update performance
- **Baseline Loading**: Baseline file loading and parsing time

**Key Metrics:**
- Operation duration
- Memory usage
- Baseline size
- Update efficiency

### 3. Diff Operations

Tests diff command performance with various baseline sizes:

- **Small Diff**: 100 keys comparison
- **Medium Diff**: 1,000 keys comparison  
- **Large Diff**: 10,000 keys comparison
- **Complex Diff**: Multiple change types

**Key Metrics:**
- Comparison time
- Memory usage
- Keys compared per second
- Diff accuracy

### 4. Validation Performance

Tests validation command performance:

- **Small Validation**: 100 keys validation
- **Medium Validation**: 1,000 keys validation
- **Large Validation**: 10,000 keys validation
- **Complex Validation**: Multi-source validation

**Key Metrics:**
- Validation time
- Keys validated per second
- Memory usage
- Validation accuracy

### 5. Memory Profiling

Detailed memory usage analysis:

- **Memory Baseline**: Base memory footprint
- **Large File Processing**: Memory usage with large files
- **Concurrent Processing**: Memory usage during parallel operations
- **Memory Leak Detection**: Long-running operation analysis

**Key Metrics:**
- Peak memory usage
- Memory growth patterns
- Garbage collection impact
- Memory efficiency

### 6. CI/CD Integration

Tests CI/CD-specific performance requirements:

- **Quick Scan**: Fast scanning for CI pipelines
- **Regression Check**: Performance regression detection time
- **Report Generation**: Report generation performance
- **Pipeline Integration**: End-to-end CI performance

**Key Metrics:**
- Total pipeline time
- Individual operation times
- Resource utilization
- CI-friendliness score

## Performance Targets

### Project Size Categories

#### Small Projects (<100 files)
- **Scan Time**: ≤500ms
- **Memory Usage**: ≤50MB
- **Throughput**: ≥500 files/sec
- **Keys/Second**: ≥10,000

#### Medium Projects (100-1,000 files)
- **Scan Time**: ≤2s
- **Memory Usage**: ≤200MB
- **Throughput**: ≥300 files/sec
- **Keys/Second**: ≥5,000

#### Large Projects (1,000-5,000 files)
- **Scan Time**: ≤10s
- **Memory Usage**: ≤500MB
- **Throughput**: ≥200 files/sec
- **Keys/Second**: ≥2,000

#### Enterprise Projects (>5,000 files)
- **Scan Time**: ≤30s
- **Memory Usage**: ≤1GB
- **Throughput**: ≥100 files/sec
- **Keys/Second**: ≥1,000

### Quality Targets

- **Cache Hit Rate**: ≥80%
- **Error Rate**: ≤0.1%
- **Accuracy**: ≥99.9%
- **Memory Efficiency**: Linear scaling with project size

## Regression Testing

### Automated Regression Detection

The system automatically detects performance regressions by comparing current results with baseline performance:

```bash
# Set regression threshold to 20%
dart run flutter_keycheck benchmark --regression-test --threshold 20

# Compare with specific baseline
dart run flutter_keycheck benchmark --baseline production_baseline.json
```

### Regression Criteria

- **Scan Time**: >20% increase
- **Memory Usage**: >25% increase
- **Throughput**: >15% decrease
- **Cache Performance**: >10% decrease in hit rate
- **Error Rate**: Any increase in errors

### Regression Response

When regressions are detected:

1. **CI Pipeline Failure**: Fails the build with detailed regression report
2. **Detailed Analysis**: Provides comparison metrics and degradation percentages
3. **Recommendation Engine**: Suggests optimization strategies
4. **Historical Context**: Shows performance trends over time

## Test Data Generation

### Realistic Test Projects

The system generates realistic Flutter projects for testing:

```bash
# Generate small test project
dart run scripts/performance_suite.dart generate --project-size small

# Generate enterprise-scale project
dart run scripts/performance_suite.dart generate --project-size enterprise
```

### Project Characteristics

- **Realistic Structure**: Follows Flutter project conventions
- **Variable File Sizes**: Mix of small and large files
- **Key Density Control**: Configurable key-to-widget ratios
- **Dependency Simulation**: Mock package dependencies
- **Test Coverage**: Unit, widget, and integration tests

### Key Distribution Patterns

- **Screen Classes**: High key density for navigation
- **Widget Classes**: Medium key density for components
- **Service Classes**: Low key density for business logic
- **Test Files**: High key density for test automation

## Performance Monitoring

### Continuous Monitoring

GitHub Actions workflow runs performance benchmarks:

- **Daily Scheduled Runs**: Track long-term performance trends
- **PR Performance Checks**: Prevent performance regressions
- **Release Validation**: Ensure release performance standards
- **Baseline Updates**: Automatic baseline updates on main branch

### Performance Dashboard

Interactive HTML dashboard provides:

- **Real-time Metrics**: Current performance status
- **Trend Analysis**: Performance trends over time
- **Configuration Comparison**: Performance across different configurations
- **Regression Alerts**: Visual alerts for performance issues
- **Recommendation Engine**: Automated optimization suggestions

### Alert System

Automated alerts for:

- **Performance Regressions**: Immediate notification of degradation
- **Resource Limits**: Memory or time limit exceeded
- **Error Rate Increases**: Quality degradation detection
- **Baseline Drift**: Significant baseline changes

## CI/CD Integration

### GitHub Actions Workflow

The performance monitoring workflow (`performance-monitoring.yml`) provides:

- **Automated Benchmarking**: Runs on push, PR, and schedule
- **Multi-Configuration Testing**: Tests different Dart versions and project sizes
- **Regression Analysis**: Compares against baseline performance
- **Performance Comments**: Adds performance results to PR comments
- **Baseline Management**: Updates performance baselines automatically

### Usage in CI/CD

```yaml
# Include in your CI pipeline
- name: Performance Benchmark
  run: |
    dart run flutter_keycheck benchmark \
      --ci-mode \
      --project-size medium \
      --scenarios scanning,baseline,diff \
      --output benchmark_results.json

- name: Check Performance Regression
  run: |
    dart run flutter_keycheck benchmark \
      --regression-test \
      --baseline baseline.json \
      --threshold 20
```

### Performance Gates

Set up performance gates in your CI:

- **Fail Build**: If regressions exceed threshold
- **Warning Comments**: For performance concerns
- **Baseline Updates**: On successful main branch builds
- **Trend Tracking**: Long-term performance monitoring

## Advanced Features

### Memory Profiling

Detailed memory analysis:

```bash
# Enable memory profiling
dart run flutter_keycheck benchmark --memory-profile

# Generate memory report
dart run tools/performance_dashboard.dart --include-memory-analysis
```

### Custom Scenarios

Create custom benchmark scenarios:

```dart
// Custom benchmark configuration
final customBenchmark = PerformanceBenchmark(
  projectPath: '/path/to/project',
  config: customConfig,
  enableCustomOptimizations: true,
);

final results = await customBenchmark.runCustomScenario([
  'large_file_processing',
  'complex_dependency_resolution',
  'high_concurrency_scanning',
]);
```

### Performance Profiling

Integrate with Dart's performance tools:

```bash
# Run with Dart Observatory
dart --observe=8181 run flutter_keycheck benchmark

# Generate performance traces
dart --trace-systrace=trace.json run flutter_keycheck benchmark
```

## Troubleshooting

### Common Issues

#### High Memory Usage
- Enable lazy loading: `--enable-lazy-loading`
- Reduce parallel workers: `--max-workers 2`
- Use incremental scanning: `--enable-incremental`

#### Slow Performance
- Enable parallel processing: `--enable-parallel`
- Use aggressive caching: `--enable-caching`
- Optimize file filtering: Check exclude patterns

#### Inconsistent Results
- Clear cache between runs: `--clear-cache`
- Use deterministic test data
- Check system resource availability

### Performance Analysis

Use the analysis tools to understand performance:

```bash
# Analyze performance results
dart run scripts/performance_suite.dart analyze --input benchmark_results.json

# Generate detailed report
dart run tools/performance_dashboard.dart --verbose --include-analysis
```

### Debug Mode

Enable verbose debugging:

```bash
# Run with detailed logging
dart run flutter_keycheck benchmark --verbose --debug-performance

# Generate debug report
dart run flutter_keycheck benchmark --debug-mode --output debug_results.json
```

## Contributing

### Adding New Benchmarks

1. **Define Scenario**: Create new benchmark scenario in `PerformanceBenchmark`
2. **Implement Metrics**: Add relevant performance metrics collection
3. **Update Targets**: Define performance targets for the new scenario
4. **Add Tests**: Create regression tests for the new benchmark
5. **Update Dashboard**: Include new metrics in performance dashboard

### Performance Optimization

1. **Profile First**: Use benchmarks to identify bottlenecks
2. **Measure Impact**: Quantify optimization improvements
3. **Regression Test**: Ensure optimizations don't break functionality
4. **Update Baselines**: Update performance baselines after improvements

### Extending Test Data

1. **Realistic Patterns**: Generate test data that reflects real-world usage
2. **Scalable Generation**: Ensure test data generation scales efficiently
3. **Reproducible Results**: Use deterministic generation for consistent testing
4. **Variety**: Include different file types, sizes, and complexity levels

## Best Practices

### Performance Testing

- **Consistent Environment**: Use consistent hardware and OS for testing
- **Warm-up Runs**: Run warm-up iterations before measuring
- **Multiple Iterations**: Average results across multiple runs
- **Baseline Management**: Keep baselines updated and relevant
- **Trend Analysis**: Focus on trends rather than individual results

### CI Integration

- **Fast Feedback**: Keep CI benchmarks fast enough for development workflow
- **Comprehensive Coverage**: Balance speed with comprehensive testing
- **Clear Reporting**: Provide clear, actionable performance feedback
- **Automated Baselines**: Automate baseline updates for consistency

### Monitoring

- **Proactive Alerts**: Set up alerts before performance becomes critical
- **Historical Tracking**: Maintain long-term performance history
- **Context Awareness**: Include relevant context in performance reports
- **Actionable Insights**: Provide specific recommendations for improvements

## Resources

- [Performance Optimization Guide](PERFORMANCE_OPTIMIZATIONS.md)
- [AST Scanner Optimization](../lib/src/scanner/ast_scanner_v3.dart)
- [GitHub Actions Workflow](../.github/workflows/performance-monitoring.yml)
- [Benchmark Command Reference](../lib/src/commands/benchmark_command.dart)
- [Performance Dashboard Tool](../tools/performance_dashboard.dart)