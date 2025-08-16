import 'dart:convert';

/// Validation result with violations and summary
class ValidationResult {
  final ValidationSummary summary;
  final List<Violation> violations;
  final List<String> warnings;
  final DateTime timestamp;
  final bool hasViolations;

  ValidationResult({
    required this.summary,
    required this.violations,
    required this.warnings,
    required this.timestamp,
  }) : hasViolations = violations.isNotEmpty;

  bool get passed => !hasViolations;

  Map<String, dynamic> toMap() {
    return {
      'schema_version': '1.0',
      'timestamp': timestamp.toIso8601String(),
      'summary': summary.toMap(),
      'violations': violations.map((e) => e.toMap()).toList(),
      'warnings': warnings,
      'has_violations': hasViolations,
    };
  }

  factory ValidationResult.fromMap(Map<String, dynamic> map) {
    return ValidationResult(
      summary: ValidationSummary.fromMap(map['summary']),
      violations: List<Violation>.from(
        (map['violations'] ?? []).map((x) => Violation.fromMap(x)),
      ),
      warnings: List<String>.from(map['warnings'] ?? []),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  String toJson() => json.encode(toMap());
  
  factory ValidationResult.fromJson(String source) => 
      ValidationResult.fromMap(json.decode(source));
}

/// Validation summary statistics
class ValidationSummary {
  final int totalKeys;
  final int lostKeys;
  final int addedKeys;
  final int renamedKeys;
  final int deprecatedInUse;
  final double driftPercentage;
  final List<String> scannedPackages;

  ValidationSummary({
    required this.totalKeys,
    required this.lostKeys,
    required this.addedKeys,
    required this.renamedKeys,
    required this.deprecatedInUse,
    required this.driftPercentage,
    required this.scannedPackages,
  });

  Map<String, dynamic> toMap() {
    return {
      'total_keys': totalKeys,
      'lost': lostKeys,
      'added': addedKeys,
      'renamed': renamedKeys,
      'deprecated_in_use': deprecatedInUse,
      'drift_percentage': driftPercentage,
      'scanned_packages': scannedPackages,
    };
  }

  factory ValidationSummary.fromMap(Map<String, dynamic> map) {
    return ValidationSummary(
      totalKeys: map['total_keys'] ?? 0,
      lostKeys: map['lost'] ?? 0,
      addedKeys: map['added'] ?? 0,
      renamedKeys: map['renamed'] ?? 0,
      deprecatedInUse: map['deprecated_in_use'] ?? 0,
      driftPercentage: (map['drift_percentage'] ?? 0).toDouble(),
      scannedPackages: List<String>.from(map['scanned_packages'] ?? []),
    );
  }
}

/// Policy violation
class Violation {
  final String type;
  final String severity;
  final KeyInfo? key;
  final String message;
  final String remediation;
  final String? policy;

  Violation({
    required this.type,
    required this.severity,
    this.key,
    required this.message,
    required this.remediation,
    this.policy,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'key': key?.toMap(),
      'message': message,
      'remediation': remediation,
      'policy': policy,
    };
  }

  factory Violation.fromMap(Map<String, dynamic> map) {
    return Violation(
      type: map['type'],
      severity: map['severity'],
      key: map['key'] != null ? KeyInfo.fromMap(map['key']) : null,
      message: map['message'],
      remediation: map['remediation'],
      policy: map['policy'],
    );
  }
}

/// Key information for violations
class KeyInfo {
  final String id;
  final String package;
  final List<String> tags;
  final String? lastSeen;
  final String status;

  KeyInfo({
    required this.id,
    required this.package,
    required this.tags,
    this.lastSeen,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package': package,
      'tags': tags,
      'last_seen': lastSeen,
      'status': status,
    };
  }

  factory KeyInfo.fromMap(Map<String, dynamic> map) {
    return KeyInfo(
      id: map['id'],
      package: map['package'],
      tags: List<String>.from(map['tags'] ?? []),
      lastSeen: map['last_seen'],
      status: map['status'] ?? 'active',
    );
  }
}