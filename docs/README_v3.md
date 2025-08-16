# Flutter KeyCheck v3

[![pub package](https://img.shields.io/pub/v/flutter_keycheck.svg)](https://pub.dev/packages/flutter_keycheck)
[![pub points](https://img.shields.io/pub/points/flutter_keycheck)](https://pub.dev/packages/flutter_keycheck/score)
[![Dart 3](https://img.shields.io/badge/Dart-3.5%2B-blue)](https://dart.dev)
[![GitLab Ready](https://img.shields.io/badge/GitLab-ready-orange)](https://gitlab.com)
[![CI Tested](https://img.shields.io/badge/CI-tested-green)](https://github.com/1nk1/flutter_keycheck/actions)

The developer-QA bridge for Flutter apps. Track, validate, and synchronize automation keys across teams and repositories.

## 👥 Who is it for?

**QA Automation Leads** - Central key registry, drift detection, historical tracking

**Flutter Development Teams** - Zero-friction key management, clear validation feedback

**DevOps Engineers** - GitLab-first CI/CD, deterministic exit codes, multi-repo support

**Enterprise Teams** - Monorepo support, package composition, compliance reporting

## 🚀 Quick Start

```bash
# Install globally
dart pub global activate flutter_keycheck

# Initialize in your project
flutter_keycheck init

# Scan and create baseline
flutter_keycheck scan --packages resolve
flutter_keycheck baseline create

# Sync with central registry
flutter_keycheck sync --registry git --repo git@gitlab.com:org/key-registry.git

# Validate in CI
flutter_keycheck validate --strict --fail-on-lost
```

## 📋 Commands

### Core Commands

| Command | Purpose | Exit Codes |
|---------|---------|------------|
| `scan` | Build current snapshot of keys | 0: success, 3: IO error |
| `baseline` | Create/update baseline | 0: success, 2: invalid config |
| `diff` | Compare snapshots | 0: no changes, 1: changes found |
| `validate` | CI gate enforcement | 0: passed, 1: policy violation |
| `sync` | Pull/push central registry | 0: success, 3: sync error |
| `report` | Generate reports | 0: success |

### Command Examples

```bash
# Scan workspace including dependencies
flutter_keycheck scan --packages resolve --report json --out-dir reports

# Create baseline from scan
flutter_keycheck baseline create --scan reports/key-snapshot.json

# Compare current state with baseline
flutter_keycheck diff --baseline registry --current scan

# Validate with strict policies
flutter_keycheck validate \
  --strict \
  --fail-on-lost \
  --fail-on-rename \
  --protected-tags critical,aqa \
  --max-drift 5

# Sync with Git-based registry
flutter_keycheck sync --registry git \
  --repo git@gitlab.com:org/key-registry.git \
  --action pull

# Generate multiple report formats
flutter_keycheck report --format json,junit,md --out-dir reports
```

## 🗂️ Key Registry

Central source of truth for all keys across your Flutter apps.

### Schema v1

```yaml
version: 1
monorepo: false
last_updated: 2024-01-15T10:30:00Z

packages:
  - name: app_main
    path: .
    keys:
      - id: "home.title"
        path: "lib/ui/home.dart:HomeTitle"
        tags: ["aqa", "e2e", "critical"]
        status: "active"  # active|deprecated|reserved|removed
        notes: "Main home screen title"
      
      - id: "profile.save_button"
        path: "lib/ui/profile.dart:SaveButton"
        tags: ["e2e"]
        status: "active"

  - name: feature_auth
    path: packages/feature_auth
    keys:
      - id: "auth.login_button"
        path: "lib/src/login.dart:42"
        tags: ["critical", "aqa"]
        status: "active"

policies:
  fail_on_lost: true
  fail_on_rename: false
  fail_on_extra: false
  protected_tags: ["critical", "aqa"]
  drift_threshold: 10
```

### Key Lifecycle

```
reserved → active → deprecated → removed
```

- **reserved**: Planned but not yet implemented
- **active**: Currently in use
- **deprecated**: Scheduled for removal
- **removed**: No longer allowed in code

## 🔄 Sync Mechanisms

### A. Git-based Registry (Recommended)

```bash
# Add registry as submodule
git submodule add git@gitlab.com:org/key-registry.git tools/key-registry

# Sync in CI
flutter_keycheck sync --registry git --repo $KEY_REGISTRY_REPO

# Update baseline (manual)
flutter_keycheck baseline update
git -C tools/key-registry add .
git -C tools/key-registry commit -m "Update baseline"
git -C tools/key-registry push
```

### B. Package-based Registry

```yaml
# pubspec.yaml
dev_dependencies:
  key_registry: ^1.0.0

# Sync from package
flutter_keycheck sync --registry pkg --package key_registry
```

### C. Storage-based Registry

```bash
# S3/GCS/MinIO
flutter_keycheck sync --registry storage --url s3://bucket/key-registry.yaml
```

## 🏗️ GitLab CI Integration

### Basic Setup

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/1nk1/flutter_keycheck/main/gitlab-ci-template.yml'

variables:
  KEY_REGISTRY_REPO: "git@gitlab.com:org/key-registry.git"
```

### Custom Configuration

```yaml
stages:
  - validate

validate:keycheck:
  stage: validate
  image: dart:stable
  cache:
    key: "pub-${CI_COMMIT_REF_SLUG}"
    paths: [.pub-cache/]
  variables:
    PUB_CACHE: "$CI_PROJECT_DIR/.pub-cache"
  before_script:
    - dart pub global activate flutter_keycheck
    - git submodule update --init --recursive
  script:
    - flutter_keycheck sync --registry git --repo "$KEY_REGISTRY_REPO"
    - flutter_keycheck scan --packages resolve --report json --out-dir reports
    - flutter_keycheck validate --strict --fail-on-lost --report json,junit,md --out-dir reports
  artifacts:
    when: always
    paths: [reports/]
    reports:
      junit: reports/validation-report.xml
```

### Merge Request Integration

```yaml
# Post validation results as MR comment
- |
  if [ -n "$CI_MERGE_REQUEST_IID" ]; then
    flutter_keycheck report --format md > mr-comment.md
    # Use GitLab API to post comment
    curl -X POST \
      -H "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
      -d @mr-comment.md \
      "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
  fi
```

## 📦 Multi-Package Support

### Workspace Scanning

Automatically resolves and scans dependencies:

```bash
# Scan app + all dependencies
flutter_keycheck scan --packages resolve

# Include dev dependencies
flutter_keycheck scan --packages resolve --include-dev

# Specific packages only
flutter_keycheck scan --packages workspace --filter "feature_*"
```

### Monorepo Configuration

```yaml
# .flutter_keycheck.yaml at repo root
monorepo: true
packages:
  - path: apps/customer
    name: customer_app
  - path: apps/admin
    name: admin_app
  - path: packages/shared
    name: shared_components

# Scan all packages
flutter_keycheck scan --monorepo
```

## 📊 Reporting

### JSON Schema v1

```json
{
  "schema_version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "scanned_packages": ["app_main", "feature_auth"],
  "summary": {
    "total_keys": 150,
    "lost": 2,
    "added": 5,
    "renamed": 1,
    "deprecated_in_use": 3,
    "drift_percentage": 5.3
  },
  "violations": [
    {
      "type": "lost",
      "severity": "error",
      "key": {
        "id": "home.title",
        "package": "app_main",
        "tags": ["critical"],
        "last_seen": "lib/ui/home.dart:42"
      },
      "message": "Critical key 'home.title' not found",
      "remediation": "Restore key or update registry"
    }
  ]
}
```

### JUnit Output

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Flutter KeyCheck" tests="5" failures="2">
  <testsuite name="app_main" tests="3" failures="1">
    <testcase name="Key: home.title" classname="Lost">
      <failure message="Critical key not found">
        Key 'home.title' with tags [critical] was not found in scan.
        Last seen at: lib/ui/home.dart:42
        Remediation: Restore key or update registry
      </failure>
    </testcase>
  </testsuite>
</testsuites>
```

### Markdown Report

```markdown
## 🔑 Key Validation Report

### Summary
- **Total Keys**: 150
- **Lost**: 2 🔥
- **Added**: 5 ➕
- **Renamed**: 1 ♻️
- **Drift**: 5.3% 📈

### Critical Issues
| Type | Key | Package | Tags | Action |
|------|-----|---------|------|--------|
| 🔥 Lost | home.title | app_main | critical, aqa | Restore key |
| 🔥 Lost | auth.login | feature_auth | critical | Update registry |

### Warnings
- 3 deprecated keys still in use
- Drift approaching threshold (5.3% of 10%)
```

## ⚙️ Configuration

### Project Configuration

```yaml
# .flutter_keycheck.yaml
version: 1
monorepo: false

# Registry settings
registry:
  type: git
  repo: git@gitlab.com:org/key-registry.git
  branch: main
  path: key-registry.yaml

# Scanning
scan:
  packages: resolve
  include_tests: false
  include_generated: false
  exclude_patterns:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

# Validation policies
policies:
  fail_on_lost: true
  fail_on_rename: false
  fail_on_extra: false
  protected_tags:
    - critical
    - aqa
  max_drift: 10

# Reporting
report:
  formats: [json, junit]
  out_dir: reports
```

### Tag Management

```yaml
# Tagging strategy
tags:
  critical:     # Cannot be lost or renamed
    - auth.*
    - payment.*
  
  aqa:          # QA automation
    - "*.button"
    - "*.field"
  
  e2e:          # End-to-end tests
    - login.*
    - checkout.*
  
  experimental: # Can be changed freely
    - feature_flag.*
```

## 🛡️ Security & Compliance

- **Read-only scanning**: Never modifies source code
- **Secure sync**: SSH/HTTPS for Git, signed URLs for storage
- **Audit trail**: All registry changes tracked in Git
- **Role-based access**: Registry repo permissions
- **Compliance reports**: JSON/JUnit for audit tools

## 🔄 Migration from v2

```bash
# Export v2 keys
flutter_keycheck --generate-keys > old-keys.yaml

# Import to v3 registry
flutter_keycheck migrate --from-v2 old-keys.yaml

# Create initial baseline
flutter_keycheck baseline create --auto-tags
```

## 📚 Advanced Features

### Rename Detection

```yaml
# rename-map.yaml
renames:
  - old: "login_button"
    new: "auth.login_button"
    date: "2024-01-15"
    reason: "Namespace standardization"
```

### Namespace Enforcement

```bash
# Enforce naming convention
flutter_keycheck validate --enforce-namespace "app."
```

### Protected Tags

```bash
# Critical tags cannot be lost
flutter_keycheck validate --guard tags=critical --deny-lost --deny-rename
```

### Incremental Scanning

```bash
# Scan only changed files since last commit
flutter_keycheck scan --since HEAD~1
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links

- [pub.dev package](https://pub.dev/packages/flutter_keycheck)
- [GitHub repository](https://github.com/1nk1/flutter_keycheck)
- [GitLab templates](https://gitlab.com/flutter-keycheck/templates)
- [Issue tracker](https://github.com/1nk1/flutter_keycheck/issues)

---

Made with ❤️ for Flutter teams worldwide