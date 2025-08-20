import 'package:flutter/material.dart';

class TestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('test_scaffold'),
      appBar: AppBar(
        key: Key('test_appbar'),
        title: Text('Test Screen'),
      ),
      body: Column(
        children: [
          TextField(
            key: Key('test_input'),
          ),
          ElevatedButton(
            key: Key('test_button'),
            onPressed: () {},
            child: Text('Test'),
          ),
        ],
      ),
    );
  }
}
