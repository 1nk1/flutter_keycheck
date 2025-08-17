// Mock Flutter code for testing - no actual Flutter imports needed
// This file simulates Flutter code structure for AST analysis testing

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static final Key appRootKey = const ValueKey('app_root');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static final Key scaffoldKey = const ValueKey('home_scaffold');

  void build() {
    // Mock widgets with keys
    final appBar = AppBar(
      key: const ValueKey('home_appbar'),
    );

    final loginButton = ElevatedButton(
      key: const ValueKey('login_button'), // Critical key
    );

    final settingsButton = ElevatedButton(
      key: const ValueKey('settings_button'),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  static final Key scaffoldKey = const ValueKey('login_scaffold');

  void build() {
    // Mock form fields with keys
    final emailField = TextField(
      key: const ValueKey('email_field'), // Critical key
    );

    final passwordField = TextField(
      key: const ValueKey('password_field'), // Critical key
    );

    final submitButton = ElevatedButton(
      key: const ValueKey('submit_button'), // Critical key
    );

    final forgotPasswordLink = TextButton(
      key: const ValueKey('forgot_password_link'),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  static final Key scaffoldKey = const ValueKey('settings_scaffold');

  void build() {
    final darkModeSwitch = SwitchListTile(
      key: const ValueKey('dark_mode_switch'),
    );

    final profileTile = ListTile(
      key: const ValueKey('profile_tile'),
    );

    final logoutTile = ListTile(
      key: const ValueKey('logout_tile'),
    );
  }
}

// Mock Flutter classes (no actual imports)
class Key {
  const Key(this.value);
  final String value;
}

class ValueKey extends Key {
  const ValueKey(String value) : super(value);
}

class Widget {
  const Widget({this.key});
  final Key? key;
}

class StatelessWidget extends Widget {
  const StatelessWidget({Key? key}) : super(key: key);
}

class StatefulWidget extends Widget {
  const StatefulWidget({Key? key}) : super(key: key);
}

class ElevatedButton extends Widget {
  const ElevatedButton({Key? key}) : super(key: key);
}

class TextField extends Widget {
  const TextField({Key? key}) : super(key: key);
}

class TextButton extends Widget {
  const TextButton({Key? key}) : super(key: key);
}

class AppBar extends Widget {
  const AppBar({Key? key}) : super(key: key);
}

class SwitchListTile extends Widget {
  const SwitchListTile({Key? key}) : super(key: key);
}

class ListTile extends Widget {
  const ListTile({Key? key}) : super(key: key);
}

void runApp(Widget app) {
  // Mock implementation
}
