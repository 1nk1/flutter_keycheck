import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'base_agent.dart';

/// Agent responsible for generating reports and statistics analysis
class ReportGeneratorAgent extends BaseAgentImpl {
  static const String _agentTypeId = 'ReportGenerator';
  
  // Report storage
  final Map<String, GeneratedReport> _reports = {};
  final Map<String, ReportTemplate> _templates = {};
  
  // Statistics aggregation
  final List<GameSession> _sessionHistory = [];
  final Map<String, List<double>> _gamePerformanceData = {};
  
  // Stream controllers
  final StreamController<ReportUpdate> _reportUpdateController = 
      StreamController<ReportUpdate>.broadcast();

  @override
  String get agentType => _agentTypeId;

  /// Stream of report updates
  Stream<ReportUpdate> get reportUpdates => _reportUpdateController.stream;

  /// All generated reports
  List<GeneratedReport> get allReports => List.unmodifiable(_reports.values);

  /// Available report templates
  List<ReportTemplate> get availableTemplates => List.unmodifiable(_templates.values);

  @override
  Future<void> onInitialize() async {
    await _loadDefaultTemplates();
  }

  @override
  Future<void> onDispose() async {
    await _reportUpdateController.close();
  }

  /// Add game session data for analysis
  void addGameSession(GameSession session) {
    validateActive();
    
    _sessionHistory.add(session);
    
    // Update performance data
    final gameType = session.gameType;
    if (!_gamePerformanceData.containsKey(gameType)) {
      _gamePerformanceData[gameType] = [];
    }
    _gamePerformanceData[gameType]!.add(session.netResult);
    
    _emitReportUpdate(ReportUpdateType.sessionDataAdded, {
      'sessionId': session.sessionId,
      'gameType': session.gameType,
      'netResult': session.netResult,
    });
  }

  /// Generate report using a template
  Future<String> generateReport(String templateId, {
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? parameters,
  }) async {
    validateActive();
    
    final template = _templates[templateId];
    if (template == null) {
      throw AgentException('Report template not found: $templateId', 
          agentType: agentType, agentId: agentId);
    }
    
    final reportId = _generateReportId();
    final filteredSessions = _filterSessions(startDate, endDate);
    
    GeneratedReport report;
    
    try {
      switch (template.type) {
        case ReportType.sessionSummary:
          report = await _generateSessionSummaryReport(
            reportId, template, filteredSessions, parameters);
          break;
        case ReportType.gamePerformance:
          report = await _generateGamePerformanceReport(
            reportId, template, filteredSessions, parameters);
          break;
        case ReportType.financialSummary:
          report = await _generateFinancialSummaryReport(
            reportId, template, filteredSessions, parameters);
          break;
        case ReportType.playerBehavior:
          report = await _generatePlayerBehaviorReport(
            reportId, template, filteredSessions, parameters);
          break;
        case ReportType.custom:
          report = await _generateCustomReport(
            reportId, template, filteredSessions, parameters);
          break;
      }
      
      _reports[reportId] = report;
      
      _emitReportUpdate(ReportUpdateType.reportGenerated, {
        'reportId': reportId,
        'templateId': templateId,
        'reportType': template.type.name,
      });
      
      return reportId;
    } catch (error, stackTrace) {
      handleError(error, stackTrace);
      rethrow;
    }
  }

  /// Get generated report by ID
  GeneratedReport? getReport(String reportId) {
    return _reports[reportId];
  }

  /// Delete a report
  bool deleteReport(String reportId) {
    validateActive();
    
    final existed = _reports.remove(reportId) != null;
    
    if (existed) {
      _emitReportUpdate(ReportUpdateType.reportDeleted, {
        'reportId': reportId,
      });
    }
    
    return existed;
  }

  /// Create custom report template
  void createReportTemplate(ReportTemplate template) {
    validateActive();
    
    _templates[template.id] = template;
    
    _emitReportUpdate(ReportUpdateType.templateCreated, {
      'templateId': template.id,
      'templateName': template.name,
      'templateType': template.type.name,
    });
  }

