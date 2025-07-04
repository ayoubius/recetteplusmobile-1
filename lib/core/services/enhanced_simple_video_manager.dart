import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

/// Version améliorée du SimpleVideoManager avec gestion robuste du cycle de vie
class EnhancedSimpleVideoManager {
  static final EnhancedSimpleVideoManager _instance = EnhancedSimpleVideoManager._internal();
  factory EnhancedSimpleVideoManager() => _instance;
  EnhancedSimpleVideoManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isInitialized = {};
  final Map<String, bool> _wasPlayingBeforePause = {};
  final Set<String> _isLoading = {};
  String? _currentPlayingId;
  String? _currentPageId;
  String? _lastActiveVideoId; // Nouvelle variable pour tracker la dernière vidéo active

  // Callbacks pour les changements d'état
  final List<VoidCallback> _onPauseCallbacks = [];
  final List<VoidCallback> _onPlayCallbacks = [];
  final List<Function(String)> _onVideoInitializedCallbacks = [];

  // Configuration
  bool _autoResumeOnPageReturn = true; // Activé par défaut
  bool _autoPlayOnAppStart = true; // Nouvelle option pour le démarrage automatique
  Duration _preloadDistance = const Duration(seconds: 5);

  /// Configurer le comportement du manager
  void configure({
    bool autoResumeOnPageReturn = true,
    bool autoPlayOnAppStart = true,
    Duration preloadDistance = const Duration(seconds: 5),
  }) {
    _autoResumeOnPageReturn = autoResumeOnPageReturn;
    _autoPlayOnAppStart = autoPlayOnAppStart;
    _preloadDistance = preloadDistance;
    
    if (kDebugMode) {
      print('⚙️ Configuration du VideoManager:');
      print('   - Auto resume: $_autoResumeOnPageReturn');
      print('   - Auto play on start: $_autoPlayOnAppStart');
      print('   - Preload distance: ${_preloadDistance.inSeconds}s');
    }
  }

  /// Définir la page actuelle
  void setCurrentPage(String pageId) {
    final previousPage = _currentPageId;
    _currentPageId = pageId;
    
    if (previousPage != null && previousPage != pageId) {
      _handlePageChange(previousPage, pageId);
    }
    
    if (kDebugMode) {
      print('📄 Page actuelle: $pageId');
    }
  }

  void _handlePageChange(String fromPage, String toPage) {
    if (kDebugMode) {
      print('🔄 Changement de page: $fromPage -> $toPage');
    }
    
    // Si on quitte la page vidéos, sauvegarder l'état et mettre en pause
    if (fromPage == 'videos') {
      _savePlaybackStates();
      pauseAll();
    }
    
    // Si on arrive sur la page vidéos et que l'auto-resume est activé
    if (toPage == 'videos' && _autoResumeOnPageReturn) {
      // Délai pour permettre à la page de se charger complètement
      Future.delayed(const Duration(milliseconds: 800), () {
        _restorePlaybackStates();
      });
    }
  }

  void _savePlaybackStates() {
    for (final entry in _controllers.entries) {
      final videoId = entry.key;
      final controller = entry.value;
      
      if (_isInitialized[videoId] == true) {
        final wasPlaying = controller.value.isPlaying;
        _wasPlayingBeforePause[videoId] = wasPlaying;
        
        // Sauvegarder la dernière vidéo qui était en cours de lecture
        if (wasPlaying) {
          _lastActiveVideoId = videoId;
        }
      }
    }
    
    if (kDebugMode) {
      print('💾 États de lecture sauvegardés');
      print('📹 Dernière vidéo active: $_lastActiveVideoId');
    }
  }

  void _restorePlaybackStates() {
    if (kDebugMode) {
      print('🔄 Tentative de restauration des états de lecture');
    }

    // Si on a une dernière vidéo active, la reprendre en priorité
    if (_lastActiveVideoId != null && _controllers.containsKey(_lastActiveVideoId)) {
      Future.delayed(const Duration(milliseconds: 300), () {
        playVideo(_lastActiveVideoId!);
        if (kDebugMode) {
          print('▶️ Reprise de la dernière vidéo active: $_lastActiveVideoId');
        }
      });
      return;
    }

    // Sinon, reprendre toutes les vidéos qui étaient en lecture
    bool hasResumedAny = false;
    for (final entry in _wasPlayingBeforePause.entries) {
      final videoId = entry.key;
      final wasPlaying = entry.value;
      
      if (wasPlaying && _controllers.containsKey(videoId) && !hasResumedAny) {
        Future.delayed(const Duration(milliseconds: 300), () {
          playVideo(videoId);
        });
        hasResumedAny = true;
        break; // Ne reprendre qu'une seule vidéo à la fois
      }
    }
    
    _wasPlayingBeforePause.clear();
    
    if (kDebugMode) {
      print('🔄 États de lecture restaurés');
    }
  }

