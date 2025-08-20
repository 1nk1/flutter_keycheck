// Test file with keys
class TestWidget {
  final key = const ValueKey('test_key');
  final button = ElevatedButton(
    key: const ValueKey('button_key'),
  );
}

// Mock classes
class ValueKey {
  const ValueKey(this.value);
  final String value;
}

class ElevatedButton {
  const ElevatedButton({this.key});
  final ValueKey? key;
}
