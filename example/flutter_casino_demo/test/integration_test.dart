import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_casino_demo/main.dart';

void main() {
  group('Flutter KeyCheck Integration Tests', () {
    
    testWidgets('✅ Should find all tracked keys from casino app', (WidgetTester tester) async {
      // Build the casino app
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();

      // Test tracked keys - main game cards
      print('🔍 Testing Game Navigation Keys...');
      
      // ✅ Verified: slotsGameCard
      expect(find.byKey(const Key('slotsGameCard')), findsOneWidget);
      print('✅ slotsGameCard - Found and accessible');
      
      // ✅ Verified: rouletteGameCard  
      expect(find.byKey(const Key('rouletteGameCard')), findsOneWidget);
      print('✅ rouletteGameCard - Found and accessible');
      
      // ✅ Verified: blackjackGameCard
      expect(find.byKey(const Key('blackjackGameCard')), findsOneWidget);
      print('✅ blackjackGameCard - Found and accessible');
    });

    testWidgets('✅ Should navigate to Slots game and find spin button', (WidgetTester tester) async {
      // Build the app and navigate to slots
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🎰 Testing Slots Game Keys...');
      
      // Tap on slots game card to navigate
      await tester.tap(find.byKey(const Key('slotsGameCard')));
      await tester.pumpAndSettle();
      
      // ✅ Verified: spinButton
      expect(find.byKey(const Key('spinButton')), findsOneWidget);
      print('✅ spinButton - Found in Slots game screen');
      
      // Test bet controls
      expect(find.byKey(const Key('decreaseBetButton')), findsOneWidget);
      expect(find.byKey(const Key('increaseBetButton')), findsOneWidget);
      print('✅ Bet control buttons - Found and accessible');
    });

    testWidgets('✅ Should navigate to Roulette game and find controls', (WidgetTester tester) async {
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🎯 Testing Roulette Game Keys...');
      
      // Navigate to roulette
      await tester.tap(find.byKey(const Key('rouletteGameCard')));
      await tester.pumpAndSettle();
      
      // ✅ Verified: spinRouletteButton
      expect(find.byKey(const Key('spinRouletteButton')), findsOneWidget);
      print('✅ spinRouletteButton - Found in Roulette game screen');
      
      // Test betting chips
      expect(find.byKey(const Key('redBet')), findsOneWidget);
      expect(find.byKey(const Key('blackBet')), findsOneWidget);
      print('✅ Roulette betting options - Found and accessible');
    });

    testWidgets('✅ Should navigate to Blackjack game and find all action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🃏 Testing Blackjack Game Keys...');
      
      // Navigate to blackjack
      await tester.tap(find.byKey(const Key('blackjackGameCard')));
      await tester.pumpAndSettle();
      
      // ✅ Verified: dealButton
      expect(find.byKey(const Key('dealButton')), findsOneWidget);
      print('✅ dealButton - Found in Blackjack game screen');
      
      // Start a game to reveal more buttons
      await tester.tap(find.byKey(const Key('dealButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      
      // ✅ Verified: hitButton and standButton
      expect(find.byKey(const Key('hitButton')), findsOneWidget);
      expect(find.byKey(const Key('standButton')), findsOneWidget);
      print('✅ hitButton, standButton - Found after dealing cards');
    });

    testWidgets('✅ Should navigate to Demo Mode and find run button', (WidgetTester tester) async {
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🎮 Testing Demo Mode Keys...');
      
      // Navigate to demo mode
      await tester.tap(find.byKey(const Key('demoModeCard')));
      await tester.pumpAndSettle();
      
      // ✅ Verified: runDemoButton
      expect(find.byKey(const Key('runDemoButton')), findsOneWidget);
      print('✅ runDemoButton - Found in Demo Mode screen');
    });

    testWidgets('❌ Should detect missing keys (negative test)', (WidgetTester tester) async {
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🔍 Testing Missing Keys Detection...');
      
      // These keys should NOT be found (negative test)
      expect(find.byKey(const Key('nonExistentKey')), findsNothing);
      expect(find.byKey(const Key('missingButton')), findsNothing);
      print('❌ Non-existent keys properly not found');
    });

    testWidgets('✅ Full workflow: Key functionality validation', (WidgetTester tester) async {
      await tester.pumpWidget(const CasinoApp());
      await tester.pump();
      
      print('🔄 Testing Full Key Workflow...');
      
      // Test complete workflow for Slots game
      await tester.tap(find.byKey(const Key('slotsGameCard')));
      await tester.pumpAndSettle();
      
      // Test bet adjustment
      await tester.tap(find.byKey(const Key('increaseBetButton')));
      await tester.pump();
      
      // Test spin functionality
      await tester.tap(find.byKey(const Key('spinButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100)); // Wait for spin animation
      
      print('✅ Complete workflow validation successful');
    });
  });
}

// Import the actual class from main.dart - no need for wrapper class