import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// KeyConstants resolver that maps constant names to their string values
class KeyConstantsResolver {
  final String projectPath;
  final Map<String, String> _constantsCache = {};
  final Map<String, String> _dynamicMethodsCache = {};
  String? _keyConstantsFilePath;

  KeyConstantsResolver(this.projectPath) {
    _loadKeyConstants();
  }

  /// Loads and caches KeyConstants from the project
  void _loadKeyConstants() {
    final pathInfo = KeyChecker.resolveProjectPath(projectPath);
    final resolvedPath = pathInfo['projectPath'] as String;
    final directories = <Directory>[];

    // Always try to scan lib/ and integration_test/ in the resolved project path
    final libDir = Directory(path.join(resolvedPath, 'lib'));
    final integrationDir =
        Directory(path.join(resolvedPath, 'integration_test'));

    if (libDir.existsSync()) {
      directories.add(libDir);
    }
    if (integrationDir.existsSync()) {
      directories.add(integrationDir);
    }

    // If we resolved to a different path, also scan the original path
    if (resolvedPath != projectPath) {
      final originalLibDir = Directory(path.join(projectPath, 'lib'));
      final originalIntegrationDir =
          Directory(path.join(projectPath, 'integration_test'));

      if (originalLibDir.existsSync()) {
        directories.add(originalLibDir);
      }
      if (originalIntegrationDir.existsSync()) {
        directories.add(originalIntegrationDir);
      }
    }

    for (final dir in directories) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path);

      for (final filePath in dartFiles) {
        final content = File(filePath).readAsStringSync();

        // Check for KeyConstants class definition
        if (content.contains('class KeyConstants')) {
          _keyConstantsFilePath = filePath;
          _parseKeyConstants(content);
          return; // Found KeyConstants, stop searching
        }
      }
    }
  }

  /// Parses KeyConstants file content and caches constants and methods
  void _parseKeyConstants(String content) {
    // Parse static const String fields: static const String name = 'value';
    final constantPattern = RegExp(
      r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)'",
      multiLine: true,
    );
    final constantMatches = constantPattern.allMatches(content);
    for (final match in constantMatches) {
      final constantName = match.group(1)!;
      final constantValue = match.group(2)!;
      _constantsCache[constantName] = constantValue;
    }

    // Also check for double quotes
    final constantPatternDouble = RegExp(
      r'static\s+const\s+String\s+(\w+)\s*=\s*"([^"]+)"',
      multiLine: true,
    );
    final constantMatchesDouble = constantPatternDouble.allMatches(content);
    for (final match in constantMatchesDouble) {
      final constantName = match.group(1)!;
      final constantValue = match.group(2)!;
      _constantsCache[constantName] = constantValue;
    }

    // Parse dynamic key methods: static Key methodName(...) => Key('base_key_...');
    final methodPattern = RegExp(
      r"static\s+Key\s+(\w+Key)\s*\([^)]*\)\s*=>\s*Key\s*\(\s*'([^'_]+)",
      multiLine: true,
    );
    final methodMatches = methodPattern.allMatches(content);
    for (final match in methodMatches) {
      final methodName = match.group(1)!;
      final baseKey = match.group(2)!;
      _dynamicMethodsCache[methodName] = baseKey;
    }

    // Also check for double quotes in methods
    final methodPatternDouble = RegExp(
      r'static\s+Key\s+(\w+Key)\s*\([^)]*\)\s*=>\s*Key\s*\(\s*"([^"_]+)',
      multiLine: true,
    );
    final methodMatchesDouble = methodPatternDouble.allMatches(content);
    for (final match in methodMatchesDouble) {
      final methodName = match.group(1)!;
      final baseKey = match.group(2)!;
      _dynamicMethodsCache[methodName] = baseKey;
    }
  }

  /// Resolves a KeyConstants constant name to its string value
  String? resolveConstant(String constantName) {
    return _constantsCache[constantName];
  }

  /// Resolves a KeyConstants dynamic method to its base key
  String? resolveDynamicKey(String methodName) {
    return _dynamicMethodsCache[methodName];
  }

  /// Returns true if KeyConstants class exists
  bool get hasKeyConstants => _keyConstantsFilePath != null;

  /// Returns the path to the KeyConstants file
  String? get keyConstantsFilePath => _keyConstantsFilePath;

  /// Returns all cached constants
  Map<String, String> get constants => Map.unmodifiable(_constantsCache);

  /// Returns all cached dynamic methods
  Map<String, String> get dynamicMethods =>
      Map.unmodifiable(_dynamicMethodsCache);
}

/// Status of required dependencies in pubspec.yaml
class DependencyStatus {
  /// Constructor
  const DependencyStatus({
    required this.hasIntegrationTest,
    required this.hasAppiumServer,
  });