  /// Get real-time statistics
  Map<String, dynamic> getRealTimeStatistics() {
    if (_sessionHistory.isEmpty) {
      return {
        'totalSessions': 0,
        'totalGamesPlayed': 0,
        'totalWinnings': 0.0,
        'totalBets': 0.0,
        'overallRTP': 0.0,
        'averageSessionDuration': 0,
        'gameTypeStats': <String, dynamic>{},
      };
    }
    
    final totalSessions = _sessionHistory.length;
    final totalGamesPlayed = _sessionHistory.fold<int>(0, (sum, session) => sum + session.gamesPlayed);
    final totalWinnings = _sessionHistory.fold<double>(0, (sum, session) => sum + session.totalWinnings);
    final totalBets = _sessionHistory.fold<double>(0, (sum, session) => sum + session.totalBets);
    final averageSessionDuration = _sessionHistory.fold<int>(0, (sum, session) => sum + session.duration.inMinutes) / totalSessions;
    
    final overallRTP = totalBets == 0 ? 0.0 : totalWinnings / totalBets;
    
    final gameTypeStats = <String, dynamic>{};
    for (final gameType in _gamePerformanceData.keys) {
      final gameResults = _gamePerformanceData[gameType]!;
      final gameSessions = _sessionHistory.where((s) => s.gameType == gameType).toList();
      
      gameTypeStats[gameType] = {
        'sessions': gameSessions.length,
        'averageResult': gameResults.isEmpty ? 0.0 : gameResults.reduce((a, b) => a + b) / gameResults.length,
        'bestResult': gameResults.isEmpty ? 0.0 : gameResults.reduce(math.max),
        'worstResult': gameResults.isEmpty ? 0.0 : gameResults.reduce(math.min),
        'volatility': _calculateVolatility(gameResults),
      };
    }
    
    return {
      'totalSessions': totalSessions,
      'totalGamesPlayed': totalGamesPlayed,
      'totalWinnings': totalWinnings,
      'totalBets': totalBets,
      'overallRTP': overallRTP,
      'averageSessionDuration': averageSessionDuration,
      'gameTypeStats': gameTypeStats,
    };
  }

  /// Export report as JSON
  String exportReportAsJson(String reportId) {
    final report = _reports[reportId];
    if (report == null) {
      throw AgentException('Report not found: $reportId', 
          agentType: agentType, agentId: agentId);
    }
    
    return jsonEncode(report.toJson());
  }

  /// Export report as CSV
  String exportReportAsCsv(String reportId) {
    final report = _reports[reportId];
    if (report == null) {
      throw AgentException('Report not found: $reportId', 
          agentType: agentType, agentId: agentId);
    }
    
    final csv = StringBuffer();
    
    // Add header
    csv.writeln('Report: ${report.title}');
    csv.writeln('Generated: ${report.generatedAt.toIso8601String()}');
    csv.writeln('Period: ${report.startDate?.toIso8601String() ?? 'N/A'} - ${report.endDate?.toIso8601String() ?? 'N/A'}');
    csv.writeln('');
    
    // Add data sections
    for (final section in report.sections) {
      csv.writeln('Section: ${section.title}');
      
      if (section.data is Map<String, dynamic>) {
        final data = section.data as Map<String, dynamic>;
        for (final entry in data.entries) {
          csv.writeln('${entry.key},${entry.value}');
        }
      } else if (section.data is List) {
        final data = section.data as List;
        for (final item in data) {
          csv.writeln(item.toString());
        }
      }
      
      csv.writeln('');
    }
    
    return csv.toString();
  }

