import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(10, (i) => 'Item ${i + 1}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: ListView.builder(
        key: const Key('home_list'),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            key: ValueKey('list_item_$index'),
            title: Text(items[index]),
            trailing: IconButton(
              key: Key('action_button_$index'),
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Clicked ${items[index]}')),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('fab_add'),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add button pressed')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