  /// Whether integration_test dependency is present
  final bool hasIntegrationTest;

  /// Whether appium_flutter_server dependency is present
  final bool hasAppiumServer;

  /// Whether all required dependencies are present
  bool get hasAllDependencies => hasIntegrationTest && hasAppiumServer;
}

/// Result of key validation containing found and missing keys.
///
/// This class holds the results of validating Flutter automation keys in a project:
/// - [missingKeys]: Keys that are expected but not found in the code
/// - [extraKeys]: Keys found in code but not in the specification (when strict mode is enabled)
/// - [matchedKeys]: Keys found in code with their file locations
/// - [dependencyStatus]: Status of required test dependencies
/// - [hasIntegrationTests]: Whether integration test setup is valid
class KeyValidationResult {
  /// Keys that are expected but not found in the code
  final Set<String> missingKeys;

  /// Keys found in code but not in the specification (strict mode)
  final Set<String> extraKeys;

  /// Keys found in code with their file locations
  final Map<String, List<String>> matchedKeys;

  /// Status of required test dependencies
  final DependencyStatus dependencyStatus;

  /// Whether integration test setup is valid
  final bool hasIntegrationTests;

  /// Optional tracked keys
  final List<String>? trackedKeys;

  /// KeyConstants resolver information
  final Map<String, dynamic>? keyConstantsInfo;

  const KeyValidationResult({
    required this.missingKeys,
    required this.extraKeys,
    required this.matchedKeys,
    required this.dependencyStatus,
    required this.hasIntegrationTests,
    this.trackedKeys,
    this.keyConstantsInfo,
  });

  /// Whether required test dependencies are present (for backward compatibility)
  bool get hasDependencies => dependencyStatus.hasAllDependencies;

  /// Whether the validation passed all checks
  bool get isValid =>
      missingKeys.isEmpty && hasDependencies && hasIntegrationTests;
}

/// ANSI color pens for console output
class ConsoleColors {
  /// Red color for errors
  static final error = AnsiPen()..red(bold: true);

  /// Green color for success messages
  static final success = AnsiPen()..green();

  /// Yellow color for warnings
  static final warning = AnsiPen()..yellow();

  /// Cyan color for info messages
  static final info = AnsiPen()..cyan();

  /// Blue color for section headers
  static final blue = AnsiPen()..blue(bold: true);

  /// Reset color pen
  static final reset = AnsiPen();

  /// Creates a formatted section header with divider
  static String section(String text) => blue('$text\n${_divider()}');

  /// Creates a horizontal divider line
  static String _divider() => '─' * 44;
}

/// Key checker functionality for validating Flutter automation keys
class KeyChecker {
  /// Detects if a project has an example/ folder and determines the correct project path.
  ///
  /// For Flutter packages published to pub.dev, it's common to have an example/ folder
  /// containing a sample application. This method helps determine the correct path to scan.
  ///
  /// Returns a map with:
  /// - 'projectPath': The resolved project path to use for scanning
  /// - 'hasExample': Whether an example folder was detected
  /// - 'isInExample': Whether we're currently in an example folder
  static Map<String, dynamic> resolveProjectPath(String sourcePath) {
    final libDir = Directory(path.join(sourcePath, 'lib'));
    final exampleDir = Directory(path.join(sourcePath, 'example'));

    // Check if we're in an example folder by checking if parent directory has pubspec
    // and current directory name is 'example'
    final parentPubspec = File(path.join(sourcePath, '..', 'pubspec.yaml'));
    final currentDirName = path.basename(sourcePath);
    final isInExample =
        currentDirName == 'example' && parentPubspec.existsSync();

    if (isInExample) {
      // We're in an example folder, use current path
      return {
        'projectPath': sourcePath,
        'hasExample': false,
        'isInExample': true,
      };
    }

    // Check if we have a lib/ folder in current directory
    if (libDir.existsSync()) {
      // Standard Flutter project structure
      return {
        'projectPath': sourcePath,
        'hasExample': exampleDir.existsSync(),
        'isInExample': false,
      };
    }

    // No lib/ folder, check if we have an example/ folder
    if (exampleDir.existsSync()) {
      final exampleLibDir = Directory(path.join(exampleDir.path, 'lib'));
      if (exampleLibDir.existsSync()) {
        // Use example folder as project path
        return {
          'projectPath': exampleDir.path,
          'hasExample': true,
          'isInExample': false,
        };
      }
    }

    // Default to original path
    return {
      'projectPath': sourcePath,
      'hasExample': exampleDir.existsSync(),
      'isInExample': false,
    };
  }