  /// Méthode pour démarrer la lecture automatique au lancement de l'app
  void startAutoPlayIfEnabled(String videoId) {
    if (_autoPlayOnAppStart && _currentPageId == 'videos') {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_controllers.containsKey(videoId) && _isInitialized[videoId] == true) {
          playVideo(videoId);
          if (kDebugMode) {
            print('🚀 Lecture automatique au démarrage: $videoId');
          }
        }
      });
    }
  }

  // Ajouter des callbacks
  void addOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.add(callback);
  }

  void removeOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.remove(callback);
  }

  void addOnPlayCallback(VoidCallback callback) {
    _onPlayCallbacks.add(callback);
  }

  void removeOnPlayCallback(VoidCallback callback) {
    _onPlayCallbacks.remove(callback);
  }

  void addOnVideoInitializedCallback(Function(String) callback) {
    _onVideoInitializedCallbacks.add(callback);
  }

  void removeOnVideoInitializedCallback(Function(String) callback) {
    _onVideoInitializedCallbacks.remove(callback);
  }

  /// Initialiser une vidéo avec gestion d'erreur améliorée
  Future<VideoPlayerController?> initializeVideo(String videoId, String videoUrl) async {
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId];
    }

    if (_isLoading.contains(videoId)) {
      // Attendre que l'initialisation en cours se termine
      while (_isLoading.contains(videoId)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _controllers[videoId];
    }

    _isLoading.add(videoId);

    try {
      if (kDebugMode) {
        print('🎬 Initialisation vidéo: $videoId');
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[videoId] = controller;

      // Timeout pour l'initialisation
      await controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Timeout lors de l\'initialisation de la vidéo', const Duration(seconds: 30));
        },
      );

      _isInitialized[videoId] = true;
      
      // Configuration par défaut
      await controller.setLooping(true);
      await controller.setVolume(1.0);

      // Notifier les callbacks
      for (final callback in _onVideoInitializedCallbacks) {
        try {
          callback(videoId);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Erreur dans callback video initialized: $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Vidéo initialisée: $videoId');
      }

      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation vidéo $videoId: $e');
      }
      _controllers.remove(videoId);
      _isInitialized.remove(videoId);
      return null;
    } finally {
      _isLoading.remove(videoId);
    }
  }

  /// Jouer une vidéo avec gestion exclusive
  Future<bool> playVideo(String videoId) async {
    try {
      // Arrêter la vidéo actuellement en cours
      if (_currentPlayingId != null && _currentPlayingId != videoId) {
        await pauseVideo(_currentPlayingId!);
      }

      final controller = _controllers[videoId];
      if (controller != null && _isInitialized[videoId] == true) {
        await controller.play();
        _currentPlayingId = videoId;
        _lastActiveVideoId = videoId; // Mettre à jour la dernière vidéo active
        
        // Notifier les callbacks
        for (final callback in _onPlayCallbacks) {
          try {
            callback();
          } catch (e) {
            if (kDebugMode) {
              print('❌ Erreur dans callback play: $e');
            }
          }
        }
        
        if (kDebugMode) {
          print('▶️ Lecture: $videoId');
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la lecture de $videoId: $e');
      }
      return false;
    }
  }

  /// Mettre en pause une vidéo
  Future<bool> pauseVideo(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null && _isInitialized[videoId] == true) {
        await controller.pause();
        
        if (_currentPlayingId == videoId) {
          _currentPlayingId = null;
        }
        
        if (kDebugMode) {
          print('⏸️ Pause: $videoId');
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la pause de $videoId: $e');
      }
      return false;
    }
  }

  /// Arrêter toutes les vidéos avec gestion d'erreur
  Future<void> pauseAll() async {
    final pauseTasks = <Future>[];
    
    for (final entry in _controllers.entries) {
      if (_isInitialized[entry.key] == true) {
        pauseTasks.add(
          entry.value.pause().catchError((e) {
            if (kDebugMode) {
              print('❌ Erreur pause ${entry.key}: $e');
            }
          })
        );
      }
    }
    
    // Attendre que toutes les pauses soient terminées
    await Future.wait(pauseTasks);
    
    _currentPlayingId = null;
    
    // Notifier les callbacks
    for (final callback in _onPauseCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur dans callback pause: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('⏸️ Toutes les vidéos mises en pause');
    }
  }

  /// Forcer la reprise de lecture (utilisé lors du retour sur la page vidéos)
  Future<void> forceResumePlayback() async {
    if (_currentPageId != 'videos') return;
    
    if (kDebugMode) {
      print('🔄 Force resume playback demandée');
    }

    // Si on a une dernière vidéo active, la reprendre
    if (_lastActiveVideoId != null && _controllers.containsKey(_lastActiveVideoId)) {
      await playVideo(_lastActiveVideoId!);
      return;
    }

    // Sinon, reprendre la première vidéo disponible et initialisée
    for (final entry in _controllers.entries) {
      if (_isInitialized[entry.key] == true) {
        await playVideo(entry.key);
        break;
      }
    }
  }

  /// Précharger une vidéo
  Future<void> preloadVideo(String videoId, String videoUrl) async {
    if (!_controllers.containsKey(videoId) && !_isLoading.contains(videoId)) {
      await initializeVideo(videoId, videoUrl);
    }
  }

  /// Nettoyer une vidéo avec gestion d'erreur
  Future<void> disposeVideo(String videoId) async {
    try {
      final controller = _controllers[videoId];
      if (controller != null) {
        await controller.dispose();
        _controllers.remove(videoId);
        _isInitialized.remove(videoId);
        _isLoading.remove(videoId);
        _wasPlayingBeforePause.remove(videoId);
        
        if (_currentPlayingId == videoId) {
          _currentPlayingId = null;
        }
        
        if (_lastActiveVideoId == videoId) {
          _lastActiveVideoId = null;
        }
        
        if (kDebugMode) {
          print('🗑️ Vidéo supprimée: $videoId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression de $videoId: $e');
      }
    }
  }

  /// Nettoyer toutes les vidéos
  Future<void> disposeAll() async {
    final disposeTasks = <Future>[];
    
    for (final entry in _controllers.entries) {
      disposeTasks.add(
        entry.value.dispose().catchError((e) {
          if (kDebugMode) {
            print('❌ Erreur dispose ${entry.key}: $e');
          }
        })
      );
    }
    
    // Attendre que toutes les suppressions soient terminées
    await Future.wait(disposeTasks);
    
    _controllers.clear();
    _isInitialized.clear();
    _isLoading.clear();
    _wasPlayingBeforePause.clear();
    _currentPlayingId = null;
    _lastActiveVideoId = null;
    _onPauseCallbacks.clear();
    _onPlayCallbacks.clear();
    _onVideoInitializedCallbacks.clear();
    
    if (kDebugMode) {
      print('🗑️ Toutes les vidéos supprimées');
    }
  }

  // Getters et méthodes utilitaires
  VideoPlayerController? getController(String videoId) => _controllers[videoId];
  bool isInitialized(String videoId) => _isInitialized[videoId] == true;
  bool isLoading(String videoId) => _isLoading.contains(videoId);
  bool isPlaying(String videoId) => _controllers[videoId]?.value.isPlaying == true;
  String? get currentPlayingId => _currentPlayingId;
  String? get currentPageId => _currentPageId;
  String? get lastActiveVideoId => _lastActiveVideoId;
  
  Duration getPosition(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.position ?? Duration.zero;
  }

  Duration getDuration(String videoId) {
    final controller = _controllers[videoId];
    return controller?.value.duration ?? Duration.zero;
  }

  Future<void> seekTo(String videoId, Duration position) async {
    final controller = _controllers[videoId];
    if (controller != null && _isInitialized[videoId] == true) {
      await controller.seekTo(position);
      
      if (kDebugMode) {
        print('⏭️ Seek $videoId à ${position.inSeconds}s');
      }
    }
  }

  /// Obtenir des statistiques sur les vidéos
  Map<String, dynamic> getStats() {
    return {
      'total_controllers': _controllers.length,
      'initialized_videos': _isInitialized.values.where((v) => v).length,
      'loading_videos': _isLoading.length,
      'current_playing': _currentPlayingId,
      'current_page': _currentPageId,
      'last_active_video': _lastActiveVideoId,
      'auto_resume_enabled': _autoResumeOnPageReturn,
      'auto_play_on_start_enabled': _autoPlayOnAppStart,
    };
  }
}