/// Security & Compliance Analyst Agent for Claude Code
///
/// Mission: Prevent leakage of sensitive strings via keys, detect insecure patterns, 
/// and align with secure coding/checklist.
///
/// Primary Responsibilities:
/// - Flag keys derived from PII or secrets
/// - Enforce deny-lists/allow-lists and SOC2/OWASP-inspired checks
/// - Produce risk reports usable by auditors
///
/// Inputs:
/// - Security policy (regex/globs), SARIF settings, exception registry
///
/// Outputs:
/// - reports/security/findings.sarif, reports/security/summary.md
///
/// Hooks & Triggers:
/// - pre-edit: immediate flag on newly introduced risks
/// - post-task: update risk score trend
///
/// MCP Tools:
/// - security_scan, backup_create, restore_system, features_detect
///
/// KPIs:
/// - 0 critical leaks on main branch
/// - Mean time to remediation < 2 days
///
/// Safeguards:
/// - False-positive suppression with evidence links
/// - No raw secret content in logs—hash only
///
export '../policy/policy_engine.dart' show PolicyEngine;
export '../models/validation_result.dart' show ValidationResult;
