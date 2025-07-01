import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

enum VideoState {
  uninitialized,
  loading,
  ready,
  playing,
  paused,
  buffering,
  error,
  disposed,
}

enum VideoQuality {
  low,
  medium,
  high,
  auto,
}

class VideoInfo {
  final String id;
  final String url;
  final String? title;
  final Duration? duration;
  final VideoQuality quality;
  final DateTime lastAccessed;
  final int accessCount;
  final VideoState state;
  final String? errorMessage;
  final Duration? currentPosition;
  final bool isMuted;
  final double volume;

  VideoInfo({
    required this.id,
    required this.url,
    this.title,
    this.duration,
    this.quality = VideoQuality.auto,
    required this.lastAccessed,
    this.accessCount = 0,
    this.state = VideoState.uninitialized,
    this.errorMessage,
    this.currentPosition,
    this.isMuted = false,
    this.volume = 1.0,
  });

  VideoInfo copyWith({
    String? id,
    String? url,
    String? title,
    Duration? duration,
    VideoQuality? quality,
    DateTime? lastAccessed,
    int? accessCount,
    VideoState? state,
    String? errorMessage,
    Duration? currentPosition,
    bool? isMuted,
    double? volume,
  }) {
    return VideoInfo(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPosition: currentPosition ?? this.currentPosition,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
    );
  }
}

class VideoStateManager extends ChangeNotifier {
  static final VideoStateManager _instance = VideoStateManager._internal();
  factory VideoStateManager() => _instance;
  VideoStateManager._internal();

  // Cache des contrôleurs vidéo
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, VideoInfo> _videoInfo = {};
  final Map<String, StreamSubscription> _listeners = {};

  // Gestion de la mémoire
  final int _maxCachedVideos = 10;
  final Duration _cacheExpiration = const Duration(minutes: 30);

  // Métriques
  final Map<String, int> _playCount = {};
  final Map<String, Duration> _totalPlayTime = {};
  final Map<String, int> _errorCount = {};

  // État global
  String? _activeVideoId;
  bool _isGlobalPaused = false;
  bool _isMuted = false;
  double _globalVolume = 1.0;

  // Getters
  String? get activeVideoId => _activeVideoId;
  bool get isGlobalPaused => _isGlobalPaused;
  bool get isMuted => _isMuted;
  double get globalVolume => _globalVolume;
  int get cachedVideosCount => _controllers.length;

  // Événements
  final StreamController<String> _videoStateChangedController =
      StreamController<String>.broadcast();
  Stream<String> get videoStateChanged => _videoStateChangedController.stream;

  /// Initialise un contrôleur vidéo
  Future<VideoPlayerController?> initializeVideo({
    required String videoId,
    required String videoUrl,
    String? title,
    VideoQuality quality = VideoQuality.auto,
    bool preload = false,
  }) async {
    try {
      // Vérifier si déjà initialisé
      if (_controllers.containsKey(videoId)) {
        _updateVideoInfo(
            videoId,
            (info) => info.copyWith(
                  lastAccessed: DateTime.now(),
                  accessCount: info.accessCount + 1,
                ));
        return _controllers[videoId];
      }

      // Nettoyer le cache si nécessaire
      _cleanupCache();

      // Créer le contrôleur
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // Mettre à jour les infos
      _videoInfo[videoId] = VideoInfo(
        id: videoId,
        url: videoUrl,
        title: title,
        quality: quality,
        lastAccessed: DateTime.now(),
        accessCount: 1,
        state: VideoState.loading,
      );

      // Initialiser le contrôleur
      await controller.initialize();

      // Configurer le contrôleur
      await controller.setLooping(true);
      await controller.setVolume(_globalVolume);
      if (_isMuted) await controller.setVolume(0.0);

      // Ajouter le listener
      _listeners[videoId] = controller.addListener(() {
        _onVideoStateChanged(videoId, controller);
      });

      // Stocker le contrôleur
      _controllers[videoId] = controller;

      // Mettre à jour l'état
      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                state: VideoState.ready,
                duration: controller.value.duration,
              ));

      _videoStateChangedController.add(videoId);
      notifyListeners();

