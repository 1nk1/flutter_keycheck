import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const ValueKey('app_root'),
      title: 'Golden Workspace',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('home_scaffold'),
      appBar: AppBar(
        key: const ValueKey('home_appbar'),
        title: const Text('Golden Workspace'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test Application',
              key: ValueKey('home_title'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const ValueKey('login_button'), // Critical key
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              key: const ValueKey('settings_button'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('login_scaffold'),
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('email_field'), // Critical key
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('password_field'), // Critical key
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const ValueKey('submit_button'), // Critical key
              onPressed: _handleLogin,
              child: const Text('Submit'),
            ),
            TextButton(
              key: const ValueKey('forgot_password_link'),
              onPressed: () {},
              child: const Text('Forgot Password?'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() {
    // Login logic
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('settings_scaffold'),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            key: const ValueKey('dark_mode_switch'),
            title: const Text('Dark Mode'),
            value: false,
            onChanged: (value) {},
          ),
          ListTile(
            key: const ValueKey('profile_tile'),
            title: const Text('Profile'),
            onTap: () {},
          ),
          ListTile(
            key: const ValueKey('logout_tile'),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}