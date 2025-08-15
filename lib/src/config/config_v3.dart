import 'dart:io';
import 'package:yaml/yaml.dart';

/// Configuration for flutter_keycheck v3
class ConfigV3 {
  String version = '3';
  bool monorepo = false;
  bool verbose = false;
  
  // Registry settings
  final RegistryConfig registry;
  
  // Scanning settings
  final ScanConfig scan;
  
  // Policy settings
  final PolicyConfig policies;
  
  // Reporting settings
  final ReportConfig report;

  ConfigV3({
    required this.registry,
    required this.scan,
    required this.policies,
    required this.report,
  });

  /// Load configuration from file
  static Future<ConfigV3> load(String path) async {
    final file = File(path);
    
    // Create default config if file doesn't exist
    if (!await file.exists()) {
      return ConfigV3.defaults();
    }
    
    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map;
    
    return ConfigV3(
      registry: RegistryConfig.fromYaml(yaml['registry'] ?? {}),
      scan: ScanConfig.fromYaml(yaml['scan'] ?? {}),
      policies: PolicyConfig.fromYaml(yaml['policies'] ?? {}),
      report: ReportConfig.fromYaml(yaml['report'] ?? {}),
    )
      ..version = yaml['version']?.toString() ?? '3'
      ..monorepo = yaml['monorepo'] ?? false;
  }

  /// Create default configuration
  factory ConfigV3.defaults() {
    return ConfigV3(
      registry: RegistryConfig.defaults(),
      scan: ScanConfig.defaults(),
      policies: PolicyConfig.defaults(),
      report: ReportConfig.defaults(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'monorepo': monorepo,
      'registry': registry.toMap(),
      'scan': scan.toMap(),
      'policies': policies.toMap(),
      'report': report.toMap(),
    };
  }
}

/// Registry configuration
class RegistryConfig {
  String type;
  String? repo;
  String? branch;
  String? path;
  String? url;
  String? package;

  RegistryConfig({
    required this.type,
    this.repo,
    this.branch,
    this.path,
    this.url,
    this.package,
  });

  factory RegistryConfig.fromYaml(Map yaml) {
    return RegistryConfig(
      type: yaml['type'] ?? 'git',
      repo: yaml['repo'],
      branch: yaml['branch'] ?? 'main',
      path: yaml['path'] ?? 'key-registry.yaml',
      url: yaml['url'],
      package: yaml['package'],
    );
  }

  factory RegistryConfig.defaults() {
    return RegistryConfig(
      type: 'git',
      branch: 'main',
      path: 'key-registry.yaml',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'repo': repo,
      'branch': branch,
      'path': path,
      'url': url,
      'package': package,
    };
  }
}

/// Scan configuration
class ScanConfig {
  String packages;
  bool includeTests;
  bool includeGenerated;
  List<String> excludePatterns;

  ScanConfig({
    required this.packages,
    required this.includeTests,
    required this.includeGenerated,
    required this.excludePatterns,
  });

  factory ScanConfig.fromYaml(Map yaml) {
    return ScanConfig(
      packages: yaml['packages'] ?? 'workspace',
      includeTests: yaml['include_tests'] ?? false,
      includeGenerated: yaml['include_generated'] ?? false,
      excludePatterns: List<String>.from(yaml['exclude_patterns'] ?? []),
    );
  }

  factory ScanConfig.defaults() {
    return ScanConfig(
      packages: 'workspace',
      includeTests: false,
      includeGenerated: false,
      excludePatterns: [
        '**/*.g.dart',
        '**/*.freezed.dart',
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packages': packages,
      'include_tests': includeTests,
      'include_generated': includeGenerated,
      'exclude_patterns': excludePatterns,
    };
  }
}

/// Policy configuration
class PolicyConfig {
  bool failOnLost;
  bool failOnRename;
  bool failOnExtra;
  List<String> protectedTags;
  double maxDrift;

  PolicyConfig({
    required this.failOnLost,
    required this.failOnRename,
    required this.failOnExtra,
    required this.protectedTags,
    required this.maxDrift,
  });

  factory PolicyConfig.fromYaml(Map yaml) {
    return PolicyConfig(
      failOnLost: yaml['fail_on_lost'] ?? true,
      failOnRename: yaml['fail_on_rename'] ?? false,
      failOnExtra: yaml['fail_on_extra'] ?? false,
      protectedTags: List<String>.from(yaml['protected_tags'] ?? ['critical', 'aqa']),
      maxDrift: (yaml['max_drift'] ?? 10).toDouble(),
    );
  }

  factory PolicyConfig.defaults() {
    return PolicyConfig(
      failOnLost: true,
      failOnRename: false,
      failOnExtra: false,
      protectedTags: ['critical', 'aqa'],
      maxDrift: 10.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fail_on_lost': failOnLost,
      'fail_on_rename': failOnRename,
      'fail_on_extra': failOnExtra,
      'protected_tags': protectedTags,
      'max_drift': maxDrift,
    };
  }
}

/// Report configuration
class ReportConfig {
  List<String> formats;
  String outDir;

  ReportConfig({
    required this.formats,
    required this.outDir,
  });

  factory ReportConfig.fromYaml(Map yaml) {
    return ReportConfig(
      formats: List<String>.from(yaml['formats'] ?? ['json', 'junit']),
      outDir: yaml['out_dir'] ?? 'reports',
    );
  }

  factory ReportConfig.defaults() {
    return ReportConfig(
      formats: ['json', 'junit'],
      outDir: 'reports',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formats': formats,
      'out_dir': outDir,
    };
  }
}