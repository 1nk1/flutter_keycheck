# GitLab CI/CD Setup Guide

This document provides comprehensive guidance for setting up and optimizing the GitLab CI/CD pipeline for Flutter KeyCheck.

## Pipeline Overview

The Flutter KeyCheck CI/CD pipeline is designed for maximum efficiency, parallel execution, and comprehensive validation. It includes:

### 🔍 Analysis Stage
- **Lint Analysis**: Dart analyzer with strict mode (`--fatal-infos --fatal-warnings`)
- **Format Check**: Code formatting validation
- **Security Analysis**: PANA-based security scanning with JSON reports

### 🧪 Test Stage
- **Unit Tests**: Parallel execution across Dart versions (3.3.0, stable, beta)
- **Integration Tests**: End-to-end workflow validation
- **Coverage Reports**: LCOV format with GitLab integration

### 🔑 Key Validation Stage
- **Scan Operations**: Workspace-only, deps-only, and comprehensive scans
- **Baseline Testing**: Diff generation and validation
- **Error Handling**: Edge case and error condition testing

### 🏗️ Build Stage
- **Multi-Platform Executables**: Linux, macOS, Windows builds
- **Package Validation**: pub.dev publication readiness

### ⚡ Performance Testing Stage
- **Benchmark Execution**: Performance regression detection
- **Memory Analysis**: Resource usage monitoring
- **Baseline Comparison**: 20% regression threshold

### 📊 Reporting Stage
- **Report Generation**: HTML, Markdown, and JSON formats
- **MR Comments**: Automated result posting to merge requests
- **Artifact Management**: 30-day retention for reports

### 🚀 Publication Stage
- **Dry Run Validation**: Version matching and package preparation
- **Manual Release**: Production deployment with safeguards

## Configuration Requirements

### Repository Settings

1. **Variables** (Settings → CI/CD → Variables):
   ```bash
   # Optional: For MR commenting
   GITLAB_ACCESS_TOKEN=<your-gitlab-access-token>
   
   # Optional: For custom performance thresholds
   PERFORMANCE_REGRESSION_THRESHOLD=20  # Percentage
   ```

2. **Runners**:
   - **Shared Runners**: Enabled for basic pipeline execution
   - **Custom Runners**: Optional for enhanced performance (see Docker runner build)

### GitLab Features Integration

1. **Merge Request Pipelines**: Automatically triggered on MR events
2. **Coverage Reports**: Integrated with GitLab's coverage visualization
3. **JUnit Test Reports**: Test results displayed in pipeline UI
4. **Artifact Downloads**: Build executables and reports available
5. **Environment Management**: Production environment for releases

## Performance Optimizations

### Multi-Level Caching Strategy

```yaml
cache:
  # Primary: Dependencies (pubspec.lock-based)
  - key: { files: [pubspec.lock] }
    paths: [$PUB_CACHE/, $DART_TOOL_CACHE/]
    policy: pull-push
    
  # Secondary: Analysis results (commit-based)
  - key: analysis-$CI_COMMIT_SHA
    paths: [.dart_tool/flutter_keycheck/cache/]
    policy: pull-push
    
  # Tertiary: Build artifacts (commit-based)
  - key: build-artifacts-$CI_COMMIT_SHA
    paths: [build/, $ARTIFACTS_DIR/]
    policy: pull-push
```

### Parallel Execution Matrix

- **Dart Versions**: Tests run in parallel across 3.3.0, stable, beta
- **Platform Builds**: Simultaneous executable compilation for all platforms
- **Stage Isolation**: Independent stage execution with dependency management

### Resource Management

- **Memory Limits**: 2GB per job with monitoring
- **CPU Allocation**: 2 cores per job for optimal performance
- **Timeout Management**: 10-minute job timeouts with interrupt capability
- **Artifact Optimization**: Selective artifact collection with expiration

## Local Development Integration

### GitLab CI Local Testing

Install and use `gitlab-ci-local` for pipeline testing:

