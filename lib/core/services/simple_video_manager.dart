import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class SimpleVideoManager {
  static final SimpleVideoManager _instance = SimpleVideoManager._internal();
  factory SimpleVideoManager() => _instance;
  SimpleVideoManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isInitialized = {};
  final Set<String> _isLoading = {};
  String? _currentPlayingId;

  // Callbacks pour les changements d'état
  final List<VoidCallback> _onPauseCallbacks = [];

  // Ajouter un callback pour les pauses automatiques
  void addOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.add(callback);
  }

  void removeOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.remove(callback);
  }

  // Initialiser une vidéo
  Future<VideoPlayerController?> initializeVideo(String videoId, String videoUrl) async {
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId];
    }

    if (_isLoading.contains(videoId)) {
      return null;
    }

    _isLoading.add(videoId);

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[videoId] = controller;

      await controller.initialize();
      _isInitialized[videoId] = true;
      
      // Configuration par défaut
      controller.setLooping(true);
      controller.setVolume(1.0);

      if (kDebugMode) {
        print('✅ Vidéo initialisée: $videoId');
      }

      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation vidéo $videoId: $e');
      }
      _controllers.remove(videoId);
      return null;
    } finally {
      _isLoading.remove(videoId);
    }
  }

  // Jouer une vidéo (et arrêter les autres)
  Future<void> playVideo(String videoId) async {
    // Arrêter la vidéo actuellement en cours
    if (_currentPlayingId != null && _currentPlayingId != videoId) {
      await pauseVideo(_currentPlayingId!);
    }

    final controller = _controllers[videoId];
    if (controller != null && _isInitialized[videoId] == true) {
      await controller.play();
      _currentPlayingId = videoId;
      
      if (kDebugMode) {
        print('▶️ Lecture: $videoId');
      }
    }
  }

  // Mettre en pause une vidéo
  Future<void> pauseVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller != null && _isInitialized[videoId] == true) {
      await controller.pause();
      
      if (_currentPlayingId == videoId) {
        _currentPlayingId = null;
      }
      
      if (kDebugMode) {
        print('⏸️ Pause: $videoId');
      }
    }
  }

  // Arrêter toutes les vidéos (appelé lors des changements de page)
  Future<void> pauseAll() async {
    for (final entry in _controllers.entries) {
      if (_isInitialized[entry.key] == true) {
        await entry.value.pause();
      }
    }
    _currentPlayingId = null;
    
    // Notifier les callbacks
    for (final callback in _onPauseCallbacks) {
      callback();
    }
    
    if (kDebugMode) {
      print('⏸️ Toutes les vidéos mises en pause');
    }
  }

  // Obtenir un contrôleur
  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  // Vérifier si une vidéo est initialisée
  bool isInitialized(String videoId) {
    return _isInitialized[videoId] == true;
  }

  // Vérifier si une vidéo est en cours de chargement
  bool isLoading(String videoId) {
    return _isLoading.contains(videoId);
  }

  // Vérifier si une vidéo est en cours de lecture
  bool isPlaying(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.isPlaying == true;
  }

  // Obtenir la vidéo actuellement en lecture
  String? get currentPlayingId => _currentPlayingId;

  // Nettoyer une vidéo
  void disposeVideo(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null) {
      controller.dispose();
      _controllers.remove(videoId);
      _isInitialized.remove(videoId);
      _isLoading.remove(videoId);
      
      if (_currentPlayingId == videoId) {
        _currentPlayingId = null;
      }
      
      if (kDebugMode) {
        print('🗑️ Vidéo supprimée: $videoId');
      }
    }
  }

  // Nettoyer toutes les vidéos
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _isInitialized.clear();
    _isLoading.clear();
    _currentPlayingId = null;
    _onPauseCallbacks.clear();
    
    if (kDebugMode) {
      print('🗑️ Toutes les vidéos supprimées');
    }
  }

  // Obtenir la position actuelle
  Duration getPosition(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.position ?? Duration.zero;
  }

  // Obtenir la durée totale
  Duration getDuration(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.duration ?? Duration.zero;
  }

  // Chercher à une position spécifique
  Future<void> seekTo(String videoId, Duration position) async {
    final controller = _controllers[videoId];
    if (controller != null && _isInitialized[videoId] == true) {
      await controller.seekTo(position);
      
      if (kDebugMode) {
        print('⏭️ Seek $videoId à ${position.inSeconds}s');
      }
    }
  }
}
