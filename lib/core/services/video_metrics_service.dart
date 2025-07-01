import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoMetrics {
  final String videoId;
  final int playCount;
  final Duration totalPlayTime;
  final int errorCount;
  final Duration averageLoadTime;
  final DateTime lastPlayed;
  final double averageBitrate;
  final int bufferCount;
  final Duration totalBufferTime;

  VideoMetrics({
    required this.videoId,
    required this.playCount,
    required this.totalPlayTime,
    required this.errorCount,
    required this.averageLoadTime,
    required this.lastPlayed,
    required this.averageBitrate,
    required this.bufferCount,
    required this.totalBufferTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'play_count': playCount,
      'total_play_time': totalPlayTime.inSeconds,
      'error_count': errorCount,
      'average_load_time': averageLoadTime.inMilliseconds,
      'last_played': lastPlayed.toIso8601String(),
      'average_bitrate': averageBitrate,
      'buffer_count': bufferCount,
      'total_buffer_time': totalBufferTime.inMilliseconds,
    };
  }

  factory VideoMetrics.fromJson(Map<String, dynamic> json) {
    return VideoMetrics(
      videoId: json['video_id'] ?? '',
      playCount: json['play_count'] ?? 0,
      totalPlayTime: Duration(seconds: json['total_play_time'] ?? 0),
      errorCount: json['error_count'] ?? 0,
      averageLoadTime: Duration(milliseconds: json['average_load_time'] ?? 0),
      lastPlayed: DateTime.parse(
          json['last_played'] ?? DateTime.now().toIso8601String()),
      averageBitrate: json['average_bitrate']?.toDouble() ?? 0.0,
      bufferCount: json['buffer_count'] ?? 0,
      totalBufferTime: Duration(milliseconds: json['total_buffer_time'] ?? 0),
    );
  }

  VideoMetrics copyWith({
    String? videoId,
    int? playCount,
    Duration? totalPlayTime,
    int? errorCount,
    Duration? averageLoadTime,
    DateTime? lastPlayed,
    double? averageBitrate,
    int? bufferCount,
    Duration? totalBufferTime,
  }) {
    return VideoMetrics(
      videoId: videoId ?? this.videoId,
      playCount: playCount ?? this.playCount,
      totalPlayTime: totalPlayTime ?? this.totalPlayTime,
      errorCount: errorCount ?? this.errorCount,
      averageLoadTime: averageLoadTime ?? this.averageLoadTime,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      averageBitrate: averageBitrate ?? this.averageBitrate,
      bufferCount: bufferCount ?? this.bufferCount,
      totalBufferTime: totalBufferTime ?? this.totalBufferTime,
    );
  }
}

class VideoMetricsService extends ChangeNotifier {
  static final VideoMetricsService _instance = VideoMetricsService._internal();
  factory VideoMetricsService() => _instance;
  VideoMetricsService._internal();

  static const String _metricsKey = 'video_metrics';
  static const String _sessionKey = 'video_session_metrics';

  final Map<String, VideoMetrics> _metrics = {};
  final Map<String, Stopwatch> _loadTimers = {};
  final Map<String, Stopwatch> _playTimers = {};
  final Map<String, List<Duration>> _loadTimes = {};
  final Map<String, List<double>> _bitrates = {};

  // Métriques de session
  int _sessionPlayCount = 0;
  Duration _sessionPlayTime = Duration.zero;
  int _sessionErrorCount = 0;
  int _sessionBufferCount = 0;
  Duration _sessionBufferTime = Duration.zero;

  // Configuration
  bool _enableMetrics = true;
  bool _enablePersistence = true;
  Duration _flushInterval = const Duration(minutes: 5);

  Timer? _flushTimer;

  // Getters
  int get sessionPlayCount => _sessionPlayCount;
  Duration get sessionPlayTime => _sessionPlayTime;
  int get sessionErrorCount => _sessionErrorCount;

  // Setters
  set enableMetrics(bool value) => _enableMetrics = value;
  set enablePersistence(bool value) => _enablePersistence = value;
  set flushInterval(Duration value) {
    _flushInterval = value;
    _setupFlushTimer();
  }

  /// Initialise le service
  Future<void> initialize() async {
    if (_enablePersistence) {
      await _loadMetrics();
      _setupFlushTimer();
    }
  }

  /// Enregistre le début du chargement d'une vidéo
  void startLoadTimer(String videoId) {
    if (!_enableMetrics) return;

    _loadTimers[videoId] = Stopwatch()..start();
  }

