import 'dart:async';
import 'dart:developer' as developer;

class PerformanceService {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _metrics = {};
  
  // Performance Tracking
  static void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }
  
  static Duration? endTimer(String operation) {
    final startTime = _startTimes.remove(operation);
    if (startTime == null) return null;
    
    final duration = DateTime.now().difference(startTime);
    _addMetric(operation, duration);
    
    if (AppConfig.enableDebugLogs) {
      developer.log('Performance: $operation took ${duration.inMilliseconds}ms');
    }
    
    return duration;
  }
  
  static void _addMetric(String operation, Duration duration) {
    _metrics[operation] ??= [];
    _metrics[operation]!.add(duration);
    
    // Keep only last 100 measurements
    if (_metrics[operation]!.length > 100) {
      _metrics[operation]!.removeAt(0);
    }
  }
  
  // Memory Monitoring
  static Future<void> logMemoryUsage() async {
    if (!AppConfig.enableDebugLogs) return;
    
    final info = await developer.Service.getInfo();
    developer.log('Memory Usage: ${info.serverUri}');
  }
  
  // Network Performance
  static Future<T> measureNetworkCall<T>(
    String operation,
    Future<T> Function() networkCall,
  ) async {
    startTimer('network_$operation');
    try {
      final result = await networkCall();
      endTimer('network_$operation');
      return result;
    } catch (e) {
      endTimer('network_$operation');
      developer.log('Network error in $operation: $e');
      rethrow;
    }
  }
  
  // Get Performance Report
  static Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final entry in _metrics.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;
      
      final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
      final avgMs = totalMs / durations.length;
      final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
      final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
      
      report[entry.key] = {
        'count': durations.length,
        'average_ms': avgMs.round(),
        'max_ms': maxMs,
        'min_ms': minMs,
        'total_ms': totalMs,
      };
    }
    
    return report;
  }
}
