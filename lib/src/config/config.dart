// Legacy config class for backward compatibility
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class Config {
  final List<String> include;
  final List<String> exclude;
  final List<String> trackedKeys;
  final Map<String, dynamic> flags;
  bool verbose;

  Config({
    this.include = const [],
    this.exclude = const [],
    this.trackedKeys = const [],
    this.flags = const {},
    this.verbose = false,
  });

  static Future<Config> load(String configPath) async {
    final file = File(configPath);
    if (!await file.exists()) {
      return Config();
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content);

    if (yaml == null || yaml is! Map) {
      return Config();
    }

    return Config(
      include: (yaml['include'] as List?)?.cast<String>() ?? [],
      exclude: (yaml['exclude'] as List?)?.cast<String>() ?? [],
      trackedKeys: (yaml['tracked_keys'] as List?)?.cast<String>() ?? [],
      flags: Map<String, dynamic>.from(yaml['flags'] ?? {}),
    );
  }

  static Config create() => Config();
}
