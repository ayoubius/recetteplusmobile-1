import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoStateManager {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializedControllers = {};

  // Initialiser un contrôleur vidéo
  Future<VideoPlayerController> initializeController(String videoId, String videoUrl) async {
    try {
      // Si le contrôleur existe déjà, le retourner
      if (_controllers.containsKey(videoId) && _initializedControllers[videoId] == true) {
        return _controllers[videoId]!;
      }

      // Créer un nouveau contrôleur
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[videoId] = controller;

      // Initialiser le contrôleur
      await controller.initialize();
      _initializedControllers[videoId] = true;

      if (kDebugMode) {
        print('✅ Contrôleur vidéo initialisé pour: $videoId');
      }

      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'initialisation du contrôleur vidéo: $e');
      }
      _initializedControllers[videoId] = false;
      rethrow;
    }
  }

  // Obtenir un contrôleur existant
  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  // Vérifier si un contrôleur est initialisé
  bool isControllerInitialized(String videoId) {
    return _initializedControllers[videoId] == true;
  }

  // Jouer une vidéo
  Future<void> play(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && _initializedControllers[videoId] == true) {
        await controller.play();
        if (kDebugMode) {
          print('▶️ Lecture de la vidéo: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la lecture: $e');
      }
    }
  }

  // Mettre en pause une vidéo
  Future<void> pause(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && _initializedControllers[videoId] == true) {
        await controller.pause();
        if (kDebugMode) {
          print('⏸️ Pause de la vidéo: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la pause: $e');
      }
    }
  }

  // Mettre en pause toutes les vidéos sauf une
  Future<void> pauseAllExcept(String activeVideoId) async {
    try {
      for (final entry in _controllers.entries) {
        if (entry.key != activeVideoId && _initializedControllers[entry.key] == true) {
          await entry.value.pause();
        }
      }
      if (kDebugMode) {
        print('⏸️ Pause de toutes les vidéos sauf: $activeVideoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la pause globale: $e');
      }
    }
  }

  // Aller à une position spécifique
  Future<void> seekTo(String videoId, Duration position) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && _initializedControllers[videoId] == true) {
        await controller.seekTo(position);
        if (kDebugMode) {
          print('⏭️ Saut à ${position.inSeconds}s pour la vidéo: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du saut: $e');
      }
    }
  }

  // Définir le volume
  Future<void> setVolume(String videoId, double volume) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && _initializedControllers[videoId] == true) {
        await controller.setVolume(volume.clamp(0.0, 1.0));
        if (kDebugMode) {
          print('🔊 Volume défini à ${(volume * 100).toInt()}% pour la vidéo: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du réglage du volume: $e');
      }
    }
  }

  // Nettoyer un contrôleur spécifique
  Future<void> disposeController(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null) {
        await controller.dispose();
        _controllers.remove(videoId);
        _initializedControllers.remove(videoId);
        if (kDebugMode) {
          print('🗑️ Contrôleur vidéo nettoyé pour: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du nettoyage du contrôleur: $e');
      }
    }
  }

  // Nettoyer tous les contrôleurs
  Future<void> disposeAll() async {
    try {
      for (final controller in _controllers.values) {
        await controller.dispose();
      }
      _controllers.clear();
      _initializedControllers.clear();
      if (kDebugMode) {
        print('🗑️ Tous les contrôleurs vidéo ont été nettoyés');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du nettoyage global: $e');
      }
    }
  }

  // Obtenir les informations d'une vidéo
  Map<String, dynamic>? getVideoInfo(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null && _initializedControllers[videoId] == true) {
      return {
        'duration': controller.value.duration,
        'position': controller.value.position,
        'isPlaying': controller.value.isPlaying,
        'isBuffering': controller.value.isBuffering,
        'hasError': controller.value.hasError,
        'aspectRatio': controller.value.aspectRatio,
        'volume': controller.value.volume,
      };
    }
    return null;
  }

  // Obtenir le nombre de contrôleurs actifs
  int get activeControllersCount => _controllers.length;

  // Obtenir la liste des IDs de vidéos actives
  List<String> get activeVideoIds => _controllers.keys.toList();
}
