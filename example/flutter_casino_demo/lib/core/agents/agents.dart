/// Flutter Casino Demo - Agent-Based Architecture System
/// 
/// This file exports all the agents in the casino system, providing a clean
/// interface for the application to interact with the agent-based architecture.
/// 
/// The agent system follows clean architecture principles with proper separation
/// of concerns, ensuring each agent has a single responsibility and clear interfaces.

// Base agent infrastructure
export 'base_agent.dart';

// Core business logic agents
export 'resource_manager_agent.dart';
export 'context_manager_agent.dart';
export 'config_manager_agent.dart';
export 'report_generator_agent.dart';
export 'game_engine_agent.dart';

/// Agent system overview:
/// 
/// 1. **BaseAgent**: Provides common infrastructure for all agents including
///    lifecycle management, error handling, and status tracking.
/// 
/// 2. **ResourceManagerAgent**: Manages player resources including credits,
///    bets, winnings, and financial constraints. Provides real-time updates
///    and ensures financial integrity.
/// 
/// 3. **ContextManagerAgent**: Handles session state, game context, and user
///    preferences. Tracks action history and manages session lifecycle.
/// 
/// 4. **ConfigManagerAgent**: Manages player profiles, game configurations,
///    and global settings. Supports import/export and profile switching.
/// 
/// 5. **ReportGeneratorAgent**: Generates comprehensive reports and statistics
///    including session summaries, performance analysis, and player behavior.
/// 
/// 6. **GameEngineAgent**: Provides secure randomization, game logic execution,
///    and fairness verification. Supports multiple game types with configurable
///    templates.
/// 
/// Each agent operates independently but can communicate through well-defined
/// interfaces, allowing for flexible system composition and testing.