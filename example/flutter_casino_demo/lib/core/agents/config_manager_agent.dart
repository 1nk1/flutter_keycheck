import 'dart:async';
import 'dart:convert';
import 'base_agent.dart';

/// Agent responsible for managing player profiles and game configuration
class ConfigManagerAgent extends BaseAgentImpl {
  static const String _agentTypeId = 'ConfigManager';

  // Player profiles
  final Map<String, PlayerProfile> _profiles = {};
  PlayerProfile? _currentProfile;

  // Game configurations
  final Map<String, GameConfig> _gameConfigs = {};

  // Global settings
  final Map<String, dynamic> _globalSettings = {};

  // Stream controllers
  final StreamController<ConfigUpdate> _configUpdateController =
      StreamController<ConfigUpdate>.broadcast();

  @override
  String get agentType => _agentTypeId;

  /// Stream of configuration updates
  Stream<ConfigUpdate> get configUpdates => _configUpdateController.stream;

  /// Current active player profile
  PlayerProfile? get currentProfile => _currentProfile;

  /// All registered player profiles
  List<PlayerProfile> get allProfiles => List.unmodifiable(_profiles.values);

  /// All game configurations
  List<GameConfig> get allGameConfigs => List.unmodifiable(_gameConfigs.values);

  /// Global settings
  Map<String, dynamic> get globalSettings => Map.unmodifiable(_globalSettings);

  @override
  Future<void> onInitialize() async {
    await _loadDefaultConfigurations();
  }

  @override
  Future<void> onDispose() async {
    await _configUpdateController.close();
  }

  /// Create a new player profile
  Future<String> createPlayerProfile({
    required String displayName,
    String? email,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? gameSettings,
  }) async {
    validateActive();

    final profileId = _generateProfileId();
    final profile = PlayerProfile(
      id: profileId,
      displayName: displayName,
      email: email,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      preferences: preferences ?? {},
      gameSettings: gameSettings ?? {},
      statistics: PlayerStatistics(),
    );

    _profiles[profileId] = profile;

    _emitConfigUpdate(ConfigUpdateType.profileCreated, {
      'profileId': profileId,
      'displayName': displayName,
    });

    return profileId;
  }

  /// Load and activate a player profile
  Future<bool> loadPlayerProfile(String profileId) async {
    validateActive();

    final profile = _profiles[profileId];
    if (profile == null) {
      return false;
    }

    _currentProfile = profile.copyWith(lastActiveAt: DateTime.now());
    _profiles[profileId] = _currentProfile!;

    _emitConfigUpdate(ConfigUpdateType.profileLoaded, {
      'profileId': profileId,
      'displayName': profile.displayName,
    });

    return true;
  }

  /// Update current player profile
  void updateCurrentProfile({
    String? displayName,
    String? email,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? gameSettings,
  }) {
    validateActive();

    if (_currentProfile == null) {
      throw AgentException('No active profile to update',
          agentType: agentType, agentId: agentId);
    }

    _currentProfile = _currentProfile!.copyWith(
      displayName: displayName,
      email: email,
      preferences: preferences,
      gameSettings: gameSettings,
      lastActiveAt: DateTime.now(),
    );

    _profiles[_currentProfile!.id] = _currentProfile!;

    _emitConfigUpdate(ConfigUpdateType.profileUpdated, {
      'profileId': _currentProfile!.id,
      'displayName': _currentProfile!.displayName,
    });
  }

  /// Delete a player profile
  bool deletePlayerProfile(String profileId) {
    validateActive();

    if (_currentProfile?.id == profileId) {
      _currentProfile = null;
    }

    final existed = _profiles.remove(profileId) != null;

    if (existed) {
      _emitConfigUpdate(ConfigUpdateType.profileDeleted, {
        'profileId': profileId,
      });
    }

    return existed;
  }

  /// Update player statistics
  void updatePlayerStatistics(PlayerStatistics statistics) {
    validateActive();

    if (_currentProfile == null) {
      throw AgentException('No active profile for statistics update',
          agentType: agentType, agentId: agentId);
    }

    _currentProfile = _currentProfile!.copyWith(
      statistics: statistics,
      lastActiveAt: DateTime.now(),
    );

    _profiles[_currentProfile!.id] = _currentProfile!;

    _emitConfigUpdate(ConfigUpdateType.statisticsUpdated, {
      'profileId': _currentProfile!.id,
      'statistics': statistics.toJson(),
    });
  }