  /// Gets the list of directories to scan for keys.
  ///
  /// This method determines which directories to scan based on the project structure.
  /// It supports both standard Flutter projects and packages with example/ folders.
  static List<Directory> _getDirectoriesToScan(String projectPath) {
    final directories = <Directory>[];

    // Always try to scan lib/ and integration_test/ in the resolved project path
    final libDir = Directory(path.join(projectPath, 'lib'));
    final integrationDir =
        Directory(path.join(projectPath, 'integration_test'));

    if (libDir.existsSync()) {
      directories.add(libDir);
    }
    if (integrationDir.existsSync()) {
      directories.add(integrationDir);
    }

    // Check if we have an example folder and scan for lib directories within it
    final exampleDir = Directory(path.join(projectPath, 'example'));
    if (exampleDir.existsSync()) {
      // Look for lib directories recursively within the example folder
      final exampleContents = exampleDir.listSync(recursive: false);
      for (final item in exampleContents) {
        if (item is Directory) {
          final potentialLibDir = Directory(path.join(item.path, 'lib'));
          final potentialIntegrationDir =
              Directory(path.join(item.path, 'integration_test'));

          if (potentialLibDir.existsSync()) {
            directories.add(potentialLibDir);
          }
          if (potentialIntegrationDir.existsSync()) {
            directories.add(potentialIntegrationDir);
          }
        }
      }

      // Also check for direct example/lib and example/integration_test
      final exampleLibDir = Directory(path.join(projectPath, 'example', 'lib'));
      final exampleIntegrationDir =
          Directory(path.join(projectPath, 'example', 'integration_test'));

      if (exampleLibDir.existsSync()) {
        directories.add(exampleLibDir);
      }
      if (exampleIntegrationDir.existsSync()) {
        directories.add(exampleIntegrationDir);
      }
    }

    return directories;
  }

  /// Filters keys based on include_only and exclude patterns.
  ///
  /// Parameters:
  /// - [keys]: Set of keys to filter
  /// - [includeOnly]: List of patterns - only keys matching at least one pattern will be included
  /// - [exclude]: List of patterns - keys matching any pattern will be excluded
  ///
  /// Patterns can be substrings or regex patterns.
  /// Include filtering is applied first, then exclude filtering.
  static Set<String> filterKeys(
    Set<String> keys, {
    List<String>? includeOnly,
    List<String>? exclude,
  }) {
    var filteredKeys = Set<String>.from(keys);

    // Apply include_only filter first
    if (includeOnly != null && includeOnly.isNotEmpty) {
      filteredKeys = filteredKeys.where((key) {
        return includeOnly.any((pattern) => _matchesPattern(key, pattern));
      }).toSet();
    }

    // Apply exclude filter
    if (exclude != null && exclude.isNotEmpty) {
      filteredKeys = filteredKeys.where((key) {
        return !exclude.any((pattern) => _matchesPattern(key, pattern));
      }).toSet();
    }

    return filteredKeys;
  }

  /// Filters a map of keys with their file locations based on include_only and exclude patterns.
  ///
  /// Parameters:
  /// - [keysMap]: Map of key names to lists of file paths where they are used
  /// - [includeOnly]: List of patterns - only keys matching at least one pattern will be included
  /// - [exclude]: List of patterns - keys matching any pattern will be excluded
  ///
  /// Returns a filtered map containing only keys that pass the filtering criteria.
  static Map<String, List<String>> filterKeysMap(
    Map<String, List<String>> keysMap, {
    List<String>? includeOnly,
    List<String>? exclude,
  }) {
    final filteredKeys = filterKeys(
      keysMap.keys.toSet(),
      includeOnly: includeOnly,
      exclude: exclude,
    );

    return Map.fromEntries(
      keysMap.entries.where((entry) => filteredKeys.contains(entry.key)),
    );
  }

  /// Checks if a key matches a pattern (substring or regex).
  static bool _matchesPattern(String key, String pattern) {
    try {
      // Try to use as regex first
      final regex = RegExp(pattern);
      return regex.hasMatch(key);
    } catch (e) {
      // If regex fails, use as substring
      return key.contains(pattern);
    }
  }

