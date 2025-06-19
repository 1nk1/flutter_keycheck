// Example Flutter widget code with ValueKey usage
// This is a sample showing how to add keys to Flutter widgets

/*
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email field with ValueKey
            TextField(
              key: const ValueKey('email_field'),
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            // Password field with ValueKey
            TextField(
              key: const ValueKey('password_field'),
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            // Login button with ValueKey
            ElevatedButton(
              key: const ValueKey('login_button'),
              onPressed: () {},
              child: const Text('Login'),
            ),

            // Signup button with ValueKey
            TextButton(
              key: const ValueKey('signup_button'),
              onPressed: () {},
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

// Integration test example
class LoginTest {
  void testLogin() async {
    // Find widgets by ValueKey
    await tester.tap(find.byValueKey('email_field'));
    await tester.enterText(find.byValueKey('email_field'), 'test@example.com');

    await tester.tap(find.byValueKey('password_field'));
    await tester.enterText(find.byValueKey('password_field'), 'password123');

    await tester.tap(find.byValueKey('login_button'));
  }
}
*/
