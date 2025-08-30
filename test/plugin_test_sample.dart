// Test file to demonstrate plugin architecture

import 'package:flutter/material.dart';

// Custom annotation that plugin will detect
@AutomationTarget
class PluginTestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom key pattern that plugin detects
          Container(
            key: TestID('custom_container_1'),
            child: Text('Plugin Test'),
          ),
          
          // Another custom pattern
          AutomationKey('button_1'),
          
          // Custom widget pattern
          CustomTestWidget(),
          
          // Standard Flutter key (for comparison)
          ElevatedButton(
            key: Key('standard_button'),
            onPressed: () {},
            child: Text('Standard'),
          ),
        ],
      ),
    );
  }
}

// Custom widget that plugin detects
class CustomTestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: AutomationKey('custom_widget_key'),
      child: Text('Custom Widget'),
    );
  }
}

// Helper functions that plugin recognizes
Key TestID(String id) => Key('test_$id');
Key AutomationKey(String id) => Key('auto_$id');