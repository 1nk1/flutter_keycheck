import 'dart:io';
import '../scanner/ast_scanner_v3.dart';
import '../models/scan_result.dart';
import 'base_command_v3.dart';

class FixCommand extends BaseCommandV3 {
  @override
  final String name = 'fix';

  @override
  final String description = 'Fix duplicate keys in Flutter project';

  FixCommand() {
    argParser
      ..addOption('key',
          help: 'Key name to fix (including dynamic keys like "(dynamic key)")',
          mandatory: true)
      ..addOption('strategy',
          help: 'Fix strategy',
          allowed: ['keepFirst', 'keepLast', 'renameSuffix', 'interactive'],
          defaultsTo: 'interactive');
  }

  @override
  Future<int> run() async {
    try {
      final keyName = argResults!['key'] as String;
      final strategy = argResults!['strategy'] as String;

      print('🔧 Fixing duplicate key: "$keyName"');
      print('📋 Strategy: $strategy');

      // Find project root
      final projectRoot = argResults!['project-root'] as String? ??
          Directory.current.path;

      // Load configuration
      final config = await loadConfig();

      // Scan for keys
      final scanner = AstScannerV3(
        projectPath: projectRoot,
        config: config,
      );
      final scanResult = await scanner.scan();

      // Find duplicates for the specified key
      final duplicates = <String, List<KeyLocation>>{};
      for (final entry in scanResult.keyUsages.entries) {
        final keyData = entry.value;
        if (keyData.locations.length > 1) {
          // Handle dynamic keys
          final displayKey = entry.key.isEmpty ? '(dynamic key)' : entry.key;
          if (displayKey == keyName || entry.key == keyName) {
            duplicates[entry.key] = keyData.locations;
          }
        }
      }

      if (duplicates.isEmpty) {
        print('❌ No duplicates found for key: "$keyName"');
        return 1;
      }

      // Apply fix based on strategy
      for (final entry in duplicates.entries) {
        final locations = entry.value;
        print('\n📍 Found ${locations.length} occurrences:');
        for (var i = 0; i < locations.length; i++) {
          final loc = locations[i];
          print('  ${i + 1}. ${loc.file} (Line ${loc.line})');
        }

        switch (strategy) {
          case 'keepFirst':
            await _keepFirst(locations);
            break;
          case 'keepLast':
            await _keepLast(locations);
            break;
          case 'renameSuffix':
            await _renameSuffix(entry.key, locations);
            break;
          case 'interactive':
            await _interactiveFix(entry.key, locations);
            break;
        }
      }

      print('\n✅ Fix applied successfully!');
      print('🔍 Run "flutter_keycheck scan" to verify the fix.');

      return 0;
    } catch (e, stack) {
      stderr.writeln('❌ Error fixing keys: $e');
      stderr.writeln(stack);
      return 1;
    }
  }

  Future<void> _keepFirst(List<KeyLocation> locations) async {
    print('\n✅ Keeping first occurrence, removing others...');

    // Skip first, comment out others
    for (var i = 1; i < locations.length; i++) {
      final loc = locations[i];
      await _commentOutKey(loc);
    }
  }

  Future<void> _keepLast(List<KeyLocation> locations) async {
    print('\n✅ Keeping last occurrence, removing others...');

    // Comment out all except last
    for (var i = 0; i < locations.length - 1; i++) {
      final loc = locations[i];
      await _commentOutKey(loc);
    }
  }

  Future<void> _renameSuffix(String keyName, List<KeyLocation> locations) async {
    print('\n✅ Renaming with suffixes...');

    for (var i = 0; i < locations.length; i++) {
      if (i == 0) continue; // Keep first as-is

      final loc = locations[i];
      final suffix = '_$i';
      await _renameKey(loc, keyName, '$keyName$suffix');
    }
  }

  Future<void> _interactiveFix(String keyName, List<KeyLocation> locations) async {
    print('\n🔍 Interactive mode:');
    print('Choose what to do with each occurrence:');

    for (var i = 0; i < locations.length; i++) {
      final loc = locations[i];
      print('\n${i + 1}. ${loc.file} (Line ${loc.line})');
      print('   Context: ${loc.context}');
      print('   [K]eep, [R]emove, [S]kip, or [Q]uit? ');

      final input = stdin.readLineSync()?.toLowerCase() ?? 's';

      switch (input) {
        case 'k':
          print('   ✅ Keeping this occurrence');
          break;
        case 'r':
          await _commentOutKey(loc);
          print('   ❌ Removed (commented out)');
          break;
        case 's':
          print('   ⏭️ Skipped');
          break;
        case 'q':
          print('   🛑 Quitting...');
          return;
      }
    }
  }

  Future<void> _commentOutKey(KeyLocation location) async {
    final file = File(location.file);
    if (!await file.exists()) {
      print('⚠️ File not found: ${location.file}');
      return;
    }

    final lines = await file.readAsLines();
    if (location.line > 0 && location.line <= lines.length) {
      final lineIndex = location.line - 1;
      final line = lines[lineIndex];

      // Comment out the line containing the key
      if (!line.trim().startsWith('//')) {
        lines[lineIndex] = '// REMOVED BY FLUTTER_KEYCHECK: $line';
        await file.writeAsString(lines.join('\n'));
      }
    }
  }

  Future<void> _renameKey(KeyLocation location, String oldKey, String newKey) async {
    final file = File(location.file);
    if (!await file.exists()) {
      print('⚠️ File not found: ${location.file}');
      return;
    }

    final content = await file.readAsString();
    final pattern = 'Key("$oldKey")';
    final replacement = 'Key("$newKey")';

    // Find and replace in the specific line range
    final lines = content.split('\n');
    if (location.line > 0 && location.line <= lines.length) {
      final lineIndex = location.line - 1;
      lines[lineIndex] = lines[lineIndex].replaceAll(pattern, replacement);
      await file.writeAsString(lines.join('\n'));
    }
  }
}
