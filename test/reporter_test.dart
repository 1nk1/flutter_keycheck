import 'package:flutter_keycheck/src/reporter/base_reporter.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

void main() {
  group('ReporterFactory', () {
    test('should create correct reporter types', () {
      expect(ReporterFactory.create('human'), isA<HumanReporter>());
      expect(ReporterFactory.create('json'), isA<JsonReporter>());
      expect(ReporterFactory.create('html'), isA<HtmlReporter>());
      expect(ReporterFactory.create('markdown'), isA<MarkdownReporter>());
      expect(ReporterFactory.create('junit'), isA<JUnitReporter>());
      expect(ReporterFactory.create('unknown'), isA<HumanReporter>()); // Default
    });

    test('should list available formats', () {
      final formats = ReporterFactory.availableFormats;
      expect(formats, contains('human'));
      expect(formats, contains('json'));
      expect(formats, contains('html'));
      expect(formats, contains('markdown'));
      expect(formats, contains('junit'));
    });
  });

  group('ReportData', () {
    test('should calculate coverage correctly', () {
      final data = ReportData(
        expectedKeys: {'key1', 'key2', 'key3'},
        foundKeys: {'key1', 'key2'},
        missingKeys: {'key3'},
        extraKeys: {'key4'},
        projectPath: '/test',
      );

      expect(data.coverage, equals(66.66666666666667));
      expect(data.passed, equals(false));
    });

    test('should pass when no missing keys', () {
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1', 'key2', 'key3'},
        missingKeys: {},
        extraKeys: {'key3'},
        projectPath: '/test',
      );

      expect(data.coverage, equals(100.0));
      expect(data.passed, equals(true));
    });

    test('should provide summary statistics', () {
      final data = ReportData(
        expectedKeys: {'key1', 'key2', 'key3'},
        foundKeys: {'key1', 'key2', 'key4'},
        missingKeys: {'key3'},
        extraKeys: {'key4'},
        projectPath: '/test',
      );

      final summary = data.summary;
      expect(summary['expected'], equals(3));
      expect(summary['found'], equals(3));
      expect(summary['missing'], equals(1));
      expect(summary['extra'], equals(1));
      expect(summary['passed'], equals(false));
    });
  });

  group('HumanReporter', () {
    test('should generate human-readable report', () {
      final reporter = HumanReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2', 'key3'},
        foundKeys: {'key1', 'key2'},
        missingKeys: {'key3'},
        extraKeys: {'key4'},
        projectPath: '/test/project',
        scanDuration: Duration(milliseconds: 123),
        scannedFiles: ['file1.dart', 'file2.dart'],
      );

      final report = reporter.generate(data);

      expect(report, contains('Flutter KeyCheck Report'));
      expect(report, contains('Project: /test/project'));
      expect(report, contains('Scan Duration: 123ms'));
      expect(report, contains('Files Scanned: 2'));
      expect(report, contains('Expected Keys: 3'));
      expect(report, contains('Missing Keys: 1'));
      expect(report, contains('❌ FAILED'));
      expect(report, contains('❌ key3'));
      expect(report, contains('⚠️ key4'));
    });

    test('should show passed status when appropriate', () {
      final reporter = HumanReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1', 'key2'},
        missingKeys: {},
        extraKeys: {},
        projectPath: '/test',
      );

      final report = reporter.generate(data);
      expect(report, contains('✅ PASSED'));
    });
  });

  group('JsonReporter', () {
    test('should generate valid JSON report', () {
      final reporter = JsonReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1'},
        missingKeys: {'key2'},
        extraKeys: {'key3'},
        projectPath: '/test',
        keyUsageCounts: {'key1': 2, 'key3': 1},
      );

      final jsonString = reporter.generate(data);
      final json = jsonDecode(jsonString);

      expect(json['projectPath'], equals('/test'));
      expect(json['summary']['expected'], equals(2));
      expect(json['summary']['missing'], equals(1));
      expect(json['missingKeys'], contains('key2'));
      expect(json['extraKeys'], contains('key3'));
      expect(json['keyUsageCounts']['key1'], equals(2));
    });

    test('should format JSON with indentation', () {
      final reporter = JsonReporter();
      final data = ReportData(
        expectedKeys: {'key1'},
        foundKeys: {'key1'},
        missingKeys: {},
        extraKeys: {},
        projectPath: '/test',
      );

      final jsonString = reporter.generate(data);
      expect(jsonString, contains('\n  ')); // Check for indentation
    });
  });

  group('HtmlReporter', () {
    test('should generate valid HTML report', () {
      final reporter = HtmlReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1'},
        missingKeys: {'key2'},
        extraKeys: {'key3'},
        projectPath: '/test',
      );

      final html = reporter.generate(data);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>Flutter KeyCheck Report</title>'));
      expect(html, contains('Project: /test'));
      expect(html, contains('❌ FAILED'));
      expect(html, contains('❌ key2'));
      expect(html, contains('⚠️ key3'));
    });
  });

  group('MarkdownReporter', () {
    test('should generate valid Markdown report', () {
      final reporter = MarkdownReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1'},
        missingKeys: {'key2'},
        extraKeys: {'key3'},
        projectPath: '/test',
      );

      final markdown = reporter.generate(data);

      expect(markdown, contains('# Flutter KeyCheck Report'));
      expect(markdown, contains('**Project:** `/test`'));
      expect(markdown, contains('| Expected Keys | 2 |'));
      expect(markdown, contains('## Missing Keys'));
      expect(markdown, contains('- ❌ `key2`'));
      expect(markdown, contains('## Extra Keys'));
      expect(markdown, contains('- ⚠️ `key3`'));
    });
  });

  group('JUnitReporter', () {
    test('should generate valid JUnit XML report', () {
      final reporter = JUnitReporter();
      final data = ReportData(
        expectedKeys: {'key1', 'key2'},
        foundKeys: {'key1'},
        missingKeys: {'key2'},
        extraKeys: {},
        projectPath: '/test',
        scanDuration: Duration(milliseconds: 500),
      );

      final xml = reporter.generate(data);

      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<testsuites name="Flutter KeyCheck" tests="2" failures="1">'));
      expect(xml, contains('<testsuite name="Key Validation" tests="2" failures="1" time="0.5">'));
      expect(xml, contains('<testcase name="key1" classname="KeyValidation">'));
      expect(xml, contains('<testcase name="key2" classname="KeyValidation">'));
      expect(xml, contains('<failure message="Key not found in project">Missing key: key2</failure>'));
    });
  });

  group('Reporter file writing', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('reporter_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should write report to file', () async {
      final reporter = JsonReporter();
      final data = ReportData(
        expectedKeys: {'key1'},
        foundKeys: {'key1'},
        missingKeys: {},
        extraKeys: {},
        projectPath: '/test',
      );

      final outputPath = path.join(tempDir.path, 'report.json');
      await reporter.writeToFile(data, outputPath);

      final file = File(outputPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final json = jsonDecode(content);
      expect(json['projectPath'], equals('/test'));
    });

    test('should create parent directories if needed', () async {
      final reporter = HumanReporter();
      final data = ReportData(
        expectedKeys: {'key1'},
        foundKeys: {'key1'},
        missingKeys: {},
        extraKeys: {},
        projectPath: '/test',
      );

      final outputPath = path.join(tempDir.path, 'nested', 'dir', 'report.txt');
      await reporter.writeToFile(data, outputPath);

      final file = File(outputPath);
      expect(file.existsSync(), isTrue);
    });
  });
}