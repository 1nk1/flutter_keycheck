import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  print('Testing Code Display Implementation...');
  
  final reporter = PremiumDashboardReporter();
  
  // Test 1: Basic functionality
  print('\n1. Testing basic HTML generation...');
  try {
    final basicResult = ScanResult(
      metrics: ScanMetrics(),
      fileAnalyses: {},
      keyUsages: {},
      blindSpots: [],
      duration: Duration(milliseconds: 100),
    );
    
    final html = reporter.generateReport(basicResult);
    print('✅ Basic HTML generation: ${html.length} characters');
    
    if (html.contains('formatCodeContext')) {
      print('✅ Contains new formatCodeContext function');
    } else {
      print('❌ Missing formatCodeContext function');
    }
    
    if (html.contains('highlightDartCode')) {
      print('✅ Contains new highlightDartCode function');
    } else {
      print('❌ Missing highlightDartCode function');
    }
    
    if (html.contains('tokenizeDartCode')) {
      print('✅ Contains new tokenizeDartCode function');
    } else {
      print('❌ Missing tokenizeDartCode function');
    }
    
  } catch (e) {
    print('❌ Basic test failed: $e');
  }
  
  // Test 2: With real key data
  print('\n2. Testing with key data...');
  try {
    final keyUsage = KeyUsage(id: 'test_key');
    keyUsage.locations.add(KeyLocation(
      file: 'test.dart',
      line: 10,
      column: 5,
      detector: 'test',
      context: 'Key("test_key")',
    ));
    
    final keyDataResult = ScanResult(
      metrics: ScanMetrics(),
      fileAnalyses: {},
      keyUsages: {'test_key': keyUsage},
      blindSpots: [],
      duration: Duration(milliseconds: 100),
    );
    
    final html = reporter.generateReport(keyDataResult);
    print('✅ Key data HTML generation: ${html.length} characters');
    
    // Check for old regex patterns (should not exist)
    if (!html.contains('.replace(/\\\\b(\\\\d+') && !html.contains('(?!<span)')) {
      print('✅ Old regex patterns removed');
    } else {
      print('❌ Old regex patterns still present');
    }
    
  } catch (e) {
    print('❌ Key data test failed: $e');
  }
  
  // Test 3: HTML security
  print('\n3. Testing HTML security...');
  try {
    final keyUsage = KeyUsage(id: 'security_test');
    keyUsage.locations.add(KeyLocation(
      file: 'security.dart',
      line: 1,
      column: 1,
      detector: 'test',
      context: '<script>alert("xss")</script>',
    ));
    
    final securityResult = ScanResult(
      metrics: ScanMetrics(),
      fileAnalyses: {},
      keyUsages: {'security_test': keyUsage},
      blindSpots: [],
      duration: Duration(milliseconds: 100),
    );
    
    final html = reporter.generateReport(securityResult);
    
    if (html.contains('&lt;script&gt;') && !html.contains('<script>alert')) {
      print('✅ HTML entities properly escaped');
    } else {
      print('❌ HTML security issue detected');
    }
    
  } catch (e) {
    print('❌ Security test failed: $e');
  }
  
  print('\nCode Display Implementation Testing Complete!');
}