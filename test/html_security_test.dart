import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  print('HTML Security Validation Test...');
  
  final reporter = PremiumDashboardReporter();
  
  final edgeCases = [
    // Very long lines
    'Key("${'very_long_key_name_' * 100}")',
    // Special characters
    'Key("key_with_特殊字符_and_émojis_🔑")',
    // Nested quotes and escapes
    'Key("key_with_\\"nested\\"_quotes_and_\\\'mixed\\\'_quotes")',
    // HTML injection attempts
    '<script>alert("xss")</script> Key("normal_key")',
    // Complex template strings
    'Key("template_\${widget.id}_\${index}_\${DateTime.now().millisecondsSinceEpoch}")',
    // Multiple keys in one line
    'return Row(children: [Widget(key: Key("first")), Widget(key: ValueKey("second")), Widget(key: GlobalKey())]);',
    // Comments with code-like content
    '// TODO: Key("commented_key") should be ignored in comments',
    // Regex patterns that could break old implementation
    'final pattern = RegExp("Key.*");',
  ];
  
  final keyUsages = <String, KeyUsage>{};
  edgeCases.asMap().forEach((index, context) {
    final keyUsage = KeyUsage(id: 'edge_case_$index');
    keyUsage.locations.add(KeyLocation(
      file: 'edge_cases.dart',
      line: index + 1,
      column: 1,
      detector: 'edge_test',
      context: context,
    ));
    keyUsages['edge_case_$index'] = keyUsage;
  });
  
  final result = ScanResult(
    metrics: ScanMetrics(),
    fileAnalyses: {},
    keyUsages: keyUsages,
    blindSpots: [],
    duration: Duration(milliseconds: 200),
  );
  
  final html = reporter.generateReport(result);
  
  print('Checking for specific contamination issues...');
  
  // Check each issue individually
  if (html.contains('<span class="syntax-keyword"><span')) {
    print('❌ Found nested spans in keywords');
  } else {
    print('✅ No nested keyword spans');
  }
  
  if (html.contains('</span></span></span>')) {
    print('❌ Found triple span closures');
  } else {
    print('✅ No triple span closures');
  }
  
  if (html.contains('<script>alert')) {
    print('❌ Found unescaped script tag');
  } else {
    print('✅ No unescaped script tags');
  }
  
  if (html.contains('undefined')) {
    print('❌ Found undefined values');
  } else {
    print('✅ No undefined values');
  }
  
  if (html.contains('null')) {
    print('❌ Found null values in output');
    // Find context of null values
    final lines = html.split('\n');
    final nullLines = lines.where((line) => line.contains('null')).toList();
    print('Null context lines:');
    for (final line in nullLines.take(5)) {
      print('  ${line.trim()}');
    }
  } else {
    print('✅ No null values in output');
  }
  
  // Check for proper HTML escaping
  if (html.contains('&lt;script&gt;')) {
    print('✅ HTML entities properly escaped');
  } else {
    print('❌ HTML entities not escaped');
  }
  
  // Look for any other issues
  if (html.contains('<span><span')) {
    print('❌ Found generic nested spans');
  } else {
    print('✅ No generic nested spans');
  }
  
  if (html.contains('&amp;') && html.contains('&lt;') && html.contains('&gt;')) {
    print('✅ All basic HTML entities escaped');
  } else {
    print('❌ Missing HTML entity escaping');
  }
  
  print('\nHTML Security Test Complete');
}