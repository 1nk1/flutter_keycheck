void main() {
  bool isSimilarKey(String key1, String key2) {
    final parts1 = key1.split(RegExp(r'[._-]'));
    final parts2 = key2.split(RegExp(r'[._-]'));
    print('parts1: $parts1');
    print('parts2: $parts2');

    final common = parts1.toSet().intersection(parts2.toSet());
    print('common: $common');
    if (common.isEmpty) return false;

    final similarity =
        common.length / (parts1.length + parts2.length - common.length);
    print('similarity: $similarity');

    return similarity > 0.6;
  }

  print('Test 1: login_submit_button vs login_submit_btn');
  print(isSimilarKey('login_submit_button', 'login_submit_btn'));

  print('\nTest 2: submit_button vs submit_btn');
  print(isSimilarKey('submit_button', 'submit_btn'));

  print('\nTest 3: user_login_button vs user_login_btn');
  print(isSimilarKey('user_login_button', 'user_login_btn'));
}
