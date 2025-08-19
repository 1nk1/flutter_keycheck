import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

/// Represents a package dependency with its metadata
class PackageDependency {
  final String name;
  final String version;
  final String source; // 'hosted', 'path', 'git'
  final String resolvedPath;
  final Set<String> directDependencies;
  final Map<String, dynamic> metadata;
  final int depth; // Distance from root package

  PackageDependency({
    required this.name,
    required this.version,
    required this.source,
    required this.resolvedPath,
    required this.directDependencies,
    this.metadata = const {},
    this.depth = 0,
  });

  String get fullName => '$name@$version';
  
  Map<String, dynamic> toMap() => {
    'name': name,
    'version': version,
    'source': source,
    'path': resolvedPath,
    'dependencies': directDependencies.toList(),
    'depth': depth,
    'metadata': metadata,
  };
}

/// Resolves full transitive dependency tree for Flutter/Dart projects
class DependencyResolver {
  final String projectPath;
  final bool includeDevDependencies;
  final int maxDepth;
  final Set<String>? packageFilter;
  final bool verbose;

  // Cache resolved packages to avoid circular dependencies
  final Map<String, PackageDependency> _resolvedPackages = {};
  final Set<String> _visited = {};

  DependencyResolver({
    required this.projectPath,
    this.includeDevDependencies = false,
    this.maxDepth = 10,
    this.packageFilter,
    this.verbose = false,
  });

  /// Resolve all dependencies (direct and transitive)
  Future<Map<String, PackageDependency>> resolveDependencies() async {
    _resolvedPackages.clear();
    _visited.clear();

    // Start with the root project
    final rootPubspec = File(path.join(projectPath, 'pubspec.yaml'));
    if (!rootPubspec.existsSync()) {
      throw Exception('No pubspec.yaml found in $projectPath');
    }

    // Parse root pubspec
    final rootContent = rootPubspec.readAsStringSync();
    final rootYaml = yaml.loadYaml(rootContent) as Map;
    final rootName = rootYaml['name'] as String? ?? 'root';
    final rootVersion = rootYaml['version'] as String? ?? '0.0.0';

    // Ensure pub get has been run
    await _ensurePubGet();

    // Load package_config.json for resolution information
    final packageConfig = await _loadPackageConfig();
    if (packageConfig == null) {
      throw Exception('Could not load package configuration. Run "flutter pub get" first.');
    }

    // Build dependency graph starting from root
    await _resolveDependenciesRecursive(
      packageName: rootName,
      packageVersion: rootVersion,
      packageConfig: packageConfig,
      depth: 0,
    );

    return _resolvedPackages;
  }