  /// Set player preference
  void setPlayerPreference(String key, dynamic value) {
    validateActive();

    if (_currentProfile == null) {
      throw AgentException('No active profile for preference update',
          agentType: agentType, agentId: agentId);
    }

    final updatedPreferences =
        Map<String, dynamic>.from(_currentProfile!.preferences);
    updatedPreferences[key] = value;

    updateCurrentProfile(preferences: updatedPreferences);
  }

  /// Get player preference
  T? getPlayerPreference<T>(String key) {
    if (_currentProfile == null) return null;

    final value = _currentProfile!.preferences[key];
    return value is T ? value : null;
  }

  /// Set player game setting
  void setPlayerGameSetting(String key, dynamic value) {
    validateActive();

    if (_currentProfile == null) {
      throw AgentException('No active profile for game setting update',
          agentType: agentType, agentId: agentId);
    }

    final updatedSettings =
        Map<String, dynamic>.from(_currentProfile!.gameSettings);
    updatedSettings[key] = value;

    updateCurrentProfile(gameSettings: updatedSettings);
  }

  /// Get player game setting
  T? getPlayerGameSetting<T>(String key) {
    if (_currentProfile == null) return null;

    final value = _currentProfile!.gameSettings[key];
    return value is T ? value : null;
  }

  /// Register a game configuration
  void registerGameConfig(GameConfig config) {
    validateActive();

    _gameConfigs[config.id] = config;

    _emitConfigUpdate(ConfigUpdateType.gameConfigRegistered, {
      'gameId': config.id,
      'gameName': config.name,
    });
  }

  /// Get game configuration by ID
  GameConfig? getGameConfig(String gameId) {
    return _gameConfigs[gameId];
  }

  /// Update game configuration
  void updateGameConfig(String gameId, GameConfig config) {
    validateActive();

    if (!_gameConfigs.containsKey(gameId)) {
      throw AgentException('Game configuration not found: $gameId',
          agentType: agentType, agentId: agentId);
    }

    _gameConfigs[gameId] = config;

    _emitConfigUpdate(ConfigUpdateType.gameConfigUpdated, {
      'gameId': gameId,
      'gameName': config.name,
    });
  }

  /// Set global setting
  void setGlobalSetting(String key, dynamic value) {
    validateActive();

    _globalSettings[key] = value;

    _emitConfigUpdate(ConfigUpdateType.globalSettingChanged, {
      'key': key,
      'value': value,
    });
  }

  /// Get global setting
  T? getGlobalSetting<T>(String key) {
    final value = _globalSettings[key];
    return value is T ? value : null;
  }