  /// Find keys in Flutter source code using regex patterns.
  ///
  /// Searches for:
  /// - ValueKey declarations
  /// - Key declarations
  /// - find.byValueKey finders
  /// - find.bySemanticsLabel finders
  /// - find.byTooltip finders
  /// - KeyConstants patterns (resolved to actual string values)
  ///
  /// This method automatically detects and handles Flutter packages with example/ folders.
  ///
  /// Parameters:
  /// - [sourcePath]: Root path of Flutter project to scan
  /// - [includeOnly]: Optional list of patterns - only keys matching at least one pattern will be included
  /// - [exclude]: Optional list of patterns - keys matching any pattern will be excluded
  ///
  /// Returns a map of key names to lists of file paths where they are used.
  static Map<String, List<String>> findKeysInProject(
    String sourcePath, {
    List<String>? includeOnly,
    List<String>? exclude,
  }) {
    final result = <String, List<String>>{};

    // Initialize KeyConstants resolver
    final resolver = KeyConstantsResolver(sourcePath);

    // Resolve the correct project path and get directories to scan
    final pathInfo = resolveProjectPath(sourcePath);
    final projectPath = pathInfo['projectPath'] as String;
    final directories = _getDirectoriesToScan(projectPath);

    // If we resolved to a different path, also scan the original path if it has directories
    if (projectPath != sourcePath) {
      directories.addAll(_getDirectoriesToScan(sourcePath));
    }

    for (final dir in directories) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path);