      return controller;
    } catch (e) {
      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                state: VideoState.error,
                errorMessage: e.toString(),
              ));

      _errorCount[videoId] = (_errorCount[videoId] ?? 0) + 1;
      _videoStateChangedController.add(videoId);
      notifyListeners();

      print('Erreur d\'initialisation vidéo $videoId: $e');
      return null;
    }
  }

  /// Joue une vidéo
  Future<void> playVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null) return;

    try {
      // Mettre en pause les autres vidéos
      _pauseOtherVideos(videoId);

      // Jouer la vidéo
      await controller.play();

      _activeVideoId = videoId;
      _isGlobalPaused = false;

      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                state: VideoState.playing,
                lastAccessed: DateTime.now(),
              ));

      _playCount[videoId] = (_playCount[videoId] ?? 0) + 1;

      _videoStateChangedController.add(videoId);
      notifyListeners();
    } catch (e) {
      print('Erreur de lecture vidéo $videoId: $e');
    }
  }

  /// Met en pause une vidéo
  Future<void> pauseVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null) return;

    try {
      await controller.pause();

      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                state: VideoState.paused,
                currentPosition: controller.value.position,
              ));

      _videoStateChangedController.add(videoId);
      notifyListeners();
    } catch (e) {
      print('Erreur de pause vidéo $videoId: $e');
    }
  }

  /// Met en pause toutes les vidéos
  void pauseAllVideos() {
    _isGlobalPaused = true;
    _activeVideoId = null;

    for (final controller in _controllers.values) {
      controller.pause();
    }

    for (final videoId in _videoInfo.keys) {
      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                state: VideoState.paused,
              ));
    }

    notifyListeners();
  }

  /// Reprend la lecture de la vidéo active
  Future<void> resumeActiveVideo() async {
    if (_activeVideoId != null && !_isGlobalPaused) {
      await playVideo(_activeVideoId!);
    }
  }

  /// Change le volume global
  void setGlobalVolume(double volume) {
    _globalVolume = volume.clamp(0.0, 1.0);

    for (final controller in _controllers.values) {
      controller.setVolume(_globalVolume);
    }

    for (final videoId in _videoInfo.keys) {
      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                volume: _globalVolume,
              ));
    }

    notifyListeners();
  }

  /// Active/désactive le mode muet
  void setMuted(bool muted) {
    _isMuted = muted;

    for (final controller in _controllers.values) {
      controller.setVolume(muted ? 0.0 : _globalVolume);
    }

    for (final videoId in _videoInfo.keys) {
      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                isMuted: muted,
              ));
    }

    notifyListeners();
  }

  /// Se positionne dans une vidéo
  Future<void> seekTo(String videoId, Duration position) async {
    final controller = _controllers[videoId];
    if (controller == null) return;

    try {
      await controller.seekTo(position);

      _updateVideoInfo(
          videoId,
          (info) => info.copyWith(
                currentPosition: position,
              ));
    } catch (e) {
      print('Erreur de positionnement vidéo $videoId: $e');
    }
  }

  /// Retry d'initialisation en cas d'erreur
  Future<VideoPlayerController?> retryVideo(String videoId) async {
    final info = _videoInfo[videoId];
    if (info == null) return null;

    // Nettoyer l'ancien contrôleur
    await disposeVideo(videoId);

    // Réinitialiser
    return initializeVideo(
      videoId: videoId,
      videoUrl: info.url,
      title: info.title,
      quality: info.quality,
    );
  }

  /// Libère une vidéo
  Future<void> disposeVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller != null) {
      await controller.dispose();
      _controllers.remove(videoId);
    }

    final listener = _listeners[videoId];
    if (listener != null) {
      await listener.cancel();
      _listeners.remove(videoId);
    }

    _videoInfo.remove(videoId);

    if (_activeVideoId == videoId) {
      _activeVideoId = null;
    }

    notifyListeners();
  }

  /// Libère toutes les vidéos
  Future<void> disposeAll() async {
    for (final controller in _controllers.values) {
      await controller.dispose();
    }

    for (final listener in _listeners.values) {
      await listener.cancel();
    }

    _controllers.clear();
    _listeners.clear();
    _videoInfo.clear();
    _activeVideoId = null;

    await _videoStateChangedController.close();
    notifyListeners();
  }

  /// Obtient les infos d'une vidéo
  VideoInfo? getVideoInfo(String videoId) {
    return _videoInfo[videoId];
  }

  /// Obtient le contrôleur d'une vidéo
  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  /// Obtient l'état d'une vidéo
  VideoState getVideoState(String videoId) {
    return _videoInfo[videoId]?.state ?? VideoState.uninitialized;
  }

  /// Obtient les métriques
  Map<String, dynamic> getMetrics() {
    return {
      'cached_videos': _controllers.length,
      'total_play_count':
          _playCount.values.fold(0, (sum, count) => sum + count),
      'total_play_time': _totalPlayTime.values
          .fold(Duration.zero, (sum, duration) => sum + duration),
      'total_errors': _errorCount.values.fold(0, (sum, count) => sum + count),
      'most_played': _playCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
            .take(5)
            .map((e) => {'video_id': e.key, 'play_count': e.value})
            .toList(),
    };
  }

  // Méthodes privées

  void _onVideoStateChanged(String videoId, VideoPlayerController controller) {
    final value = controller.value;
    VideoState newState = VideoState.ready;

    if (value.isPlaying) {
      newState = VideoState.playing;
      _updateTotalPlayTime(videoId, value.position);
    } else if (value.isBuffering) {
      newState = VideoState.buffering;
    } else if (value.hasError) {
      newState = VideoState.error;
      _errorCount[videoId] = (_errorCount[videoId] ?? 0) + 1;
    } else if (!value.isInitialized) {
      newState = VideoState.loading;
    }

    _updateVideoInfo(
        videoId,
        (info) => info.copyWith(
              state: newState,
              currentPosition: value.position,
              duration: value.duration,
              errorMessage: value.hasError ? value.errorDescription : null,
            ));
  }

  void _updateVideoInfo(String videoId, VideoInfo Function(VideoInfo) updater) {
    final currentInfo = _videoInfo[videoId];
    if (currentInfo != null) {
      _videoInfo[videoId] = updater(currentInfo);
    }
  }

  void _updateTotalPlayTime(String videoId, Duration position) {
    final current = _totalPlayTime[videoId] ?? Duration.zero;
    _totalPlayTime[videoId] = current + const Duration(seconds: 1);
  }

  void _pauseOtherVideos(String activeVideoId) {
    for (final entry in _controllers.entries) {
      if (entry.key != activeVideoId) {
        entry.value.pause();
        _updateVideoInfo(
            entry.key,
            (info) => info.copyWith(
                  state: VideoState.paused,
                ));
      }
    }
  }

  void _cleanupCache() {
    if (_controllers.length < _maxCachedVideos) return;

    // Trier par dernière utilisation
    final sortedVideos = _videoInfo.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

    // Supprimer les plus anciens
    final toRemove =
        sortedVideos.take(_controllers.length - _maxCachedVideos + 1);

    for (final entry in toRemove) {
      disposeVideo(entry.key);
    }
  }
}
