// Re-export registry v3
export 'key_registry_v3.dart';
import 'dart:io';
import 'package:yaml/yaml.dart';

// Legacy compatibility aliases
typedef Registry = KeyRegistryV3;

// Simple Config class for base_command compatibility
class Config {
  List<String> packages = ['workspace'];
  List<String> tagsInclude = [];
  List<String> tagsExclude = [];
  bool strict = false;
  String registryType = 'standard';
  bool verbose = false;
  String reportFormat = 'human';

  static Future<Config> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return Config();
    }
    // Simple YAML loading - could be extended
    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map<dynamic, dynamic>?;
    final config = Config();
    // Parse yaml if needed
    return config;
  }

  static Registry create(Config config) {
    return KeyRegistryV3();
  }
}
