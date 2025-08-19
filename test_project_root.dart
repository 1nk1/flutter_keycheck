#!/usr/bin/env dart
/// Test script to verify --project-root functionality

import 'dart:io';
import 'dart:convert';

void main() async {
  print('Testing --project-root functionality...\n');
  
  // Test 1: Scan with explicit project root (current directory)
  print('Test 1: Scan with --project-root .');
  final result1 = await Process.run(
    'dart',
    ['run', 'bin/flutter_keycheck.dart', 'scan', '--project-root', '.', '--report', 'json'],
  );
  
  if (result1.exitCode == 0) {
    print('✅ Scan with --project-root succeeded');
    
    // Check if reports were created
    final reportFile = File('reports/scan-report.json');
    if (await reportFile.exists()) {
      print('✅ Report file created successfully');
      
      // Parse and check the JSON
      try {
        final content = await reportFile.readAsString();
        final json = jsonDecode(content);
        print('  - Schema version: ${json['schema_version']}');
        print('  - Total keys found: ${json['keys']?.length ?? 0}');
      } catch (e) {
        print('⚠️ Could not parse report JSON: $e');
      }
    } else {
      print('❌ Report file not found');
    }
  } else {
    print('❌ Scan failed with exit code: ${result1.exitCode}');
    print('Stderr: ${result1.stderr}');
  }
  
  // Test 2: Scan with different report formats
  print('\nTest 2: Scan with HTML report format');
  final result2 = await Process.run(
    'dart',
    ['run', 'bin/flutter_keycheck.dart', 'scan', '--project-root', '.', '--report', 'html'],
  );
  
  if (result2.exitCode == 0) {
    print('✅ Scan with HTML report succeeded');
    
    final htmlFile = File('reports/scan-report.html');
    if (await htmlFile.exists()) {
      print('✅ HTML report created successfully');
      final content = await htmlFile.readAsString();
      if (content.contains('<!DOCTYPE html>') && content.contains('Flutter KeyCheck')) {
        print('✅ HTML report appears valid');
      }
    }
  } else {
    print('❌ HTML scan failed: ${result2.stderr}');
  }
  
  // Test 3: Test dependency scanning
  print('\nTest 3: Scan with dependency analysis');
  final result3 = await Process.run(
    'dart',
    ['run', 'bin/flutter_keycheck.dart', 'scan', '--project-root', '.', '--scope', 'all', '--verbose'],
  );
  
  if (result3.exitCode == 0) {
    print('✅ Dependency scan succeeded');
    if (result3.stdout.toString().contains('Dependency Statistics')) {
      print('✅ Dependency statistics displayed');
    }
  } else {
    print('❌ Dependency scan failed: ${result3.stderr}');
  }
  
  // Test 4: Validate command with project-root
  print('\nTest 4: Validate command with --project-root');
  final result4 = await Process.run(
    'dart',
    ['run', 'bin/flutter_keycheck.dart', 'validate', '--project-root', '.'],
  );
  
  // Validate command might fail if there are violations, but that's ok
  // We just want to make sure it runs without errors
  if (result4.exitCode == 0 || result4.exitCode == 1) {
    print('✅ Validate command executed successfully');
  } else {
    print('❌ Validate command failed unexpectedly: ${result4.stderr}');
  }
  
  print('\n✅ All tests completed!');
}