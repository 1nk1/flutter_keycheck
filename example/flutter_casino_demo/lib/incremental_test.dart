// File added for incremental scan demonstration
import 'package:flutter/material.dart';

class IncrementalTestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          key: Key('incremental_key_1'),
          child: Text('Added for incremental scan'),
        ),
        ElevatedButton(key: Key("elevated_btn_${RANDOM}"), 
          key: Key('incremental_button'),
          onPressed: () {},
          child: Text('Test Button'),
        ),
      ],
    );
  }
}