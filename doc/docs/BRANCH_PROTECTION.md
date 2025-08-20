# Branch Protection Configuration

This document describes the required branch protection settings for the `flutter_keycheck` repository.

## Main Branch Protection Rules

Configure these settings in GitHub: Settings → Branches → Add rule → Branch name pattern: `main`

### Required Status Checks

The following checks MUST pass before merging to main:

#### Core Quality Checks
- ✅ **Test & Analyze (stable)** - Core test suite and static analysis
- ✅ **CLI Smoke Tests** - CLI functionality verification
- ✅ **Package Quality Check** - Pana score and pub.dev readiness

#### Golden Baseline Gates
- ✅ **Golden Snapshot Verification** - Schema and key validation
- ✅ **Golden Snapshot Check** (PR only) - Baseline comparison
- ✅ **Performance Regression Check** - Performance threshold validation
- ✅ **Performance Check** (PR only) - Regression detection

### Protection Settings

Enable these protection rules:

- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - [x] Status checks required:
    - `Test & Analyze (stable)`
    - `Golden Snapshot Verification`
    - `Performance Regression Check`
    - `CLI Smoke Tests`
    - `Package Quality Check`

- [x] **Require a pull request before merging**
  - [x] Require approvals: 1
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from CODEOWNERS (if configured)

- [x] **Require conversation resolution before merging**

- [x] **Require signed commits** (optional but recommended)

- [x] **Do not allow bypassing the above settings**
  - Even administrators should follow the process

- [x] **Restrict who can push to matching branches**
  - Add maintainers and CI service accounts only

## Pull Request Validation

PRs targeting main automatically run:

1. **Quick PR Validation** - Format, analyze, test basics
2. **Golden Snapshot Check** - Verify against baseline
3. **Performance Check** - Detect regressions >20%

## Release Tag Protection

For version tags (`v3.*`):

- [x] **Restrict who can create matching tags**
  - Only maintainers and release automation
- [x] **Require status checks for tag creation**
  - All release gate validations must pass

## CI Required Jobs Summary

### Always Required (Blocking)
| Job Name | Purpose | Failure Action |
|----------|---------|----------------|
| Test & Analyze (stable) | Core functionality | Fix code issues |
| Golden Snapshot Verification | Schema/key validation | Update baseline if legitimate |
| Performance Regression Check | Performance gates | Optimize or update baseline |
| CLI Smoke Tests | CLI functionality | Fix CLI issues |
| Package Quality Check | pub.dev readiness | Fix package issues |

### PR-Only Checks
| Job Name | Purpose | Failure Action |
|----------|---------|----------------|
| Golden Snapshot Check | Baseline comparison | Review changes |
| Performance Check | Regression detection | Optimize code |

## Baseline Update Process

If a PR legitimately needs to update baselines:

1. **Developer updates baseline locally:**
   ```bash
   dart run tool/update_baseline.dart
   ```

2. **Commit with rationale:**
   ```bash
   git add test/golden_workspace/
   git commit -m "chore(baseline): update golden snapshot
     
     - Reason: [specific reason for change]
     - Schema changes: [if any]
     - Performance impact: [measured impact]
     - Critical keys: [any changes to critical keys]"
   ```

3. **PR must include:**
   - Clear justification in PR description
   - Before/after metrics
   - Review from maintainer who understands the impact

## Emergency Procedures

### Bypassing Protection (Emergency Only)

If protection must be bypassed in an emergency:

1. Document the emergency in the PR/commit
2. Create follow-up issue to address properly
3. Notify all maintainers
4. Review in next team meeting

### Rolling Back Failed Releases

If a release fails quality gates:

1. Revert the problematic commits
2. Fix issues in a new PR with full validation
3. Re-run release process

## Monitoring & Alerts

Set up GitHub notifications for:

- Failed required status checks on main
- Performance regressions >20%
- Golden snapshot mismatches
- Package quality score drops

## Review Cadence

Review and update these settings:

- Monthly: Check if all required jobs are running
- Quarterly: Review baseline drift and update if needed
- Annually: Audit entire protection configuration

---

Last Updated: 2025-01-16
Next Review: 2025-02-16