  /// Enregistre la fin du chargement d'une vidéo
  void endLoadTimer(String videoId) {
    if (!_enableMetrics) return;

    final timer = _loadTimers.remove(videoId);
    if (timer != null) {
      final loadTime = timer.elapsed;
      _loadTimes[videoId] = [...(_loadTimes[videoId] ?? []), loadTime];

      _updateMetrics(
          videoId,
          (metrics) => metrics.copyWith(
                averageLoadTime: _calculateAverageLoadTime(videoId),
              ));
    }
  }

  /// Enregistre le début de la lecture
  void startPlayTimer(String videoId) {
    if (!_enableMetrics) return;

    _playTimers[videoId] = Stopwatch()..start();
    _sessionPlayCount++;

    _updateMetrics(
        videoId,
        (metrics) => metrics.copyWith(
              playCount: metrics.playCount + 1,
              lastPlayed: DateTime.now(),
            ));

    notifyListeners();
  }

  /// Enregistre la fin de la lecture
  void endPlayTimer(String videoId) {
    if (!_enableMetrics) return;

    final timer = _playTimers.remove(videoId);
    if (timer != null) {
      final playTime = timer.elapsed;
      _sessionPlayTime += playTime;

      _updateMetrics(
          videoId,
          (metrics) => metrics.copyWith(
                totalPlayTime: metrics.totalPlayTime + playTime,
              ));

      notifyListeners();
    }
  }

  /// Enregistre une erreur
  void recordError(String videoId, String error) {
    if (!_enableMetrics) return;

    _sessionErrorCount++;

    _updateMetrics(
        videoId,
        (metrics) => metrics.copyWith(
              errorCount: metrics.errorCount + 1,
            ));

    debugPrint('Erreur vidéo $videoId: $error');
    notifyListeners();
  }

  /// Enregistre un événement de buffering
  void recordBuffering(String videoId, Duration bufferTime) {
    if (!_enableMetrics) return;

    _sessionBufferCount++;
    _sessionBufferTime += bufferTime;

    _updateMetrics(
        videoId,
        (metrics) => metrics.copyWith(
              bufferCount: metrics.bufferCount + 1,
              totalBufferTime: metrics.totalBufferTime + bufferTime,
            ));

    notifyListeners();
  }

  /// Enregistre le bitrate
  void recordBitrate(String videoId, double bitrate) {
    if (!_enableMetrics) return;

    _bitrates[videoId] = [...(_bitrates[videoId] ?? []), bitrate];

    _updateMetrics(
        videoId,
        (metrics) => metrics.copyWith(
              averageBitrate: _calculateAverageBitrate(videoId),
            ));
  }

  /// Obtient les métriques d'une vidéo
  VideoMetrics? getMetrics(String videoId) {
    return _metrics[videoId];
  }

  /// Obtient toutes les métriques
  Map<String, VideoMetrics> getAllMetrics() {
    return Map.unmodifiable(_metrics);
  }

  /// Obtient les métriques de session
  Map<String, dynamic> getSessionMetrics() {
    return {
      'play_count': _sessionPlayCount,
      'play_time': _sessionPlayTime.inSeconds,
      'error_count': _sessionErrorCount,
      'buffer_count': _sessionBufferCount,
      'buffer_time': _sessionBufferTime.inMilliseconds,
      'session_duration':
          DateTime.now().difference(_sessionStartTime).inMinutes,
    };
  }

  /// Obtient les statistiques globales
  Map<String, dynamic> getGlobalStats() {
    if (_metrics.isEmpty) {
      return {
        'total_videos': 0,
        'total_play_time': 0,
        'total_play_count': 0,
        'total_errors': 0,
        'average_load_time': 0,
        'most_played_videos': [],
        'error_prone_videos': [],
      };
    }

    final totalPlayTime =
        _metrics.values.map((m) => m.totalPlayTime).reduce((a, b) => a + b);

    final totalPlayCount =
        _metrics.values.map((m) => m.playCount).reduce((a, b) => a + b);

    final totalErrors =
        _metrics.values.map((m) => m.errorCount).reduce((a, b) => a + b);

    final averageLoadTime =
        _metrics.values.map((m) => m.averageLoadTime).reduce((a, b) => a + b) ~/
            _metrics.length;

    final mostPlayedList = _metrics.entries.toList();
    mostPlayedList.sort((a, b) => b.value.playCount.compareTo(a.value.playCount));
    final mostPlayed = mostPlayedList.take(10).map((e) => {
      'video_id': e.key,
      'play_count': e.value.playCount,
      'total_time': e.value.totalPlayTime.inSeconds,
    }).toList();

    final errorProneList = _metrics.entries.where((e) => e.value.errorCount > 0).toList();
    errorProneList.sort((a, b) => b.value.errorCount.compareTo(a.value.errorCount));
    final errorProne = errorProneList.take(10).map((e) => {
      'video_id': e.key,
      'error_count': e.value.errorCount,
      'play_count': e.value.playCount,
    }).toList();

    return {
      'total_videos': _metrics.length,
      'total_play_time': totalPlayTime.inSeconds,
      'total_play_count': totalPlayCount,
      'total_errors': totalErrors,
      'average_load_time': averageLoadTime.inMilliseconds,
      'most_played_videos': mostPlayed,
      'error_prone_videos': errorProne,
      'session_metrics': getSessionMetrics(),
    };
  }

