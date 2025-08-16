import 'dart:convert';
import 'package:yaml/yaml.dart';

/// Key Registry schema v1
class KeyRegistry {
  final int version;
  final bool monorepo;
  final List<PackageKeys> packages;
  final RegistryPolicies policies;
  final DateTime? lastUpdated;

  KeyRegistry({
    this.version = 1,
    this.monorepo = false,
    required this.packages,
    required this.policies,
    this.lastUpdated,
  });

  factory KeyRegistry.fromYaml(String yaml) {
    final doc = loadYaml(yaml) as Map;
    
    return KeyRegistry(
      version: doc['version'] as int? ?? 1,
      monorepo: doc['monorepo'] as bool? ?? false,
      packages: (doc['packages'] as List? ?? [])
          .map((p) => PackageKeys.fromMap(p as Map<dynamic, dynamic>))
          .toList(),
      policies: RegistryPolicies.fromMap(
        doc['policies'] as Map<dynamic, dynamic>? ?? {},
      ),
      lastUpdated: doc['last_updated'] != null
          ? DateTime.parse(doc['last_updated'] as String)
          : null,
    );
  }

  factory KeyRegistry.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    
    return KeyRegistry(
      version: map['version'] as int? ?? 1,
      monorepo: map['monorepo'] as bool? ?? false,
      packages: (map['packages'] as List? ?? [])
          .map((p) => PackageKeys.fromMap(p as Map<String, dynamic>))
          .toList(),
      policies: RegistryPolicies.fromMap(
        map['policies'] as Map<String, dynamic>? ?? {},
      ),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'monorepo': monorepo,
        'packages': packages.map((p) => p.toMap()).toList(),
        'policies': policies.toMap(),
        if (lastUpdated != null) 'last_updated': lastUpdated!.toIso8601String(),
      };

  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('version: $version');
    buffer.writeln('monorepo: $monorepo');
    if (lastUpdated != null) {
      buffer.writeln('last_updated: ${lastUpdated!.toIso8601String()}');
    }
    
    buffer.writeln('packages:');
    for (final package in packages) {
      buffer.writeln('  - name: ${package.name}');
      buffer.writeln('    path: ${package.path}');
      buffer.writeln('    keys:');
      for (final key in package.keys) {
        buffer.writeln('      - id: "${key.id}"');
        buffer.writeln('        path: "${key.path}"');
        buffer.writeln('        tags: ${jsonEncode(key.tags)}');
        buffer.writeln('        status: "${key.status.name}"');
        if (key.notes != null) {
          buffer.writeln('        notes: "${key.notes}"');
        }
      }
    }
    
    buffer.writeln('policies:');
    buffer.writeln('  fail_on_lost: ${policies.failOnLost}');
    buffer.writeln('  fail_on_rename: ${policies.failOnRename}');
    buffer.writeln('  fail_on_extra: ${policies.failOnExtra}');
    buffer.writeln('  protected_tags: ${jsonEncode(policies.protectedTags)}');
    buffer.writeln('  drift_threshold: ${policies.driftThreshold}');
    
    return buffer.toString();
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());
}

/// Package-level key definitions
class PackageKeys {
  final String name;
  final String path;
  final List<KeyDefinition> keys;

  PackageKeys({
    required this.name,
    required this.path,
    required this.keys,
  });

  factory PackageKeys.fromMap(Map<dynamic, dynamic> map) {
    return PackageKeys(
      name: map['name'] as String,
      path: map['path'] as String? ?? '.',
      keys: (map['keys'] as List? ?? [])
          .map((k) => KeyDefinition.fromMap(k as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'path': path,
        'keys': keys.map((k) => k.toMap()).toList(),
      };
}

/// Individual key definition
class KeyDefinition {
  final String id;
  final String path;
  final List<String> tags;
  final KeyStatus status;
  final String? notes;
  final DateTime? addedAt;
  final DateTime? deprecatedAt;

  KeyDefinition({
    required this.id,
    required this.path,
    this.tags = const [],
    this.status = KeyStatus.active,
    this.notes,
    this.addedAt,
    this.deprecatedAt,
  });

  factory KeyDefinition.fromMap(Map<dynamic, dynamic> map) {
    return KeyDefinition(
      id: map['id'] as String,
      path: map['path'] as String,
      tags: (map['tags'] as List? ?? []).cast<String>(),
      status: KeyStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? 'active'),
        orElse: () => KeyStatus.active,
      ),
      notes: map['notes'] as String?,
      addedAt: map['added_at'] != null
          ? DateTime.parse(map['added_at'] as String)
          : null,
      deprecatedAt: map['deprecated_at'] != null
          ? DateTime.parse(map['deprecated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'tags': tags,
        'status': status.name,
        if (notes != null) 'notes': notes,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
        if (deprecatedAt != null) 'deprecated_at': deprecatedAt!.toIso8601String(),
      };

  bool hasTag(String tag) => tags.contains(tag);
  
  bool hasAnyTag(List<String> checkTags) => 
      checkTags.any((tag) => tags.contains(tag));
}

/// Key lifecycle status
enum KeyStatus {
  active,
  deprecated,
  reserved,
  removed,
}

/// Registry-level policies
class RegistryPolicies {
  final bool failOnLost;
  final bool failOnRename;
  final bool failOnExtra;
  final List<String> protectedTags;
  final int driftThreshold;
  final Map<String, dynamic> custom;

  RegistryPolicies({
    this.failOnLost = true,
    this.failOnRename = false,
    this.failOnExtra = false,
    this.protectedTags = const [],
    this.driftThreshold = 0,
    this.custom = const {},
  });

  factory RegistryPolicies.fromMap(Map<dynamic, dynamic> map) {
    return RegistryPolicies(
      failOnLost: map['fail_on_lost'] as bool? ?? true,
      failOnRename: map['fail_on_rename'] as bool? ?? false,
      failOnExtra: map['fail_on_extra'] as bool? ?? false,
      protectedTags: (map['protected_tags'] as List? ?? []).cast<String>(),
      driftThreshold: map['drift_threshold'] as int? ?? 0,
      custom: Map<String, dynamic>.from(map)
        ..removeWhere((key, _) => [
              'fail_on_lost',
              'fail_on_rename',
              'fail_on_extra',
              'protected_tags',
              'drift_threshold',
            ].contains(key)),
    );
  }

  Map<String, dynamic> toMap() => {
        'fail_on_lost': failOnLost,
        'fail_on_rename': failOnRename,
        'fail_on_extra': failOnExtra,
        'protected_tags': protectedTags,
        'drift_threshold': driftThreshold,
        ...custom,
      };
}