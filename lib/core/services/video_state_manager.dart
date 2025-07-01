import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoStateManager {
  static final VideoStateManager _instance = VideoStateManager._internal();
  factory VideoStateManager() => _instance;
  VideoStateManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isInitialized = {};
  final Map<String, bool> _isPlaying = {};
  final Map<String, bool> _hasError = {};

  // Getters
  Map<String, VideoPlayerController> get controllers => _controllers;
  Map<String, bool> get isInitialized => _isInitialized;
  Map<String, bool> get isPlaying => _isPlaying;
  Map<String, bool> get hasError => _hasError;

  // Créer ou récupérer un contrôleur pour une vidéo
  VideoPlayerController? getController(String videoId, String videoUrl) {
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId];
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[videoId] = controller;
      _isInitialized[videoId] = false;
      _isPlaying[videoId] = false;
      _hasError[videoId] = false;

      // Écouter les changements d'état
      controller.addListener(() {
        _isPlaying[videoId] = controller.value.isPlaying;
        _hasError[videoId] = controller.value.hasError;
        
        if (controller.value.hasError) {
          if (kDebugMode) {
            print('❌ Erreur vidéo pour $videoId: ${controller.value.errorDescription}');
          }
        }
      });

      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la création du contrôleur pour $videoId: $e');
      }
      _hasError[videoId] = true;
      return null;
    }
  }

  // Initialiser un contrôleur
  Future<bool> initializeController(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null) return false;

    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
        _isInitialized[videoId] = true;
        _hasError[videoId] = false;
        
        if (kDebugMode) {
          print('✅ Contrôleur initialisé pour $videoId');
        }
        return true;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'initialisation du contrôleur pour $videoId: $e');
      }
      _hasError[videoId] = true;
      _isInitialized[videoId] = false;
      return false;
    }
  }

  // Jouer une vidéo
  Future<void> play(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.play();
      _isPlaying[videoId] = true;
      
      if (kDebugMode) {
        print('▶️ Lecture démarrée pour $videoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la lecture pour $videoId: $e');
      }
      _hasError[videoId] = true;
    }
  }

  // Mettre en pause une vidéo
  Future<void> pause(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.pause();
      _isPlaying[videoId] = false;
      
      if (kDebugMode) {
        print('⏸️ Lecture mise en pause pour $videoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la mise en pause pour $videoId: $e');
      }
    }
  }

  // Arrêter toutes les vidéos sauf une
  Future<void> pauseAllExcept(String? exceptVideoId) async {
    for (final entry in _controllers.entries) {
      if (entry.key != exceptVideoId && _isPlaying[entry.key] == true) {
        await pause(entry.key);
      }
    }
  }

  // Disposer d'un contrôleur spécifique
  Future<void> disposeController(String videoId) async {
    try {
      // Disposer du contrôleur
      final controller = _controllers[videoId];
      if (controller != null) {
        await controller.dispose();
        _controllers.remove(videoId);
      }

      // Nettoyer les états
      _isInitialized.remove(videoId);
      _isPlaying.remove(videoId);
      _hasError.remove(videoId);

      if (kDebugMode) {
        print('🗑️ Contrôleur disposé pour $videoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la disposition du contrôleur pour $videoId: $e');
      }
    }
  }

  // Disposer de tous les contrôleurs
  Future<void> disposeAll() async {
    try {
      // Disposer de tous les contrôleurs
      for (final controller in _controllers.values) {
        await controller.dispose();
      }
      _controllers.clear();

      // Nettoyer tous les états
      _isInitialized.clear();
      _isPlaying.clear();
      _hasError.clear();

      if (kDebugMode) {
        print('🗑️ Tous les contrôleurs ont été disposés');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la disposition de tous les contrôleurs: $e');
      }
    }
  }
}
