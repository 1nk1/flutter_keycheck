import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const Key('app_bar_profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Profile'),
        actions: [
          IconButton(
            key: const Key('btn_profile_edit'),
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              key: Key('avatar_profile'),
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            const Text(
              'John Doe',
              key: Key('text_profile_name'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'john.doe@example.com',
              key: Key('text_profile_email'),
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('tile_profile_account'),
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Account Settings'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account settings')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('tile_profile_privacy'),
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Privacy settings')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('tile_profile_notifications'),
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notifications'),
                    trailing: Switch(
                      key: const Key('switch_notifications'),
                      value: true,
                      onChanged: (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('tile_profile_help'),
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Help & Support'),
                          content:
                              const Text('Contact us at support@example.com'),
                          actions: [
                            TextButton(
                              key: const Key('btn_help_ok'),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('tile_profile_about'),
                    leading: const Icon(Icons.info),
                    title: const Text('About'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Demo App',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('btn_profile_logout'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        key: const Key('btn_logout_cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        key: const Key('btn_logout_confirm'),
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/',
                            (route) => false,
                          );
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