  /// Réinitialise les métriques de session
  void resetSession() {
    _sessionPlayCount = 0;
    _sessionPlayTime = Duration.zero;
    _sessionErrorCount = 0;
    _sessionBufferCount = 0;
    _sessionBufferTime = Duration.zero;
    _sessionStartTime = DateTime.now();

    notifyListeners();
  }

  /// Efface toutes les métriques
  Future<void> clearAllMetrics() async {
    _metrics.clear();
    _loadTimes.clear();
    _bitrates.clear();
    resetSession();

    if (_enablePersistence) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_metricsKey);
      await prefs.remove(_sessionKey);
    }

    notifyListeners();
  }

  /// Sauvegarde les métriques
  Future<void> saveMetrics() async {
    if (!_enablePersistence) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final metricsJson =
          _metrics.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_metricsKey, json.encode(metricsJson));

      final sessionJson = getSessionMetrics();
      await prefs.setString(_sessionKey, json.encode(sessionJson));

      debugPrint('Métriques vidéo sauvegardées');
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde des métriques: $e');
    }
  }

  /// Charge les métriques
  Future<void> _loadMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final metricsString = prefs.getString(_metricsKey);
      if (metricsString != null) {
        final metricsJson = json.decode(metricsString) as Map<String, dynamic>;
        _metrics.clear();

        for (final entry in metricsJson.entries) {
          _metrics[entry.key] =
              VideoMetrics.fromJson(entry.value as Map<String, dynamic>);
        }
      }

      final sessionString = prefs.getString(_sessionKey);
      if (sessionString != null) {
        final sessionJson = json.decode(sessionString) as Map<String, dynamic>;
        _sessionPlayCount = sessionJson['play_count'] ?? 0;
        _sessionPlayTime = Duration(seconds: sessionJson['play_time'] ?? 0);
        _sessionErrorCount = sessionJson['error_count'] ?? 0;
        _sessionBufferCount = sessionJson['buffer_count'] ?? 0;
        _sessionBufferTime =
            Duration(milliseconds: sessionJson['buffer_time'] ?? 0);
      }

      debugPrint('Métriques vidéo chargées: [32m${_metrics.length} vidéos[0m');
    } catch (e) {
      debugPrint('Erreur lors du chargement des métriques: $e');
    }
  }

  // Méthodes privées

  late DateTime _sessionStartTime = DateTime.now();

  void _updateMetrics(
      String videoId, VideoMetrics Function(VideoMetrics) updater) {
    final current = _metrics[videoId] ??
        VideoMetrics(
          videoId: videoId,
          playCount: 0,
          totalPlayTime: Duration.zero,
          errorCount: 0,
          averageLoadTime: Duration.zero,
          lastPlayed: DateTime.now(),
          averageBitrate: 0.0,
          bufferCount: 0,
          totalBufferTime: Duration.zero,
        );

    _metrics[videoId] = updater(current);
  }

  Duration _calculateAverageLoadTime(String videoId) {
    final times = _loadTimes[videoId];
    if (times == null || times.isEmpty) return Duration.zero;

    final total = times.reduce((a, b) => a + b);
    return total ~/ times.length;
  }

  double _calculateAverageBitrate(String videoId) {
    final rates = _bitrates[videoId];
    if (rates == null || rates.isEmpty) return 0.0;

    final total = rates.reduce((a, b) => a + b);
    return total / rates.length;
  }

  void _setupFlushTimer() {
    _flushTimer?.cancel();
    if (_enablePersistence) {
      _flushTimer = Timer.periodic(_flushInterval, (_) => saveMetrics());
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    saveMetrics();
    super.dispose();
  }
}