```bash
# Install gitlab-ci-local
npm install -g gitlab-ci-local

# Test essential jobs locally
gitlab-ci-local --file .gitlabci-local.yml

# Test specific job
gitlab-ci-local lint
```

### CI Setup Script

Use the provided setup script for environment preparation:

```bash
# Run CI setup (works both locally and in CI)
./scripts/ci-setup.sh
```

## Advanced Features

### Custom Docker Runner

The pipeline includes optional custom runner image generation:

```yaml
# Builds optimized runner with pre-installed tools
build:docker-runner:
  # Triggered manually or on schedule
  # Pushes to GitLab Container Registry
  # Includes: dart, pana, coverage, time, python3
```

### Performance Regression Detection

Automated performance monitoring with Python-based analysis:

```python
# 20% regression threshold
if current.scan_duration_ms > baseline.scan_duration_ms * 1.2:
    print('❌ Performance regression detected!')
    sys.exit(1)
```

### MR Integration

Automatic merge request commenting with:
- Pipeline status summary
- Validation results
- Performance metrics
- Test coverage information

## Troubleshooting

### Common Issues

1. **Cache Misses**:
   ```bash
   # Clear cache manually if needed
   # Settings → CI/CD → Pipelines → Clear Runner Caches
   ```

2. **Memory Issues**:
   ```yaml
   # Reduce concurrency in problematic jobs
   script:
     - dart test --concurrency=1  # Instead of 4
   ```

3. **Timeout Problems**:
   ```yaml
   # Increase timeout for specific jobs
   timeout: 15m  # Instead of default 10m
   ```

4. **Permission Errors**:
   ```yaml
   # Ensure proper directory permissions
   before_script:
     - mkdir -p $REPORTS_DIR && chmod 755 $REPORTS_DIR
   ```

### Debug Mode

Enable detailed logging by setting:

```yaml
variables:
  CI_DEBUG_TRACE: "true"  # GitLab debug mode
  DART_VM_OPTIONS: "--verbose"  # Dart verbose mode
```

## Monitoring and Metrics

### Pipeline Metrics

Monitor these key indicators:
- **Pipeline Duration**: Target <15 minutes for full pipeline
- **Cache Hit Rate**: Target >80% for dependency cache
- **Test Coverage**: Maintain >80% line coverage
- **Performance Variance**: Keep within 20% of baseline

### Resource Usage

Track resource consumption:
- **Peak Memory Usage**: Monitor via `/usr/bin/time -v`
- **CPU Utilization**: Observe via GitLab runner metrics
- **Artifact Size**: Keep total artifacts <500MB per pipeline

## Best Practices

### Code Quality Gates

All pipelines enforce:
- ✅ Zero analyzer warnings/infos
- ✅ Consistent code formatting
- ✅ Security compliance via PANA
- ✅ Comprehensive test coverage

### Release Management

For version releases:
1. Update `pubspec.yaml` version
2. Create git tag matching version (`v3.0.1`)
3. Pipeline automatically validates version consistency
4. Manual approval required for pub.dev publication

### Security Considerations

- **Token Management**: Use GitLab CI variables for sensitive data
- **Artifact Security**: Reports may contain project structure information
- **Runner Security**: Custom runners isolate build environment
- **Dependency Scanning**: PANA integration for vulnerability detection

## Support and Maintenance

### Regular Maintenance Tasks

1. **Weekly**: Review pipeline performance metrics
2. **Monthly**: Update Dart SDK versions in matrix testing
3. **Quarterly**: Audit and optimize cache strategies
4. **Annually**: Review and update security scanning tools

### Getting Help

- **GitLab Documentation**: [GitLab CI/CD Docs](https://docs.gitlab.com/ee/ci/)
- **Dart CI Best Practices**: [Dart CI Guide](https://dart.dev/tools/dart-test#running-tests-with-continuous-integration)
- **Flutter KeyCheck Issues**: [Project Issues](https://github.com/1nk1/flutter_keycheck/issues)

---

*This pipeline configuration is optimized for the Flutter KeyCheck v3.0.0 project and follows GitLab CI/CD best practices for Dart/Flutter projects.*