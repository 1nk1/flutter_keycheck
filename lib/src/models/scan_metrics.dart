/// Metrics collected during AST scanning
class ScanMetrics {
  int filesTotal = 0;
  int filesScanned = 0;
  int parseErrors = 0;
  int widgetsTotal = 0;
  int widgetsWithKeys = 0;
  int handlersTotal = 0;
  int handlersLinked = 0;
  int nodesTotal = 0;
  int nodesWithKeys = 0;
  
  double get parseSuccessRate {
    if (filesTotal == 0) return 0.0;
    return filesScanned / filesTotal;
  }
  
  double get widgetCoverage {
    if (widgetsTotal == 0) return 0.0;
    return widgetsWithKeys / widgetsTotal;
  }
  
  double get handlerLinkage {
    if (handlersTotal == 0) return 0.0;
    return handlersLinked / handlersTotal;
  }
  
  Map<String, dynamic> toJson() => {
    'files_total': filesTotal,
    'files_scanned': filesScanned,
    'parse_success_rate': parseSuccessRate,
    'widgets_total': widgetsTotal,
    'widgets_with_keys': widgetsWithKeys,
    'handlers_total': handlersTotal,
    'handlers_linked': handlersLinked,
  };
}