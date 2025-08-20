void main() {
  bool isSimilar(String k1, String k2) {
    final p1 = k1.split(RegExp(r'[._-]'));
    final p2 = k2.split(RegExp(r'[._-]'));
    print('p1: $p1');
    print('p2: $p2');
    final c = p1.toSet().intersection(p2.toSet());
    print('common: $c');
    if (c.isEmpty) return false;
    // Formula: common / (total_unique_parts)
    // total_unique = p1.length + p2.length - common.length
    final s = c.length / (p1.length + p2.length - c.length);
    print('similarity: $s (${s > 0.6 ? "MATCH" : "NO MATCH"})');
    print(
        'Formula: ${c.length} / (${p1.length} + ${p2.length} - ${c.length}) = ${c.length} / ${p1.length + p2.length - c.length}');
    return s > 0.6;
  }

  // Need >60% similarity
  // If we have 2 parts each with 1 common: 1/(2+2-1) = 1/3 = 33.3% NO
  // If we have 2 parts each with 2 common: 2/(2+2-2) = 2/2 = 100% YES
  // If we have 3 parts and 2 parts with 2 common: 2/(3+2-2) = 2/3 = 66.6% YES

  print('Test: login_button vs login_btn (should match):');
  print(isSimilar('login_button', 'login_btn'));
  print('');

  print('Test: login_form vs login_dialog (should match):');
  print(isSimilar('login_form', 'login_dialog'));
}
