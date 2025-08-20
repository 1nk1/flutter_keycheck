import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const Key('app_bar_menu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Menu'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Flutter KeyCheck Demo App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              key: const Key('btn_goto_register'),
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Go to Register'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('btn_goto_home'),
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
              child: const Text('Go to Home'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('btn_goto_profile'),
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              child: const Text('Go to Profile'),
            ),
            const SizedBox(height: 40),
            TextButton(
              key: const Key('btn_menu_about'),
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Demo App',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                        'This is a demo app for testing flutter_keycheck'),
                  ],
                );
              },
              child: const Text('About'),
            ),
          ],
        ),
      ),
    );
  }
}
