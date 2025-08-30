# Flutter Casino Demo - Agent-Based Architecture

This directory contains a complete agent-based architecture system for the Flutter casino demo application. The system is designed with clean architecture principles, proper separation of concerns, and comprehensive functionality for a casino gaming platform.

## Architecture Overview

The agent system consists of six main components, each with a specific responsibility:

```
┌─────────────────────┐
│  CasinoOrchestrator │  ← High-level coordination
└─────────┬───────────┘
          │
    ┌─────▼─────┐
    │   Agents  │
    └─────┬─────┘
          │
┌─────────▼─────────────────────────────────────────┐
│  BaseAgent (Infrastructure)                      │
├───────────────────────────────────────────────────┤
│  ResourceManagerAgent    │  ContextManagerAgent   │
│  (Credits & Bets)        │  (Session State)       │
├──────────────────────────┼─────────────────────────┤
│  ConfigManagerAgent      │  ReportGeneratorAgent  │
│  (Player Profiles)       │  (Statistics)          │
├──────────────────────────┼─────────────────────────┤
│  GameEngineAgent         │                        │
│  (Game Logic & RNG)      │                        │
└──────────────────────────┴─────────────────────────┘
```

## Core Components

### 1. BaseAgent (`base_agent.dart`)

**Purpose**: Provides common infrastructure for all agents

**Key Features**:
- Lifecycle management (initialize, dispose, status tracking)
- Error handling and logging
- Agent metadata and identification
- Status enumeration (uninitialized, active, error, etc.)

**Usage**:
```dart
abstract class YourAgent extends BaseAgentImpl {
  @override
  String get agentType => 'YourAgentType';
  
  @override
  Future<void> onInitialize() async {
    // Your initialization logic
  }
  
  @override
  Future<void> onDispose() async {
    // Your cleanup logic
  }
}
```

### 2. ResourceManagerAgent (`resource_manager_agent.dart`)

**Purpose**: Manages player resources, credits, bets, and financial constraints

**Key Features**:
- Credit management with real-time updates
- Bet validation and processing
- Winnings calculation and distribution
- Financial statistics tracking
- Betting limits and constraints
- Resource update streaming

**Key Methods**:
```dart
// Set and validate bets
bool setBet(double amount);
bool placeBet();

// Process winnings
void processWinnings(double winAmount);

// Add credits (bonus, purchase)
void addCredits(double amount, {String reason});

// Get comprehensive summary
ResourceSummary getResourceSummary();
```

**Event Streaming**:
```dart
// Listen to real-time resource updates
resourceManager.resourceUpdates.listen((update) {
  switch (update.type) {
    case ResourceUpdateType.creditsChanged:
      // Handle credit changes
      break;
    case ResourceUpdateType.winningsProcessed:
      // Handle winnings
      break;
  }
});
```

### 3. ContextManagerAgent (`context_manager_agent.dart`)

**Purpose**: Manages session state, game context, and user preferences

**Key Features**:
- Session lifecycle management
- Game state tracking
- Action history recording
- User preferences storage
- Context data management
- Session export/import

**Key Methods**:
```dart
// Session management
Future<String> startSession({String? userId});
Future<void> endSession();

// Game context
void startGame(String gameType);
void endGame({Map<String, dynamic>? gameResults});

// Action tracking
void recordAction(GameActionType actionType, {Map<String, dynamic>? actionData});

// Data management
void setSessionData(String key, dynamic value);
T? getSessionData<T>(String key);
```

### 4. ConfigManagerAgent (`config_manager_agent.dart`)

**Purpose**: Manages player profiles, game configurations, and global settings

**Key Features**:
- Player profile management
- Game configuration templates
- Global settings management
- Profile statistics tracking
- Import/export functionality
- Multi-profile support

**Key Methods**:
```dart
// Profile management
Future<String> createPlayerProfile({required String displayName});
Future<bool> loadPlayerProfile(String profileId);
void updateCurrentProfile({String? displayName, String? email});

// Game configuration
void registerGameConfig(GameConfig config);
GameConfig? getGameConfig(String gameId);

// Settings
void setGlobalSetting(String key, dynamic value);
T? getGlobalSetting<T>(String key);
```

### 5. ReportGeneratorAgent (`report_generator_agent.dart`)

**Purpose**: Generates comprehensive reports and statistics analysis

**Key Features**:
- Multiple report types (session, performance, financial, behavior)
- Real-time statistics
- Custom report templates
- Export formats (JSON, CSV)
- Trend analysis
- Player behavior analytics

**Report Types**:
- **Session Summary**: Overview of gaming sessions
- **Game Performance**: Win/loss analysis by game type
- **Financial Summary**: Financial overview with RTP analysis
- **Player Behavior**: Playing patterns and session behavior

**Key Methods**:
```dart
// Generate reports
Future<String> generateReport(String templateId, {DateTime? startDate, DateTime? endDate});

// Real-time stats
Map<String, dynamic> getRealTimeStatistics();

// Export functionality
String exportReportAsJson(String reportId);
String exportReportAsCsv(String reportId);
```

### 6. GameEngineAgent (`game_engine_agent.dart`)

**Purpose**: Provides secure randomization, game logic execution, and fairness verification

**Key Features**:
- Secure random number generation
- Multiple game type support (Slots, Roulette, Blackjack, Poker)
- Fairness tracking and RTP management
- Game template system
- Real-time game execution
- Cryptographic integrity