      for (final filePath in dartFiles) {
        // Skip the KeyConstants file itself to avoid detecting key definitions as usage
        if (resolver.keyConstantsFilePath != null &&
            path.normalize(filePath) ==
                path.normalize(resolver.keyConstantsFilePath!)) {
          continue;
        }

        final content = File(filePath).readAsStringSync();

        // Find traditional ValueKey and Key declarations
        final keyMatches =
            RegExp("(Value)?Key\\(['\"](.*?)['\"]\\)").allMatches(content);
        for (final match in keyMatches) {
          final key = match.group(2)!;
          result.putIfAbsent(key, () => []).add(filePath);
        }

        // Find modern Key(KeyConstants.*) patterns and resolve them
        final constantKeyMatches =
            RegExp(r"(?:const\s+)?Key\(\s*KeyConstants\.(\w+)\s*\)")
                .allMatches(content);
        for (final match in constantKeyMatches) {
          final constantName = match.group(1)!;
          final resolvedValue = resolver.resolveConstant(constantName);
          if (resolvedValue != null) {
            result.putIfAbsent(resolvedValue, () => []).add(filePath);
          } else {
            // If resolution fails, use the constant name as fallback
            result.putIfAbsent(constantName, () => []).add(filePath);
          }
        }

        // Find dynamic KeyConstants.*Key(*) method calls and resolve them
        final dynamicKeyMatches =
            RegExp(r"KeyConstants\.(\w*Key)\s*\([^)]*\)").allMatches(content);
        for (final match in dynamicKeyMatches) {
          final methodName = match.group(1)!;
          final resolvedBaseKey = resolver.resolveDynamicKey(methodName);
          if (resolvedBaseKey != null) {
            result.putIfAbsent(resolvedBaseKey, () => []).add(filePath);
          } else {
            // If resolution fails, use the method name as fallback
            result.putIfAbsent(methodName, () => []).add(filePath);
          }
        }

        // Find ValueKey(KeyConstants.*) patterns and resolve them
        final constantValueKeyMatches =
            RegExp(r"(?:const\s+)?ValueKey\(\s*KeyConstants\.(\w+)\s*\)")
                .allMatches(content);
        for (final match in constantValueKeyMatches) {
          final constantName = match.group(1)!;
          final resolvedValue = resolver.resolveConstant(constantName);
          if (resolvedValue != null) {
            result.putIfAbsent(resolvedValue, () => []).add(filePath);
          } else {
            // If resolution fails, use the constant name as fallback
            result.putIfAbsent(constantName, () => []).add(filePath);
          }
        }

        // Find finder methods (byValueKey, bySemanticsLabel, byTooltip)
        final finderMatches = RegExp(
                "find\\.by(ValueKey|SemanticsLabel|Tooltip)\\(['\"](.*?)['\"]\\)")
            .allMatches(content);
        for (final match in finderMatches) {
          final key = match.group(2)!;
          result.putIfAbsent(key, () => []).add(filePath);
        }

        // Find finder methods with KeyConstants and resolve them
        final constantFinderMatches =
            RegExp(r"find\.byValueKey\(\s*KeyConstants\.(\w+)\s*\)")
                .allMatches(content);
        for (final match in constantFinderMatches) {
          final constantName = match.group(1)!;
          final resolvedValue = resolver.resolveConstant(constantName);
          if (resolvedValue != null) {
            result.putIfAbsent(resolvedValue, () => []).add(filePath);
          } else {
            // If resolution fails, use the constant name as fallback
            result.putIfAbsent(constantName, () => []).add(filePath);
          }
        }

        // Find dynamic finder methods with KeyConstants and resolve them
        final dynamicFinderMatches = RegExp(
                r"find\.byValueKey\(\s*KeyConstants\.(\w*Key)\s*\([^)]*\)\s*\)")
            .allMatches(content);
        for (final match in dynamicFinderMatches) {
          final methodName = match.group(1)!;
          final resolvedBaseKey = resolver.resolveDynamicKey(methodName);
          if (resolvedBaseKey != null) {
            result.putIfAbsent(resolvedBaseKey, () => []).add(filePath);
          } else {
            // If resolution fails, use the method name as fallback
            result.putIfAbsent(methodName, () => []).add(filePath);
          }
        }
      }
    }

    // Apply filtering if patterns are provided
    return filterKeysMap(
      result,
      includeOnly: includeOnly,
      exclude: exclude,
    );
  }

  /// Loads expected keys from a YAML file.
  ///
  /// The YAML file should have a 'keys' list containing strings.
  /// Example format:
  /// ```yaml
  /// keys:
  ///   - login_button
  ///   - password_field
  ///   - submit_button
  /// ```
  ///
  /// Throws [FileSystemException] if file not found.
  /// Throws [FormatException] if YAML format is invalid.
  static Set<String> loadExpectedKeys(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Keys file not found', filePath);
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;
    final keys = yaml['keys'] as YamlList?;

    if (keys == null) {
      throw FormatException('Invalid YAML format: missing "keys" list');
    }

    return keys.map((k) => k.toString()).toSet();
  }

  /// Checks if required dependencies are present in pubspec.yaml.
  ///
  /// Required dependencies:
  /// - integration_test (can be in dependencies or dev_dependencies)
  /// - appium_flutter_server (in dev_dependencies)
  ///
  /// This method automatically handles Flutter packages with example/ folders.
  static DependencyStatus checkDependencies(String projectPath) {
    final pathInfo = resolveProjectPath(projectPath);
    final resolvedPath = pathInfo['projectPath'] as String;
    final hasExample = pathInfo['hasExample'] as bool;

    // Check dependencies in the resolved project path
    final pubspecFile = File(path.join(resolvedPath, 'pubspec.yaml'));

    DependencyStatus mainStatus = DependencyStatus(
      hasIntegrationTest: false,
      hasAppiumServer: false,
    );

    if (pubspecFile.existsSync()) {
      final content = loadYaml(pubspecFile.readAsStringSync()) as YamlMap?;
      if (content != null) {
        final deps = content['dependencies'] as YamlMap?;
        final devDeps = content['dev_dependencies'] as YamlMap?;

        bool hasIntegrationTest = false;
        bool hasAppiumServer = false;

        if (deps != null) {
          hasIntegrationTest = deps.containsKey('integration_test');
        }
        if (devDeps != null) {
          hasIntegrationTest |= devDeps.containsKey('integration_test');
          hasAppiumServer = devDeps.containsKey('appium_flutter_server');
        }

        mainStatus = DependencyStatus(
          hasIntegrationTest: hasIntegrationTest,
          hasAppiumServer: hasAppiumServer,
        );
      }
    }

    // If we have an example folder and we're not in it, also check example dependencies
    if (hasExample && resolvedPath != path.join(projectPath, 'example')) {
      final examplePubspec =
          File(path.join(projectPath, 'example', 'pubspec.yaml'));
      if (examplePubspec.existsSync()) {
        final exampleContent =
            loadYaml(examplePubspec.readAsStringSync()) as YamlMap?;
        if (exampleContent != null) {
          final exampleDeps = exampleContent['dependencies'] as YamlMap?;
          final exampleDevDeps = exampleContent['dev_dependencies'] as YamlMap?;

          bool exampleHasIntegrationTest = false;
          bool exampleHasAppiumServer = false;

          if (exampleDeps != null) {
            exampleHasIntegrationTest =
                exampleDeps.containsKey('integration_test');
          }
          if (exampleDevDeps != null) {
            exampleHasIntegrationTest |=
                exampleDevDeps.containsKey('integration_test');
            exampleHasAppiumServer =
                exampleDevDeps.containsKey('appium_flutter_server');
          }

          // Combine results (if either main or example has dependencies, consider it available)
          return DependencyStatus(
            hasIntegrationTest:
                mainStatus.hasIntegrationTest || exampleHasIntegrationTest,
            hasAppiumServer:
                mainStatus.hasAppiumServer || exampleHasAppiumServer,
          );
        }
      }
    }

    return mainStatus;
  }

  /// Checks if integration test files are properly set up.
  ///
  /// Verifies:
  /// - integration_test directory exists
  /// - At least one .dart test file exists
  /// - Appium Flutter Driver is initialized
  ///
  /// This method automatically handles Flutter packages with example/ folders.
  static bool checkIntegrationTests(String projectPath) {
    final pathInfo = resolveProjectPath(projectPath);
    final resolvedPath = pathInfo['projectPath'] as String;
    final hasExample = pathInfo['hasExample'] as bool;

    // Check integration tests in the resolved project path
    bool hasMainIntegrationTests = _checkIntegrationTestsInPath(resolvedPath);

    // If we have an example folder and we're not in it, also check example integration tests
    if (hasExample && resolvedPath != path.join(projectPath, 'example')) {
      bool hasExampleIntegrationTests =
          _checkIntegrationTestsInPath(path.join(projectPath, 'example'));
      return hasMainIntegrationTests || hasExampleIntegrationTests;
    }

    return hasMainIntegrationTests;
  }

  /// Validates KeyConstants class existence and structure.
  ///
  /// Checks for:
  /// - KeyConstants class definition
  /// - Static const String fields
  /// - Static Key method definitions
  /// - Proper imports
  ///
  /// Returns a map with validation results:
  /// - 'hasKeyConstants': Whether KeyConstants class exists
  /// - 'constantsFound': List of static const fields found
  /// - 'methodsFound': List of static Key methods found
  /// - 'filePath': Path to the KeyConstants file
  static Map<String, dynamic> validateKeyConstants(String projectPath) {
    final result = <String, dynamic>{
      'hasKeyConstants': false,
      'constantsFound': <String>[],
      'methodsFound': <String>[],
      'filePath': null,
    };

    final pathInfo = resolveProjectPath(projectPath);
    final resolvedPath = pathInfo['projectPath'] as String;
    final directories = _getDirectoriesToScan(resolvedPath);

    // If we resolved to a different path, also scan the original path
    if (resolvedPath != projectPath) {
      directories.addAll(_getDirectoriesToScan(projectPath));
    }

    for (final dir in directories) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path);

      for (final filePath in dartFiles) {
        final content = File(filePath).readAsStringSync();

        // Check for KeyConstants class definition
        if (content.contains('class KeyConstants')) {
          result['hasKeyConstants'] = true;
          result['filePath'] = filePath;

          // Find static const String fields
          final constantMatches = RegExp(r'static\s+const\s+String\s+(\w+)\s*=')
              .allMatches(content);
          for (final match in constantMatches) {
            final constantName = match.group(1)!;
            (result['constantsFound'] as List<String>).add(constantName);
          }

          // Find static Key methods
          final methodMatches = RegExp(r'static\s+Key\s+(\w+Key)\s*\([^)]*\)')
              .allMatches(content);
          for (final match in methodMatches) {
            final methodName = match.group(1)!;
            (result['methodsFound'] as List<String>).add(methodName);
          }

          break; // Found KeyConstants, no need to continue
        }
      }

      if (result['hasKeyConstants'] as bool) break;
    }

    return result;
  }

  /// Generates a comprehensive key usage report.
  ///
  /// Analyzes the project for:
  /// - Traditional key patterns (ValueKey, Key with strings)
  /// - Modern KeyConstants patterns (resolved to actual values)
  /// - Dynamic key generation methods
  /// - Missing KeyConstants class
  ///
  /// Returns a detailed report map with statistics and recommendations.
  static Map<String, dynamic> generateKeyReport(String projectPath) {
    final foundKeys = findKeysInProject(projectPath);
    final keyConstantsInfo = validateKeyConstants(projectPath);
    final resolver = KeyConstantsResolver(projectPath);

    final report = <String, dynamic>{
      'totalKeysFound': foundKeys.length,
      'traditionalKeys': <String>[],
      'constantKeys': <String>[],
      'dynamicKeys': <String>[],
      'resolvedKeys':
          <String, String>{}, // Maps resolved keys to their constants
      'keyConstantsValidation': keyConstantsInfo,
      'keyConstantsResolver': <String, dynamic>{
        'hasKeyConstants': resolver.hasKeyConstants,
        'keyConstantsFilePath': resolver.keyConstantsFilePath,
        'constantsCount': resolver.constants.length,
        'dynamicMethodsCount': resolver.dynamicMethods.length,
        'constants': resolver.constants,
        'dynamicMethods': resolver.dynamicMethods,
      },
      'recommendations': <String>[],
    };

    // Categorize found keys by analyzing their usage patterns
    final pathInfo = resolveProjectPath(projectPath);
    final resolvedPath = pathInfo['projectPath'] as String;
    final directories = _getDirectoriesToScan(resolvedPath);

    if (resolvedPath != projectPath) {
      directories.addAll(_getDirectoriesToScan(projectPath));
    }

    final traditionalKeys = <String>[];
    final constantKeys = <String>[];
    final dynamicKeys = <String>[];
    final resolvedKeysMap = <String, String>{};

    for (final dir in directories) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path);

      for (final filePath in dartFiles) {
        // Skip the KeyConstants file itself to avoid detecting key definitions as usage
        if (resolver.keyConstantsFilePath != null &&
            path.normalize(filePath) ==
                path.normalize(resolver.keyConstantsFilePath!)) {
          continue;
        }

        final content = File(filePath).readAsStringSync();

        // Check for traditional patterns
        final traditionalMatches =
            RegExp("(Value)?Key\\(['\"](.*?)['\"]\\)").allMatches(content);
        for (final match in traditionalMatches) {
          final key = match.group(2)!;
          if (!traditionalKeys.contains(key)) traditionalKeys.add(key);
        }

        // Check for KeyConstants patterns and resolve them
        final constantMatches =
            RegExp(r"(?:const\s+)?(?:Value)?Key\(\s*KeyConstants\.(\w+)\s*\)")
                .allMatches(content);
        for (final match in constantMatches) {
          final constantName = match.group(1)!;
          final resolvedValue = resolver.resolveConstant(constantName);
          if (resolvedValue != null) {
            if (!constantKeys.contains(resolvedValue)) {
              constantKeys.add(resolvedValue);
              resolvedKeysMap[resolvedValue] = constantName;
            }
          } else {
            // If resolution fails, treat as constant name
            if (!constantKeys.contains(constantName)) {
              constantKeys.add(constantName);
            }
          }
        }

        // Check for dynamic KeyConstants methods and resolve them
        final dynamicMatches =
            RegExp(r"KeyConstants\.(\w*Key)\s*\([^)]*\)").allMatches(content);
        for (final match in dynamicMatches) {
          final methodName = match.group(1)!;
          final resolvedBaseKey = resolver.resolveDynamicKey(methodName);
          if (resolvedBaseKey != null) {
            if (!dynamicKeys.contains(resolvedBaseKey)) {
              dynamicKeys.add(resolvedBaseKey);
              resolvedKeysMap[resolvedBaseKey] = methodName;
            }
          } else {
            // If resolution fails, treat as method name
            if (!dynamicKeys.contains(methodName)) {
              dynamicKeys.add(methodName);
            }
          }
        }
      }
    }

    report['traditionalKeys'] = traditionalKeys;
    report['constantKeys'] = constantKeys;
    report['dynamicKeys'] = dynamicKeys;
    report['resolvedKeys'] = resolvedKeysMap;

    // Generate recommendations
    final recommendations = <String>[];

    if (!resolver.hasKeyConstants) {
      recommendations.add(
          'Consider creating a KeyConstants class to centralize key management');
    }

    if (traditionalKeys.isNotEmpty) {
      recommendations.add(
          'Found ${traditionalKeys.length} traditional string-based keys that could be migrated to KeyConstants');
    }

    if (constantKeys.isEmpty &&
        dynamicKeys.isEmpty &&
        resolver.hasKeyConstants) {
      recommendations.add(
          'KeyConstants class exists but is not being used. Consider migrating existing keys');
    }

    if (resolver.hasKeyConstants && resolver.constants.isNotEmpty) {
      final unusedConstants = resolver.constants.keys
          .toSet()
          .difference(resolvedKeysMap.values.toSet());
      if (unusedConstants.isNotEmpty) {
        recommendations.add(
            'Found ${unusedConstants.length} unused KeyConstants: ${unusedConstants.join(', ')}');
      }
    }

    report['recommendations'] = recommendations;
    return report;
  }

  /// Helper method to check integration tests in a specific path.
  static bool _checkIntegrationTestsInPath(String projectPath) {
    final integrationDir =
        Directory(path.join(projectPath, 'integration_test'));
    if (!integrationDir.existsSync()) return false;

    final files = integrationDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    if (files.isEmpty) return false;

    // Check for Appium Flutter Driver initialization
    bool hasAppiumInit = false;
    for (final file in files) {
      final content = file.readAsStringSync();
      if (content.contains(
              'import \'package:appium_flutter_server/appium_flutter_server.dart\'') &&
          content.contains('initializeTest(')) {
        hasAppiumInit = true;
        break;
      }
    }

    return hasAppiumInit;
  }

  /// Main validation function that checks keys in Flutter source code.
  ///
  /// Parameters:
  /// - [keysPath]: Path to YAML file containing expected keys
  /// - [sourcePath]: Root path of Flutter project to scan
  /// - [strict]: Whether to fail if integration_test setup is incomplete
  /// - [includeOnly]: Optional list of patterns - only keys matching at least one pattern will be included
  /// - [exclude]: Optional list of patterns - keys matching any pattern will be excluded
  /// - [trackedKeys]: Optional list of specific keys to track - when provided, only these keys are validated
  ///
  /// This method automatically detects and handles Flutter packages with example/ folders.
  ///
  /// Returns a [KeyValidationResult] containing validation results.
  static KeyValidationResult validateKeys({
    required String keysPath,
    String sourcePath = '.',
    bool strict = false,
    List<String>? includeOnly,
    List<String>? exclude,
    List<String>? trackedKeys,
  }) {
    // Load expected keys
    final expectedKeys = loadExpectedKeys(keysPath);

    // Initialize KeyConstants resolver
    final resolver = KeyConstantsResolver(sourcePath);

    // Apply tracked keys filtering if specified
    final keysToValidate = trackedKeys != null && trackedKeys.isNotEmpty
        ? expectedKeys.intersection(trackedKeys.toSet())
        : expectedKeys;

    // Find keys in project with filtering applied (automatically handles example/ folders)
    final foundKeys = findKeysInProject(
      sourcePath,
      includeOnly: includeOnly,
      exclude: exclude,
    );

    // Apply filtering to keys to validate for comparison
    final filteredKeysToValidate = filterKeys(
      keysToValidate,
      includeOnly: includeOnly,
      exclude: exclude,
    );

    // Filter found keys to only include tracked keys if specified
    final filteredFoundKeys = trackedKeys != null && trackedKeys.isNotEmpty
        ? filterKeysMap(foundKeys, includeOnly: trackedKeys)
        : foundKeys;

    // Calculate missing and extra keys based on tracked keys if specified
    final missingKeys =
        filteredKeysToValidate.difference(filteredFoundKeys.keys.toSet());
    final extraKeys = trackedKeys != null && trackedKeys.isNotEmpty
        ? foundKeys.keys.toSet().difference(trackedKeys.toSet())
        : foundKeys.keys.toSet().difference(filteredKeysToValidate);

    // Check dependencies and integration tests (automatically handles example/ folders)
    final hasDeps = checkDependencies(sourcePath);
    final hasTests = checkIntegrationTests(sourcePath);

    // Prepare KeyConstants resolver information
    final keyConstantsInfo = <String, dynamic>{
      'hasKeyConstants': resolver.hasKeyConstants,
      'keyConstantsFilePath': resolver.keyConstantsFilePath,
      'constantsCount': resolver.constants.length,
      'dynamicMethodsCount': resolver.dynamicMethods.length,
      'constants': resolver.constants,
      'dynamicMethods': resolver.dynamicMethods,
    };

    return KeyValidationResult(
      missingKeys: missingKeys,
      extraKeys: extraKeys,
      matchedKeys: filteredFoundKeys,
      dependencyStatus: hasDeps,
      hasIntegrationTests: hasTests,
      trackedKeys: trackedKeys,
      keyConstantsInfo: keyConstantsInfo,
    );
  }

  /// Generates a YAML string with keys found in the project
  ///
  /// Parameters:
  /// - [sourcePath]: Root path of Flutter project to scan
  /// - [includeOnly]: Optional list of patterns - only keys matching at least one pattern will be included
  /// - [exclude]: Optional list of patterns - keys matching any pattern will be excluded
  /// - [trackedKeys]: Optional list of specific keys to track - when provided, only these keys are included
  ///
  /// Returns a formatted YAML string ready for saving to a file.
  static String generateKeysYaml({
    String sourcePath = '.',
    List<String>? includeOnly,
    List<String>? exclude,
    List<String>? trackedKeys,
  }) {
    // Find all keys in project
    final foundKeys = findKeysInProject(
      sourcePath,
      includeOnly: includeOnly,
      exclude: exclude,
    );

    // Apply tracked keys filtering if specified
    final keysToGenerate = trackedKeys != null && trackedKeys.isNotEmpty
        ? foundKeys.keys.where((key) => trackedKeys.contains(key)).toSet()
        : foundKeys.keys.toSet();

    final sortedKeys = keysToGenerate.toList()..sort();

    final buffer = StringBuffer();

    // Add header comment
    buffer.writeln('# Generated expected keys for flutter_keycheck');
    buffer.writeln(
        '# Run: flutter_keycheck --generate-keys > keys/expected_keys.yaml');

    // Add filter information
    if (includeOnly != null && includeOnly.isNotEmpty) {
      buffer.writeln(
          '# Generated with include_only filters: ${includeOnly.join(', ')}');
    }
    if (exclude != null && exclude.isNotEmpty) {
      buffer.writeln('# Generated with exclude filters: ${exclude.join(', ')}');
    }
    if (trackedKeys != null && trackedKeys.isNotEmpty) {
      buffer
          .writeln('# Generated with tracked_keys: ${trackedKeys.join(', ')}');
    }
    buffer.writeln();

    // Add keys section
    buffer.writeln('keys:');
    for (final key in sortedKeys) {
      buffer.writeln('  - $key');
    }

    return buffer.toString();
  }
}
