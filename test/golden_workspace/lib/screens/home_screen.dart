import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_scaffold'),
      appBar: AppBar(
        key: const Key('home_appbar'),
        title: const Text('Home'),
      ),
      body: Column(
        children: [
          TextButton(
            key: const Key('login_button'),
            onPressed: () {},
            child: const Text('Login'),
          ),
          TextButton(
            key: const Key('profile_button'),
            onPressed: () {},
            child: const Text('Profile'),
          ),
          TextButton(
            key: const Key('settings_button'),
            onPressed: () {},
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}