**Supported Games**:
- **Slot Machine**: Multi-reel slots with configurable paylines
- **Roulette**: European/American wheel variations
- **Blackjack**: Classic blackjack with standard rules
- **Poker**: 5-card draw poker with standard payouts
- **Custom**: Extensible custom game support

**Key Methods**:
```dart
// Game management
Future<String> createGame(String templateId, {double? betAmount});
Future<bool> startGame(String gameId);
Future<GameResult> executeRound(String gameId);
Future<void> endGame(String gameId);

// Fairness verification
Map<String, FairnessMetrics> getFairnessMetrics();
bool verifyRNGIntegrity();
```

## System Coordination

### CasinoOrchestrator (`casino_orchestrator.dart`)

The orchestrator coordinates all agents and provides a high-level interface for the application:

```dart
// Initialize the system
final orchestrator = CasinoOrchestrator();
await orchestrator.initialize();

// Start a gaming session
final session = await orchestrator.startSession(
  playerName: 'John Doe',
  initialCredits: 1000.0,
);

// Play a game round
final result = await orchestrator.playRound(
  gameType: 'slots',
  betAmount: 10.0,
);

// Get real-time statistics
final stats = orchestrator.getRealTimeStatistics();

// Generate reports
final report = await orchestrator.generateSessionReport();
```

## Usage Examples

### Basic Setup

```dart
import 'package:flutter_casino_demo/core/agents/agents.dart';

void main() async {
  // Initialize orchestrator
  final casino = CasinoOrchestrator();
  await casino.initialize();

  // Start session
  final session = await casino.startSession(
    playerName: 'Player One',
    initialCredits: 500.0,
  );

  // Play some rounds
  for (int i = 0; i < 10; i++) {
    try {
      final result = await casino.playRound(
        gameType: 'slots',
        betAmount: 5.0,
      );
      
      print('Round ${i + 1}: ${result.gameResult.isWin ? 'WIN' : 'LOSE'} '
            '- ${result.gameResult.winAmount} (Balance: ${result.newBalance})');
    } catch (e) {
      print('Error in round ${i + 1}: $e');
      break;
    }
  }

  // Generate final report
  final report = await casino.generateSessionReport();
  print('Session Report: $report');

  // Cleanup
  await session.endSession();
  await casino.dispose();
}
```

### Individual Agent Usage

```dart
// Use agents individually for specific functionality
final resourceManager = ResourceManagerAgent();
await resourceManager.initialize();

// Set initial credits and betting limits
resourceManager.setInitialCredits(1000.0);
resourceManager.setBettingLimits(minimum: 1.0, maximum: 100.0);

// Listen to resource updates
resourceManager.resourceUpdates.listen((update) {
  print('Resource update: ${update.type} - ${update.data}');
});

// Place a bet
if (resourceManager.setBet(25.0)) {
  if (resourceManager.placeBet()) {
    print('Bet placed successfully');
    
    // Simulate winnings
    resourceManager.processWinnings(50.0);
  }
}
```

## Architecture Principles

### 1. Single Responsibility
Each agent has one primary responsibility:
- ResourceManager: Financial operations
- ContextManager: State management
- ConfigManager: Configuration and profiles
- ReportGenerator: Analytics and reporting
- GameEngine: Game logic and randomization

### 2. Clean Architecture
- **Independence**: Agents can operate independently
- **Testability**: Each agent can be unit tested in isolation
- **Flexibility**: Easy to replace or extend individual agents
- **Maintainability**: Clear separation of concerns

### 3. Event-Driven Communication
- Agents communicate through streams and events
- Loose coupling between components
- Real-time updates and notifications
- Asynchronous operation support

### 4. Error Handling
- Comprehensive error handling at each level
- Graceful degradation on failures
- Detailed error reporting and logging
- Recovery mechanisms where possible

## Testing Strategy

```dart
// Unit testing individual agents
test('ResourceManagerAgent handles bets correctly', () async {
  final agent = ResourceManagerAgent();
  await agent.initialize();
  
  agent.setInitialCredits(100.0);
  
  expect(agent.setBet(50.0), isTrue);
  expect(agent.setBet(150.0), isFalse); // Insufficient credits
  
  await agent.dispose();
});

// Integration testing agent coordination
test('Orchestrator coordinates agents properly', () async {
  final orchestrator = CasinoOrchestrator();
  await orchestrator.initialize();
  
  final session = await orchestrator.startSession(initialCredits: 100.0);
  final result = await orchestrator.playRound(gameType: 'slots', betAmount: 10.0);
  
  expect(result.newBalance, lessThanOrEqualTo(100.0));
  
  await session.endSession();
  await orchestrator.dispose();
});
```

## Performance Considerations

### Memory Management
- Agents properly dispose of resources
- Stream subscriptions are managed and cancelled
- Large data structures are cleared on disposal

### Scalability
- Event streaming for real-time updates
- Configurable limits and thresholds
- Efficient data structures and algorithms

### Security
- Secure random number generation
- Input validation on all public methods
- Protection against common attack vectors

## Extension Points

### Adding New Game Types
1. Extend the `GameType` enum
2. Create a new game template
3. Implement game logic in `GameEngineAgent`
4. Register the template in the system

### Custom Report Types
1. Extend the `ReportType` enum
2. Create a new report template
3. Implement generation logic in `ReportGeneratorAgent`
4. Register the template for use

### Additional Agents
1. Extend `BaseAgentImpl`
2. Implement required abstract methods
3. Add to orchestrator coordination
4. Export from `agents.dart`

This agent-based architecture provides a robust, scalable, and maintainable foundation for casino gaming applications with comprehensive functionality and clean separation of concerns.