  /// Export all configurations as JSON
  String exportConfigurations() {
    final data = {
      'profiles':
          _profiles.map((id, profile) => MapEntry(id, profile.toJson())),
      'gameConfigs':
          _gameConfigs.map((id, config) => MapEntry(id, config.toJson())),
      'globalSettings': _globalSettings,
      'currentProfileId': _currentProfile?.id,
      'exportTime': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  /// Import configurations from JSON
  Future<bool> importConfigurations(String jsonData) async {
    validateActive();

    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Import profiles
      if (data['profiles'] is Map) {
        final profilesData = data['profiles'] as Map<String, dynamic>;
        for (final entry in profilesData.entries) {
          final profile =
              PlayerProfile.fromJson(entry.value as Map<String, dynamic>);
          _profiles[entry.key] = profile;
        }
      }

      // Import game configs
      if (data['gameConfigs'] is Map) {
        final configsData = data['gameConfigs'] as Map<String, dynamic>;
        for (final entry in configsData.entries) {
          final config =
              GameConfig.fromJson(entry.value as Map<String, dynamic>);
          _gameConfigs[entry.key] = config;
        }
      }

      // Import global settings
      if (data['globalSettings'] is Map) {
        _globalSettings.addAll(data['globalSettings'] as Map<String, dynamic>);
      }

      // Set current profile
      final currentProfileId = data['currentProfileId'] as String?;
      if (currentProfileId != null && _profiles.containsKey(currentProfileId)) {
        _currentProfile = _profiles[currentProfileId];
      }

      _emitConfigUpdate(ConfigUpdateType.configurationsImported, {
        'profileCount': _profiles.length,
        'gameConfigCount': _gameConfigs.length,
      });

      return true;
    } catch (error, stackTrace) {
      handleError(error, stackTrace);
      return false;
    }
  }

  Future<void> _loadDefaultConfigurations() async {
    // Set default global settings
    _globalSettings.addAll({
      'soundEnabled': true,
      'musicEnabled': true,
      'animationsEnabled': true,
      'autoSpinEnabled': false,
      'fastSpinEnabled': false,
      'language': 'en',
      'currency': 'USD',
    });

    // Register default game configurations
    registerGameConfig(GameConfig(
      id: 'slot_machine',
      name: 'Slot Machine',
      category: 'Slots',
      minBet: 1.0,
      maxBet: 100.0,
      paylines: 20,
      reels: 5,
      settings: {
        'autoSpinCount': 10,
        'turboMode': false,
        'soundEffects': true,
      },
    ));

    registerGameConfig(GameConfig(
      id: 'roulette',
      name: 'Roulette',
      category: 'Table Games',
      minBet: 1.0,
      maxBet: 500.0,
      settings: {
        'wheelType': 'european', // european or american
        'animationSpeed': 'normal',
        'showStatistics': true,
      },
    ));
  }

  void _emitConfigUpdate(ConfigUpdateType type, Map<String, dynamic> data) {
    if (!_configUpdateController.isClosed) {
      _configUpdateController.add(ConfigUpdate(
        type: type,
        data: data,
        timestamp: DateTime.now(),
        agentId: agentId,
      ));
    }
  }

  String _generateProfileId() {
    return 'profile_${DateTime.now().millisecondsSinceEpoch}_${hashCode.abs()}';
  }
}

/// Types of configuration updates
enum ConfigUpdateType {
  profileCreated,
  profileLoaded,
  profileUpdated,
  profileDeleted,
  statisticsUpdated,
  gameConfigRegistered,
  gameConfigUpdated,
  globalSettingChanged,
  configurationsImported,
}

/// Configuration update event
class ConfigUpdate {
  final ConfigUpdateType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String agentId;

  const ConfigUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.agentId,
  });

  @override
  String toString() {
    return 'ConfigUpdate(type: $type, timestamp: $timestamp)';
  }
}

/// Player profile data
class PlayerProfile {
  final String id;
  final String displayName;
  final String? email;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> gameSettings;
  final PlayerStatistics statistics;

  const PlayerProfile({
    required this.id,
    required this.displayName,
    this.email,
    required this.createdAt,
    required this.lastActiveAt,
    required this.preferences,
    required this.gameSettings,
    required this.statistics,
  });

  PlayerProfile copyWith({
    String? displayName,
    String? email,
    DateTime? lastActiveAt,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? gameSettings,
    PlayerStatistics? statistics,
  }) {
    return PlayerProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      preferences: preferences ?? Map.from(this.preferences),
      gameSettings: gameSettings ?? Map.from(this.gameSettings),
      statistics: statistics ?? this.statistics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'preferences': preferences,
      'gameSettings': gameSettings,
      'statistics': statistics.toJson(),
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      preferences: Map<String, dynamic>.from(json['preferences'] as Map),
      gameSettings: Map<String, dynamic>.from(json['gameSettings'] as Map),
      statistics:
          PlayerStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() {
    return 'PlayerProfile(id: $id, displayName: $displayName, email: $email)';
  }
}

/// Player statistics
class PlayerStatistics {
  final int totalGamesPlayed;
  final int totalWins;
  final int totalLosses;
  final double totalWinnings;
  final double totalBets;
  final Duration totalPlayTime;
  final double biggestWin;
  final int currentStreak;
  final int longestWinStreak;
  final int longestLossStreak;
  final Map<String, int> gameTypeStats;

  const PlayerStatistics({
    this.totalGamesPlayed = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalWinnings = 0.0,
    this.totalBets = 0.0,
    this.totalPlayTime = Duration.zero,
    this.biggestWin = 0.0,
    this.currentStreak = 0,
    this.longestWinStreak = 0,
    this.longestLossStreak = 0,
    this.gameTypeStats = const {},
  });

