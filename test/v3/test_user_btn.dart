void main() {
  bool isSimilar(String k1, String k2) {
    final p1 = k1.split(RegExp(r'[._-]'));
    final p2 = k2.split(RegExp(r'[._-]'));
    print('p1: $p1');
    print('p2: $p2');
    final c = p1.toSet().intersection(p2.toSet());
    print('common: $c');
    if (c.isEmpty) return false;
    final s = c.length / (p1.length + p2.length - c.length);
    print('similarity: $s (${s > 0.6 ? "MATCH" : "NO MATCH"})');
    return s > 0.6;
  }

  print('user_button vs user_btn:');
  print(isSimilar('user_button', 'user_btn'));
}
