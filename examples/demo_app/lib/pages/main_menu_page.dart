import 'package:flutter/material.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const Key('main_menu_app_bar'),
        title: const Text('Main Menu'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              key: const Key('register_button'),
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Register'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('home_button'),
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Text('Home'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('profile_button'),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: const Text('Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