  double get winRate =>
      totalGamesPlayed == 0 ? 0.0 : totalWins / totalGamesPlayed;
  double get returnToPlayer => totalBets == 0 ? 0.0 : totalWinnings / totalBets;

  PlayerStatistics copyWith({
    int? totalGamesPlayed,
    int? totalWins,
    int? totalLosses,
    double? totalWinnings,
    double? totalBets,
    Duration? totalPlayTime,
    double? biggestWin,
    int? currentStreak,
    int? longestWinStreak,
    int? longestLossStreak,
    Map<String, int>? gameTypeStats,
  }) {
    return PlayerStatistics(
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      totalWinnings: totalWinnings ?? this.totalWinnings,
      totalBets: totalBets ?? this.totalBets,
      totalPlayTime: totalPlayTime ?? this.totalPlayTime,
      biggestWin: biggestWin ?? this.biggestWin,
      currentStreak: currentStreak ?? this.currentStreak,
      longestWinStreak: longestWinStreak ?? this.longestWinStreak,
      longestLossStreak: longestLossStreak ?? this.longestLossStreak,
      gameTypeStats: gameTypeStats ?? Map.from(this.gameTypeStats),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalGamesPlayed': totalGamesPlayed,
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'totalWinnings': totalWinnings,
      'totalBets': totalBets,
      'totalPlayTime': totalPlayTime.inMilliseconds,
      'biggestWin': biggestWin,
      'currentStreak': currentStreak,
      'longestWinStreak': longestWinStreak,
      'longestLossStreak': longestLossStreak,
      'gameTypeStats': gameTypeStats,
      'winRate': winRate,
      'returnToPlayer': returnToPlayer,
    };
  }

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) {
    return PlayerStatistics(
      totalGamesPlayed: json['totalGamesPlayed'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalLosses: json['totalLosses'] as int? ?? 0,
      totalWinnings: (json['totalWinnings'] as num?)?.toDouble() ?? 0.0,
      totalBets: (json['totalBets'] as num?)?.toDouble() ?? 0.0,
      totalPlayTime: Duration(milliseconds: json['totalPlayTime'] as int? ?? 0),
      biggestWin: (json['biggestWin'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestWinStreak: json['longestWinStreak'] as int? ?? 0,
      longestLossStreak: json['longestLossStreak'] as int? ?? 0,
      gameTypeStats: Map<String, int>.from(json['gameTypeStats'] as Map? ?? {}),
    );
  }

  @override
  String toString() {
    return 'PlayerStatistics(games: $totalGamesPlayed, wins: $totalWins, '
        'winRate: ${(winRate * 100).toStringAsFixed(1)}%, '
        'totalWinnings: $totalWinnings)';
  }
}

/// Game configuration
class GameConfig {
  final String id;
  final String name;
  final String category;
  final double minBet;
  final double maxBet;
  final int? paylines;
  final int? reels;
  final Map<String, dynamic> settings;

  const GameConfig({
    required this.id,
    required this.name,
    required this.category,
    required this.minBet,
    required this.maxBet,
    this.paylines,
    this.reels,
    this.settings = const {},
  });

  GameConfig copyWith({
    String? name,
    String? category,
    double? minBet,
    double? maxBet,
    int? paylines,
    int? reels,
    Map<String, dynamic>? settings,
  }) {
    return GameConfig(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      minBet: minBet ?? this.minBet,
      maxBet: maxBet ?? this.maxBet,
      paylines: paylines ?? this.paylines,
      reels: reels ?? this.reels,
      settings: settings ?? Map.from(this.settings),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'minBet': minBet,
      'maxBet': maxBet,
      'paylines': paylines,
      'reels': reels,
      'settings': settings,
    };
  }

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      minBet: (json['minBet'] as num).toDouble(),
      maxBet: (json['maxBet'] as num).toDouble(),
      paylines: json['paylines'] as int?,
      reels: json['reels'] as int?,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
    );
  }

  @override
  String toString() {
    return 'GameConfig(id: $id, name: $name, category: $category)';
  }
}
