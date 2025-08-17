import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _items = [
    {'title': 'Dashboard', 'icon': Icons.dashboard, 'count': 5},
    {'title': 'Messages', 'icon': Icons.message, 'count': 12},
    {'title': 'Notifications', 'icon': Icons.notifications, 'count': 3},
    {'title': 'Settings', 'icon': Icons.settings, 'count': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const Key('app_bar_home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Home'),
        actions: [
          IconButton(
            key: const Key('btn_home_search'),
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _SearchDelegate(),
              );
            },
          ),
          IconButton(
            key: const Key('btn_home_notifications'),
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('3 new notifications')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            key: Key('card_home_item_$index'),
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Icon(item['icon'] as IconData),
              title: Text(item['title'] as String),
              trailing: item['count'] > 0
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: Text(
                        '${item['count']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected: ${item['title']}'),
                  ),
                );
              },
              selected: _selectedIndex == index,
              selectedTileColor:
                  Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('fab_home_add'),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Item'),
              content: TextField(
                key: const Key('input_add_item'),
                decoration: const InputDecoration(
                  hintText: 'Enter item name',
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('btn_dialog_cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  key: const Key('btn_dialog_add'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item added!')),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/profile');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/');
          }
        },
      ),
    );
  }
}

class _SearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        key: const Key('btn_search_clear'),
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      key: const Key('btn_search_back'),
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text(
        'Search results for: $query',
        key: const Key('text_search_results'),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          key: const Key('search_suggestion_1'),
          title: const Text('Suggestion 1'),
          onTap: () {
            query = 'Suggestion 1';
          },
        ),
        ListTile(
          key: const Key('search_suggestion_2'),
          title: const Text('Suggestion 2'),
          onTap: () {
            query = 'Suggestion 2';
          },
        ),
      ],
    );
  }
}