  Future<GeneratedReport> _generateSessionSummaryReport(
    String reportId,
    ReportTemplate template,
    List<GameSession> sessions,
    Map<String, dynamic>? parameters,
  ) async {
    final sections = <ReportSection>[];
    
    // Overview section
    sections.add(ReportSection(
      title: 'Session Overview',
      data: {
        'Total Sessions': sessions.length,
        'Total Games Played': sessions.fold<int>(0, (sum, s) => sum + s.gamesPlayed),
        'Average Session Duration (minutes)': sessions.isEmpty ? 0 : 
            sessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes) / sessions.length,
        'Total Play Time (hours)': sessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes) / 60.0,
      },
    ));
    
    // Game type breakdown
    final gameTypeBreakdown = <String, dynamic>{};
    for (final session in sessions) {
      if (!gameTypeBreakdown.containsKey(session.gameType)) {
        gameTypeBreakdown[session.gameType] = {
          'sessions': 0,
          'totalGames': 0,
          'totalWinnings': 0.0,
          'totalBets': 0.0,
        };
      }
      
      gameTypeBreakdown[session.gameType]!['sessions'] += 1;
      gameTypeBreakdown[session.gameType]!['totalGames'] += session.gamesPlayed;
      gameTypeBreakdown[session.gameType]!['totalWinnings'] += session.totalWinnings;
      gameTypeBreakdown[session.gameType]!['totalBets'] += session.totalBets;
    }
    
    sections.add(ReportSection(
      title: 'Game Type Breakdown',
      data: gameTypeBreakdown,
    ));
    
    return GeneratedReport(
      id: reportId,
      templateId: template.id,
      title: template.name,
      type: template.type,
      generatedAt: DateTime.now(),
      startDate: sessions.isEmpty ? null : sessions.first.startTime,
      endDate: sessions.isEmpty ? null : sessions.last.endTime,
      sections: sections,
    );
  }

  Future<GeneratedReport> _generateGamePerformanceReport(
    String reportId,
    ReportTemplate template,
    List<GameSession> sessions,
    Map<String, dynamic>? parameters,
  ) async {
    final sections = <ReportSection>[];
    
    // Performance metrics by game type
    final performanceByGame = <String, dynamic>{};
    
    for (final gameType in _gamePerformanceData.keys) {
      final gameResults = _gamePerformanceData[gameType]!;
      final gameSessions = sessions.where((s) => s.gameType == gameType).toList();
      
      if (gameResults.isNotEmpty && gameSessions.isNotEmpty) {
        final winSessions = gameSessions.where((s) => s.netResult > 0).length;
        final lossSessions = gameSessions.where((s) => s.netResult < 0).length;
        
        performanceByGame[gameType] = {
          'Total Sessions': gameSessions.length,
          'Win Sessions': winSessions,
          'Loss Sessions': lossSessions,
          'Win Rate': gameSessions.isEmpty ? 0.0 : winSessions / gameSessions.length * 100,
          'Average Result': gameResults.reduce((a, b) => a + b) / gameResults.length,
          'Best Result': gameResults.reduce(math.max),
          'Worst Result': gameResults.reduce(math.min),
          'Volatility': _calculateVolatility(gameResults),
          'Total RTP': _calculateRTP(gameSessions),
        };
      }
    }
    
    sections.add(ReportSection(
      title: 'Game Performance Analysis',
      data: performanceByGame,
    ));
    
    // Trending analysis
    if (sessions.length >= 5) {
      final recentSessions = sessions.take(sessions.length ~/ 2).toList();
      final olderSessions = sessions.skip(sessions.length ~/ 2).toList();
      
      final recentAvg = recentSessions.isEmpty ? 0.0 : 
          recentSessions.fold<double>(0, (sum, s) => sum + s.netResult) / recentSessions.length;
      final olderAvg = olderSessions.isEmpty ? 0.0 :
          olderSessions.fold<double>(0, (sum, s) => sum + s.netResult) / olderSessions.length;
      
      sections.add(ReportSection(
        title: 'Performance Trends',
        data: {
          'Recent Average Result': recentAvg,
          'Historical Average Result': olderAvg,
          'Trend Direction': recentAvg > olderAvg ? 'Improving' : 'Declining',
          'Trend Magnitude': (recentAvg - olderAvg).abs(),
        },
      ));
    }
    
    return GeneratedReport(
      id: reportId,
      templateId: template.id,
      title: template.name,
      type: template.type,
      generatedAt: DateTime.now(),
      startDate: sessions.isEmpty ? null : sessions.first.startTime,
      endDate: sessions.isEmpty ? null : sessions.last.endTime,
      sections: sections,
    );
  }

  Future<GeneratedReport> _generateFinancialSummaryReport(
    String reportId,
    ReportTemplate template,
    List<GameSession> sessions,
    Map<String, dynamic>? parameters,
  ) async {
    final sections = <ReportSection>[];
    
    final totalWinnings = sessions.fold<double>(0, (sum, s) => sum + s.totalWinnings);
    final totalBets = sessions.fold<double>(0, (sum, s) => sum + s.totalBets);
    final netResult = sessions.fold<double>(0, (sum, s) => sum + s.netResult);
    
    // Financial overview
    sections.add(ReportSection(
      title: 'Financial Overview',
      data: {
        'Total Winnings': totalWinnings,
        'Total Bets': totalBets,
        'Net Result': netResult,
        'Overall RTP': totalBets == 0 ? 0.0 : (totalWinnings / totalBets) * 100,
        'Average Bet Size': sessions.isEmpty ? 0.0 : totalBets / sessions.fold<int>(0, (sum, s) => sum + s.gamesPlayed),
        'Largest Win': sessions.isEmpty ? 0.0 : sessions.map((s) => s.largestWin).reduce(math.max),
        'Largest Loss': sessions.isEmpty ? 0.0 : sessions.map((s) => s.largestLoss).reduce(math.max),
      },
    ));
    
    // Monthly breakdown (if data spans multiple months)
    if (sessions.isNotEmpty) {
      final monthlyData = <String, Map<String, dynamic>>{};
      
      for (final session in sessions) {
        final monthKey = '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}';
        
        if (!monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = {
            'sessions': 0,
            'winnings': 0.0,
            'bets': 0.0,
            'netResult': 0.0,
          };
        }
        
        monthlyData[monthKey]!['sessions'] += 1;
        monthlyData[monthKey]!['winnings'] += session.totalWinnings;
        monthlyData[monthKey]!['bets'] += session.totalBets;
        monthlyData[monthKey]!['netResult'] += session.netResult;
      }
      
      sections.add(ReportSection(
        title: 'Monthly Breakdown',
        data: monthlyData,
      ));
    }
    
    return GeneratedReport(
      id: reportId,
      templateId: template.id,
      title: template.name,
      type: template.type,
      generatedAt: DateTime.now(),
      startDate: sessions.isEmpty ? null : sessions.first.startTime,
      endDate: sessions.isEmpty ? null : sessions.last.endTime,
      sections: sections,
    );
  }

  Future<GeneratedReport> _generatePlayerBehaviorReport(
    String reportId,
    ReportTemplate template,
    List<GameSession> sessions,
    Map<String, dynamic>? parameters,
  ) async {
    final sections = <ReportSection>[];
    
    if (sessions.isNotEmpty) {
      // Playing patterns
      final hourlyActivity = <int, int>{};
      final dailyActivity = <int, int>{};
      
      for (final session in sessions) {
        final hour = session.startTime.hour;
        final weekday = session.startTime.weekday;
        
        hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;
        dailyActivity[weekday] = (dailyActivity[weekday] ?? 0) + 1;
      }
      
      sections.add(ReportSection(
        title: 'Playing Patterns',
        data: {
          'Most Active Hour': hourlyActivity.entries.reduce((a, b) => a.value > b.value ? a : b).key,
          'Most Active Day': _getDayName(dailyActivity.entries.reduce((a, b) => a.value > b.value ? a : b).key),
          'Hourly Activity': hourlyActivity,
          'Daily Activity': dailyActivity.map((k, v) => MapEntry(_getDayName(k), v)),
        },
      ));
      
      // Session behavior
      final sessionDurations = sessions.map((s) => s.duration.inMinutes).toList();
      final averageSessionLength = sessionDurations.reduce((a, b) => a + b) / sessionDurations.length;
      
      sections.add(ReportSection(
        title: 'Session Behavior',
        data: {
          'Average Session Length (minutes)': averageSessionLength,
          'Shortest Session (minutes)': sessionDurations.reduce(math.min),
          'Longest Session (minutes)': sessionDurations.reduce(math.max),
          'Session Length Variance': _calculateVariance(sessionDurations.map((d) => d.toDouble()).toList()),
        },
      ));
    }
    
    return GeneratedReport(
      id: reportId,
      templateId: template.id,
      title: template.name,
      type: template.type,
      generatedAt: DateTime.now(),
      startDate: sessions.isEmpty ? null : sessions.first.startTime,
      endDate: sessions.isEmpty ? null : sessions.last.endTime,
      sections: sections,
    );
  }

  Future<GeneratedReport> _generateCustomReport(
    String reportId,
    ReportTemplate template,
    List<GameSession> sessions,
    Map<String, dynamic>? parameters,
  ) async {
    // Custom report logic would be implemented based on template configuration
    return GeneratedReport(
      id: reportId,
      templateId: template.id,
      title: template.name,
      type: template.type,
      generatedAt: DateTime.now(),
      startDate: sessions.isEmpty ? null : sessions.first.startTime,
      endDate: sessions.isEmpty ? null : sessions.last.endTime,
      sections: [
        ReportSection(
          title: 'Custom Analysis',
          data: {'message': 'Custom report implementation required'},
        ),
      ],
    );
  }

  List<GameSession> _filterSessions(DateTime? startDate, DateTime? endDate) {
    return _sessionHistory.where((session) {
      if (startDate != null && session.startTime.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && session.endTime.isAfter(endDate)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadDefaultTemplates() async {
    final templates = [
      ReportTemplate(
        id: 'session_summary',
        name: 'Session Summary Report',
        description: 'Overview of gaming sessions and basic statistics',
        type: ReportType.sessionSummary,
        parameters: {},
      ),
      ReportTemplate(
        id: 'game_performance',
        name: 'Game Performance Analysis',
        description: 'Detailed analysis of game performance and trends',
        type: ReportType.gamePerformance,
        parameters: {},
      ),
      ReportTemplate(
        id: 'financial_summary',
        name: 'Financial Summary Report',
        description: 'Financial overview including winnings, losses, and RTP',
        type: ReportType.financialSummary,
        parameters: {},
      ),
      ReportTemplate(
        id: 'player_behavior',
        name: 'Player Behavior Analysis',
        description: 'Analysis of playing patterns and session behavior',
        type: ReportType.playerBehavior,
        parameters: {},
      ),
    ];
    
    for (final template in templates) {
      _templates[template.id] = template;
    }
  }

  double _calculateVolatility(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }

  double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
  }

  double _calculateRTP(List<GameSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    
    final totalWinnings = sessions.fold<double>(0, (sum, s) => sum + s.totalWinnings);
    final totalBets = sessions.fold<double>(0, (sum, s) => sum + s.totalBets);
    
    return totalBets == 0 ? 0.0 : (totalWinnings / totalBets) * 100;
  }

  String _getDayName(int weekday) {
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayNames[weekday - 1];
  }

  void _emitReportUpdate(ReportUpdateType type, Map<String, dynamic> data) {
    if (!_reportUpdateController.isClosed) {
      _reportUpdateController.add(ReportUpdate(
        type: type,
        data: data,
        timestamp: DateTime.now(),
        agentId: agentId,
      ));
    }
  }

  String _generateReportId() {
    return 'report_${DateTime.now().millisecondsSinceEpoch}_${hashCode.abs()}';
  }
}

/// Types of reports
enum ReportType {
  sessionSummary,
  gamePerformance,
  financialSummary,
  playerBehavior,
  custom,
}

/// Types of report updates
enum ReportUpdateType {
  sessionDataAdded,
  reportGenerated,
  reportDeleted,
  templateCreated,
}

/// Report update event
class ReportUpdate {
  final ReportUpdateType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String agentId;

  const ReportUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.agentId,
  });

  @override
  String toString() {
    return 'ReportUpdate(type: $type, timestamp: $timestamp)';
  }
}

