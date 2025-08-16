void main() {
  bool isSimilar(String k1, String k2) {
    final p1 = k1.split(RegExp(r'[._-]'));
    final p2 = k2.split(RegExp(r'[._-]'));
    final c = p1.toSet().intersection(p2.toSet());
    if (c.isEmpty) return false;
    final s = c.length / (p1.length + p2.length - c.length);
    return s > 0.6;
  }

  // Try different combinations
  final tests = [
    // Need 2 common out of 3 total unique parts for >60%
    ['user_login', 'user_login_form'], // 2/(2+3-2)=2/3=66.6%
    ['submit', 'submit_button'], // 1/(1+2-1)=1/2=50%
    ['login', 'login'], // 1/(1+1-1)=1/1=100%
    ['user.login', 'user.signin'], // 1/(2+2-1)=1/3=33.3%
    ['app_main', 'app_main_view'], // 2/(2+3-2)=2/3=66.6%
    ['home', 'home-page'], // 1/(1+2-1)=1/2=50%
  ];

  for (final test in tests) {
    final result = isSimilar(test[0], test[1]);
    print('${test[0]} vs ${test[1]}: $result ${result ? "✓" : "✗"}');
  }
}
