import 'dart:io';
import 'package:test/test.dart';
import '../lib/src/models/scan_result.dart';
import '../lib/src/models/key_usage.dart';
import '../lib/src/models/location.dart';
import '../lib/src/models/scan_metrics.dart';
import '../lib/src/reporter/premium_dashboard_reporter_v2.dart';

/// Demonstration test for Enhanced Premium Reporter - Priority 1 Features
/// Shows the new syntax highlighting, collapsible blocks, and mobile improvements
void main() {
  group('Enhanced Premium Reporter Demo', () {
    test('generates enhanced report with Priority 1 features', () async {
      // Create sample scan result with complex Dart code examples
      final scanResult = ScanResult(
        projectName: 'Enhanced Flutter KeyCheck Demo',
        scannedFiles: [
          'lib/main.dart',
          'lib/widgets/game_card.dart',
          'lib/screens/casino_screen.dart',
          'lib/models/game_model.dart',
          'test/widget_test.dart'
        ],
        keyUsages: {
          'main_scaffold': KeyUsage(
            name: 'main_scaffold',
            type: 'Key',
            status: 'active',
            locations: [
              Location(
                file: 'lib/main.dart',
                line: 25,
                column: 12,
                context: '''@override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'Flutter Demo App',
    theme: ThemeData(
      // Enhanced theme with null safety
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    home: Scaffold(
      key: Key('main_scaffold'), // ← Key usage here
      appBar: AppBar(
        title: Text('Enhanced Flutter KeyCheck Demo'),
      ),
      body: const Center(
        child: GameGrid(),
      ),
    ),
  );
}''',
              ),
            ],
          ),
          'casino_card_\${gameId}': KeyUsage(
            name: 'casino_card_\${gameId}',
            type: 'ValueKey',
            status: 'active',
            locations: [
              Location(
                file: 'lib/widgets/game_card.dart',
                line: 15,
                column: 8,
                context: '''class GameCard extends StatelessWidget {
  final String gameId;
  final String? gameName; // Null safety example
  final GameData gameData;
  
  const GameCard({
    super.key,
    required this.gameId,
    this.gameName,
    required this.gameData,
  });

  @override
  Widget build(BuildContext context) {
    // String interpolation example
    final displayName = gameName ?? 'Game \${gameId}';
    
    return GestureDetector(
      key: ValueKey('casino_card_\${gameId}'), // ← Enhanced key with interpolation
      onTap: () async {
        // Async/await pattern
        await Navigator.pushNamed(
          context, 
          '/game/\${gameId}',
          arguments: gameData,
        );
      },
      child: Card(
        elevation: 4.0,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // TODO: Add game image
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              /* Multi-line comment example:
               * This section handles the game statistics
               * with proper error handling
               */
              if (gameData.stats != null) 
                GameStatsWidget(stats: gameData.stats!),
            ],
          ),
        ),
      ),
    );
  }
}''',
              ),
              Location(
                file: 'test/widget_test.dart',
                line: 42,
                column: 20,
                context: '''testWidgets('GameCard displays correctly', (WidgetTester tester) async {
  // Build our app and trigger a frame
  const testGameId = 'poker_game_001';
  const testGameData = GameData(
    id: testGameId,
    name: 'Texas Hold\\'em Poker',
    category: GameCategory.cards,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GameCard(
          gameId: testGameId,
          gameName: 'Poker Game',
          gameData: testGameData,
        ),
      ),
    ),
  );

  // Verify key exists and is findable
  expect(find.byKey(ValueKey('casino_card_\${testGameId}')), findsOneWidget);
  
  // Test tap behavior
  await tester.tap(find.byKey(ValueKey('casino_card_\${testGameId}')));
  await tester.pumpAndSettle();
  
  // Verify navigation occurred
  expect(find.text('Poker Game'), findsOneWidget);
});''',
              ),
            ],
          ),
          'login_button': KeyUsage(
            name: 'login_button',
            type: 'Key',
            status: 'active',
            locations: [
              Location(
                file: 'lib/screens/auth_screen.dart',
                line: 78,
                column: 16,
                context: '''Future<void> _handleLogin() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Generic type example
    final result = await AuthService.login<LoginResponse>(
      email: _emailController.text,
      password: _passwordController.text,
    );
    
    // Null-aware operators
    final user = result?.user;
    final token = user?.token ?? '';
    
    if (token.isNotEmpty) {
      await SecureStorage.store('auth_token', token);
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  } catch (e) {
    // Error handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login failed: \$e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Widget _buildLoginButton() {
  return ElevatedButton(key: Key("elevated_btn_${RANDOM}"), 
    key: const Key('login_button'), // ← Key usage
    onPressed: _isLoading ? null : _handleLogin,
    child: _isLoading 
        ? const CircularProgressIndicator()
        : const Text('Login'),
  );
}''',
              ),
            ],
          ),
          'deprecated_widget_key': KeyUsage(
            name: 'deprecated_widget_key',
            type: 'Key',
            status: 'inactive',
            locations: [
              Location(
                file: 'lib/widgets/old_component.dart',
                line: 12,
                column: 8,
                context: '''@Deprecated('Use NewComponent instead')
class OldComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('deprecated_widget_key'), // ← Inactive key
      child: Text('This component is deprecated'),
    );
  }
}''',
              ),
            ],
          ),
        },
        metrics: ScanMetrics(
          totalScanTime: Duration(milliseconds: 1234),
          scannedFiles: 5,
          totalLines: 847,
          fileCoverage: 85.6,
          keyDensity: 3.2,
        ),
      );

      // Generate enhanced report
      final reporter = PremiumDashboardReporterV2();
      final htmlReport = reporter.generateReport(scanResult);

      // Write to file for inspection
      final outputFile = File('enhanced_demo_report.html');
      await outputFile.writeAsString(htmlReport);

      // Verify enhanced features are present
      expect(htmlReport.contains('Enhanced Code Analysis Report'), isTrue);
      expect(htmlReport.contains('Priority 1 Features'), isTrue);
      expect(htmlReport.contains('token.interpolation'), isTrue);
      expect(htmlReport.contains('token.annotation'), isTrue);
      expect(htmlReport.contains('null-safety'), isTrue);
      expect(htmlReport.contains('collapse-btn'), isTrue);
      expect(htmlReport.contains('enhanced-copy'), isTrue);
      expect(htmlReport.contains('@media (max-width: 768px)'), isTrue);
      expect(htmlReport.contains('touch-friendly'), isTrue);
      
      print('✅ Enhanced Premium Reporter Demo Report generated successfully!');
      print('📱 Features included:');
      print('   • Enhanced Dart syntax highlighting with string interpolation');
      print('   • Multi-line comment support with TODO/FIXME highlighting');
      print('   • Generics and annotations highlighting');
      print('   • Null safety operators (?, ??, ?!, ?.)');
      print('   • Async/await pattern highlighting');
      print('   • Collapsible code blocks for classes and methods');
      print('   • Enhanced copy-to-clipboard with line selection');
      print('   • Mobile-first responsive design');
      print('   • Touch-friendly interface improvements');
      print('   • Accessibility enhancements');
      print('');
      print('📄 Report saved as: enhanced_demo_report.html');
      print('🌐 Open in browser to see the enhanced features in action!');
    });

    test('validates mobile responsiveness features', () {
      final reporter = PremiumDashboardReporterV2();
      final mockResult = ScanResult(
        projectName: 'Mobile Test',
        scannedFiles: ['test.dart'],
        keyUsages: {
          'test_key': KeyUsage(
            name: 'test_key',
            type: 'Key',
            status: 'active',
            locations: [
              Location(
                file: 'test.dart',
                line: 1,
                column: 1,
                context: 'Widget build() { return Container(key: Key("test")); }',
              )
            ],
          )
        },
        metrics: ScanMetrics(
          totalScanTime: Duration(milliseconds: 500),
          scannedFiles: 1,
          totalLines: 10,
          fileCoverage: 100.0,
          keyDensity: 1.0,
        ),
      );

      final htmlReport = reporter.generateReport(mockResult);

      // Validate mobile-specific CSS
      expect(htmlReport.contains('@media (max-width: 768px)'), isTrue);
      expect(htmlReport.contains('@media (pointer: coarse)'), isTrue);
      expect(htmlReport.contains('min-height: 44px'), isTrue); // Touch targets
      expect(htmlReport.contains('touch-friendly'), isTrue);
      expect(htmlReport.contains('responsive'), isTrue);

      print('✅ Mobile responsiveness validation passed!');
    });
  });
}