/// Game session data for reporting
class GameSession {
  final String sessionId;
  final String gameType;
  final DateTime startTime;
  final DateTime endTime;
  final int gamesPlayed;
  final double totalBets;
  final double totalWinnings;
  final double netResult;
  final double largestWin;
  final double largestLoss;

  const GameSession({
    required this.sessionId,
    required this.gameType,
    required this.startTime,
    required this.endTime,
    required this.gamesPlayed,
    required this.totalBets,
    required this.totalWinnings,
    required this.netResult,
    required this.largestWin,
    required this.largestLoss,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'gameType': gameType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'gamesPlayed': gamesPlayed,
      'totalBets': totalBets,
      'totalWinnings': totalWinnings,
      'netResult': netResult,
      'largestWin': largestWin,
      'largestLoss': largestLoss,
      'duration': duration.inMinutes,
    };
  }

  @override
  String toString() {
    return 'GameSession(id: $sessionId, game: $gameType, net: $netResult)';
  }
}

/// Report template
class ReportTemplate {
  final String id;
  final String name;
  final String description;
  final ReportType type;
  final Map<String, dynamic> parameters;

  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'parameters': parameters,
    };
  }

  @override
  String toString() {
    return 'ReportTemplate(id: $id, name: $name, type: $type)';
  }
}

/// Generated report
class GeneratedReport {
  final String id;
  final String templateId;
  final String title;
  final ReportType type;
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ReportSection> sections;

  const GeneratedReport({
    required this.id,
    required this.templateId,
    required this.title,
    required this.type,
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.sections,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'title': title,
      'type': type.name,
      'generatedAt': generatedAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'GeneratedReport(id: $id, title: $title, sections: ${sections.length})';
  }
}

/// Report section
class ReportSection {
  final String title;
  final dynamic data;

  const ReportSection({
    required this.title,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'ReportSection(title: $title)';
  }
}