  /// Get only direct dependencies
  Future<Set<String>> getDirectDependencies() async {
    final pubspec = File(path.join(projectPath, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return {};
    }

    final content = pubspec.readAsStringSync();
    final yamlDoc = yaml.loadYaml(content) as Map;
    
    final dependencies = <String>{};
    
    // Add regular dependencies
    final deps = yamlDoc['dependencies'] as Map?;
    if (deps != null) {
      dependencies.addAll(deps.keys.cast<String>());
    }
    
    // Add dev dependencies if requested
    if (includeDevDependencies) {
      final devDeps = yamlDoc['dev_dependencies'] as Map?;
      if (devDeps != null) {
        dependencies.addAll(devDeps.keys.cast<String>());
      }
    }
    
    return dependencies;
  }

  /// Recursively resolve dependencies
  Future<void> _resolveDependenciesRecursive({
    required String packageName,
    required String packageVersion,
    required Map<String, dynamic> packageConfig,
    required int depth,
  }) async {
    // Check max depth
    if (depth > maxDepth) {
      if (verbose) {
        print('  Skipping $packageName@$packageVersion (max depth reached)');
      }
      return;
    }

    // Check if already visited (circular dependency prevention)
    final packageKey = '$packageName@$packageVersion';
    if (_visited.contains(packageKey)) {
      return;
    }
    _visited.add(packageKey);

    // Apply package filter if specified
    if (packageFilter != null && !packageFilter!.contains(packageName)) {
      return;
    }

    // Find package in package_config.json
    final packages = packageConfig['packages'] as List;
    final packageInfo = packages.firstWhere(
      (p) => p['name'] == packageName,
      orElse: () => null,
    );

    if (packageInfo == null) {
      if (verbose) {
        print('  Warning: Package $packageName not found in package_config.json');
      }
      return;
    }

    // Get package path
    final packageUri = packageInfo['rootUri'] as String;
    String packagePath;
    
    if (packageUri.startsWith('file://')) {
      packagePath = Uri.parse(packageUri).toFilePath();
    } else if (packageUri.startsWith('../')) {
      packagePath = path.normalize(
        path.join(projectPath, '.dart_tool', packageUri)
      );
    } else {
      packagePath = path.join(projectPath, '.dart_tool', packageUri);
    }

    // Read package's pubspec to get its dependencies
    final packagePubspec = File(path.join(packagePath, 'pubspec.yaml'));
    final directDeps = <String>{};
    
    if (packagePubspec.existsSync()) {
      try {
        final content = packagePubspec.readAsStringSync();
        final yamlDoc = yaml.loadYaml(content) as Map;
        
        // Get package version from pubspec if not provided
        if (packageVersion.isEmpty || packageVersion == '0.0.0') {
          packageVersion = yamlDoc['version'] as String? ?? '0.0.0';
        }
        
        // Extract dependencies
        final deps = yamlDoc['dependencies'] as Map?;
        if (deps != null) {
          directDeps.addAll(deps.keys.cast<String>());
        }
        
        // Include dev dependencies for root package or if requested
        if (depth == 0 || includeDevDependencies) {
          final devDeps = yamlDoc['dev_dependencies'] as Map?;
          if (devDeps != null) {
            directDeps.addAll(devDeps.keys.cast<String>());
          }
        }
      } catch (e) {
        if (verbose) {
          print('  Warning: Could not parse pubspec for $packageName: $e');
        }
      }
    }

    // Determine source type
    String source = 'hosted';
    if (packageUri.contains('pub.dev') || packageUri.contains('pub.dartlang.org')) {
      source = 'hosted';
    } else if (packageUri.startsWith('..')) {
      source = 'path';
    } else if (packageUri.contains('.git')) {
      source = 'git';
    }

    // Create package dependency
    final dependency = PackageDependency(
      name: packageName,
      version: packageVersion,
      source: source,
      resolvedPath: packagePath,
      directDependencies: directDeps,
      depth: depth,
      metadata: {
        'uri': packageUri,
        'language_version': packageInfo['languageVersion'] ?? 'unknown',
      },
    );

    // Store resolved package
    _resolvedPackages[packageKey] = dependency;

    if (verbose) {
      final indent = '  ' * depth;
      print('$indent📦 $packageName@$packageVersion (${directDeps.length} deps)');
    }

    // Recursively resolve dependencies
    for (final depName in directDeps) {
      await _resolveDependenciesRecursive(
        packageName: depName,
        packageVersion: '', // Will be resolved from its pubspec
        packageConfig: packageConfig,
        depth: depth + 1,
      );
    }
  }

  /// Ensure pub get has been run
  Future<void> _ensurePubGet() async {
    final packageConfigFile = File(
      path.join(projectPath, '.dart_tool', 'package_config.json')
    );

    if (!packageConfigFile.existsSync()) {
      if (verbose) {
        print('Running pub get to resolve dependencies...');
      }

      // Try flutter pub get first, fallback to dart pub get
      ProcessResult result;
      try {
        result = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      } on ProcessException {
        result = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      }

      if (result.exitCode != 0) {
        throw Exception('Failed to run pub get: ${result.stderr}');
      }
    }
  }

  /// Load package_config.json
  Future<Map<String, dynamic>?> _loadPackageConfig() async {
    final packageConfigFile = File(
      path.join(projectPath, '.dart_tool', 'package_config.json')
    );

    if (!packageConfigFile.existsSync()) {
      return null;
    }

    try {
      final content = packageConfigFile.readAsStringSync();
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      if (verbose) {
        print('Error loading package_config.json: $e');
      }
      return null;
    }
  }

  /// Get dependency statistics
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{
      'total_packages': _resolvedPackages.length,
      'direct_dependencies': 0,
      'transitive_dependencies': 0,
      'max_depth': 0,
      'by_source': <String, int>{},
      'by_depth': <int, int>{},
    };

    for (final package in _resolvedPackages.values) {
      // Count by depth
      if (package.depth == 1) {
        stats['direct_dependencies'] = (stats['direct_dependencies'] as int) + 1;
      } else if (package.depth > 1) {
        stats['transitive_dependencies'] = (stats['transitive_dependencies'] as int) + 1;
      }

      // Track max depth
      if (package.depth > (stats['max_depth'] as int)) {
        stats['max_depth'] = package.depth;
      }

      // Count by source
      final bySource = stats['by_source'] as Map<String, int>;
      bySource[package.source] = (bySource[package.source] ?? 0) + 1;

      // Count by depth
      final byDepth = stats['by_depth'] as Map<int, int>;
      byDepth[package.depth] = (byDepth[package.depth] ?? 0) + 1;
    }

    return stats;
  }

  /// Export dependency tree as JSON
  String exportAsJson({bool pretty = true}) {
    final tree = {
      'project': projectPath,
      'timestamp': DateTime.now().toIso8601String(),
      'statistics': getStatistics(),
      'dependencies': _resolvedPackages.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(tree);
    }
    return json.encode(tree);
  }

  /// Get packages at specific depth level
  List<PackageDependency> getPackagesAtDepth(int depth) {
    return _resolvedPackages.values
        .where((p) => p.depth == depth)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find circular dependencies
  List<List<String>> findCircularDependencies() {
    final cycles = <List<String>>[];
    final visited = <String>{};
    final recursionStack = <String>[];

    for (final package in _resolvedPackages.keys) {
      if (!visited.contains(package)) {
        _findCyclesRecursive(
          package,
          visited,
          recursionStack,
          cycles,
        );
      }
    }

    return cycles;
  }

  void _findCyclesRecursive(
    String packageKey,
    Set<String> visited,
    List<String> recursionStack,
    List<List<String>> cycles,
  ) {
    visited.add(packageKey);
    recursionStack.add(packageKey);

    final package = _resolvedPackages[packageKey];
    if (package != null) {
      for (final dep in package.directDependencies) {
        final depKey = _resolvedPackages.keys.firstWhere(
          (k) => k.startsWith('$dep@'),
          orElse: () => '',
        );

        if (depKey.isNotEmpty) {
          if (recursionStack.contains(depKey)) {
            // Found a cycle
            final cycleStart = recursionStack.indexOf(depKey);
            cycles.add(recursionStack.sublist(cycleStart).toList()..add(depKey));
          } else if (!visited.contains(depKey)) {
            _findCyclesRecursive(depKey, visited, recursionStack, cycles);
          }
        }
      }
    }

    recursionStack.removeLast();
  }
}