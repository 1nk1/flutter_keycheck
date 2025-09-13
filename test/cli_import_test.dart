import 'package:test/test.dart';
import 'package:flutter_keycheck/src/cli/cli_runner.dart';

void main() {
  group('CLI Import Tests', () {
    test('CLI runner can be instantiated without import errors', () {
      expect(() => CliRunner(), returnsNormally);
    });

    test('All commands can be registered without errors', () {
      final runner = CliRunner();
      expect(runner.commands.length, greaterThan(0));
    });

    test('Expected commands are registered', () {
      final runner = CliRunner();
      expect(runner.commands.containsKey('scan'), isTrue);
      expect(runner.commands.containsKey('validate'), isTrue);
      expect(runner.commands.containsKey('diff'), isTrue);
      expect(runner.commands.containsKey('report'), isTrue);
      expect(runner.commands.containsKey('sync'), isTrue);
      expect(runner.commands.containsKey('fix'), isTrue);
    });
  });
}
