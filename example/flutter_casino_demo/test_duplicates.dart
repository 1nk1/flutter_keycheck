import 'package:flutter/material.dart';

class TestDuplicates extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Duplicate key 1
        ElevatedButton(
          key: ValueKey('duplicate_button'),
          onPressed: () {},
          child: Text('Button 1'),
        ),
        // Duplicate key 1 - same key!
        ElevatedButton(
          key: ValueKey('duplicate_button'),
          onPressed: () {},
          child: Text('Button 2'),
        ),
        // Duplicate key 2
        TextField(
          key: Key('duplicate_field'),
          decoration: InputDecoration(labelText: 'Field 1'),
        ),
        // Duplicate key 2 - same key!
        TextField(
          key: Key('duplicate_field'),
          decoration: InputDecoration(labelText: 'Field 2'),
        ),
        // Duplicate key 2 - same key again!
        TextFormField(
          key: Key('duplicate_field'),
          decoration: InputDecoration(labelText: 'Field 3'),
        ),
        // Unique key
        Container(
          key: ValueKey('unique_container'),
          child: Text('Unique'),
        ),
      ],
    );
  }
}
