import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

// Video state for use in widgets and state manager
enum VideoState { loading, playing, paused, error, stopped }

// Video quality enum for selection
enum VideoQuality { auto, low, medium, high }

class VideoInfo {
  final VideoState state;
  final String? errorMessage;
  final VideoPlayerController? controller;
  VideoInfo({
    required this.state,
    this.errorMessage,
    this.controller,
  });
}

class VideoStateManager {
  static final VideoStateManager _instance = VideoStateManager._internal();
  factory VideoStateManager() => _instance;
  VideoStateManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isPlaying = {};
  final Map<String, bool> _isInitialized = {};
  final List<VoidCallback> _listeners = [];
  final Map<String, VideoInfo> _videoInfos = {};

  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  bool isPlaying(String videoId) {
    return _isPlaying[videoId] ?? false;
  }

  bool isInitialized(String videoId) {
    return _isInitialized[videoId] ?? false;
  }

  // Add a listener for state changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Notify listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // Get video info for a videoId
  VideoInfo? getVideoInfo(String videoId) {
    return _videoInfos[videoId];
  }

  // Initialize video and update state
  Future<VideoPlayerController?> initializeVideo({
    required String videoId,
    required String videoUrl,
    String? title,
    VideoQuality? quality,
  }) async {
    try {
      _videoInfos[videoId] = VideoInfo(state: VideoState.loading);
      _notifyListeners();
      final controller = await initializeController(videoId, videoUrl);
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.paused, controller: controller);
      _notifyListeners();
      return controller;
    } catch (e) {
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.error, errorMessage: e.toString());
      _notifyListeners();
      return null;
    }
  }

  // Play video and update state
  Future<void> playVideo(String videoId) async {
    try {
      await play(videoId);
      final controller = _controllers[videoId];
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.playing, controller: controller);
      _notifyListeners();
    } catch (e) {
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.error, errorMessage: e.toString());
      _notifyListeners();
    }
  }

  // Pause video and update state
  Future<void> pauseVideo(String videoId) async {
    try {
      await pause(videoId);
      final controller = _controllers[videoId];
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.paused, controller: controller);
      _notifyListeners();
    } catch (e) {
      _videoInfos[videoId] =
          VideoInfo(state: VideoState.error, errorMessage: e.toString());
      _notifyListeners();
    }
  }

  Future<VideoPlayerController> initializeController(
      String videoId, String videoUrl) async {
    try {
      if (_controllers.containsKey(videoId)) {
        return _controllers[videoId]!;
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[videoId] = controller;

      await controller.initialize();
      _isInitialized[videoId] = true;

      // Écouter les changements d'état
      controller.addListener(() {
        _isPlaying[videoId] = controller.value.isPlaying;
      });

      if (kDebugMode) {
        print('✅ Contrôleur vidéo initialisé pour: $videoId');
      }

      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'initialisation du contrôleur vidéo: $e');
      }
      rethrow;
    }
  }

  Future<void> play(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && controller.value.isInitialized) {
        await controller.play();
        _isPlaying[videoId] = true;

        if (kDebugMode) {
          print('▶️ Lecture démarrée pour: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la lecture: $e');
      }
    }
  }

  Future<void> pause(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
        _isPlaying[videoId] = false;

        if (kDebugMode) {
          print('⏸️ Lecture mise en pause pour: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la mise en pause: $e');
      }
    }
  }

  Future<void> seekTo(String videoId, Duration position) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && controller.value.isInitialized) {
        await controller.seekTo(position);

        if (kDebugMode) {
          print('⏭️ Saut à la position ${position.inSeconds}s pour: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du saut: $e');
      }
    }
  }

  void pauseAll() {
    for (final entry in _controllers.entries) {
      if (entry.value.value.isPlaying) {
        pause(entry.key);
      }
    }
  }

  void disposeController(String videoId) {
    try {
      final controller = _controllers[videoId];
      if (controller != null) {
        controller.dispose();
        _controllers.remove(videoId);
        _isPlaying.remove(videoId);
        _isInitialized.remove(videoId);

        if (kDebugMode) {
          print('🗑️ Contrôleur vidéo supprimé pour: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression du contrôleur: $e');
      }
    }
  }

  void disposeAll() {
    try {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _isPlaying.clear();
      _isInitialized.clear();

      if (kDebugMode) {
        print('🗑️ Tous les contrôleurs vidéo supprimés');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression de tous les contrôleurs: $e');
      }
    }
  }

  Duration getPosition(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.position ?? Duration.zero;
  }

  Duration getDuration(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.duration ?? Duration.zero;
  }

  double getAspectRatio(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.aspectRatio ?? 16 / 9;
  }
}
