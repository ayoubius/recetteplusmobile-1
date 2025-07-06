import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'enhanced_simple_video_manager.dart';

/// Gestionnaire du cycle de vie des vidéos pour gérer automatiquement
/// la pause lors des changements de page, de l'état de l'application, etc.
class VideoLifecycleManager with WidgetsBindingObserver {
  static final VideoLifecycleManager _instance =
      VideoLifecycleManager._internal();
  factory VideoLifecycleManager() => _instance;
  VideoLifecycleManager._internal();

  final EnhancedSimpleVideoManager _videoManager = EnhancedSimpleVideoManager();
  bool _isInitialized = false;
  bool _isAppInBackground = false;

  // Callbacks pour les événements de cycle de vie
  final List<VoidCallback> _onAppPausedCallbacks = [];
  final List<VoidCallback> _onAppResumedCallbacks = [];
  final List<VoidCallback> _onPageChangedCallbacks = [];

  /// Initialiser le gestionnaire de cycle de vie
  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    if (kDebugMode) {
      print('🔄 VideoLifecycleManager initialisé');
    }
  }

  /// Nettoyer le gestionnaire
  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _onAppPausedCallbacks.clear();
    _onAppResumedCallbacks.clear();
    _onPageChangedCallbacks.clear();
    _isInitialized = false;

    if (kDebugMode) {
      print('🗑️ VideoLifecycleManager nettoyé');
    }
  }

  /// Ajouter un callback pour quand l'app est mise en pause
  void addOnAppPausedCallback(VoidCallback callback) {
    _onAppPausedCallbacks.add(callback);
  }

  /// Supprimer un callback pour quand l'app est mise en pause
  void removeOnAppPausedCallback(VoidCallback callback) {
    _onAppPausedCallbacks.remove(callback);
  }

  /// Ajouter un callback pour quand l'app reprend
  void addOnAppResumedCallback(VoidCallback callback) {
    _onAppResumedCallbacks.add(callback);
  }

  /// Supprimer un callback pour quand l'app reprend
  void removeOnAppResumedCallback(VoidCallback callback) {
    _onAppResumedCallbacks.remove(callback);
  }

  /// Ajouter un callback pour les changements de page
  void addOnPageChangedCallback(VoidCallback callback) {
    _onPageChangedCallbacks.add(callback);
  }

  /// Supprimer un callback pour les changements de page
  void removeOnPageChangedCallback(VoidCallback callback) {
    _onPageChangedCallbacks.remove(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  void _handleAppPaused() {
    if (_isAppInBackground) return;

    _isAppInBackground = true;

    if (kDebugMode) {
      print('📱 Application mise en arrière-plan - Pause des vidéos');
    }

    // Mettre en pause toutes les vidéos
    _videoManager.pauseAll();

    // Notifier les callbacks
    for (final callback in _onAppPausedCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur dans callback app paused: $e');
        }
      }
    }
  }

  void _handleAppResumed() {
    if (!_isAppInBackground) return;

    _isAppInBackground = false;

    if (kDebugMode) {
      print('📱 Application reprise depuis l\'arrière-plan');
    }

    // Notifier les callbacks
    for (final callback in _onAppResumedCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur dans callback app resumed: $e');
        }
      }
    }
  }

  void _handleAppDetached() {
    if (kDebugMode) {
      print('📱 Application détachée - Nettoyage des vidéos');
    }

    // Nettoyer toutes les vidéos
    _videoManager.disposeAll();
  }

  void _handleAppHidden() {
    if (kDebugMode) {
      print('📱 Application cachée - Pause des vidéos');
    }

    // Mettre en pause toutes les vidéos
    _videoManager.pauseAll();
  }

  /// Méthode appelée lors des changements de page
  void onPageChanged(String? fromPage, String toPage) {
    if (kDebugMode) {
      print('🔄 Changement de page: ${fromPage ?? 'null'} -> $toPage');
    }

    // Mettre en pause toutes les vidéos lors du changement de page
    _videoManager.pauseAll();

    // Notifier les callbacks
    for (final callback in _onPageChangedCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur dans callback page changed: $e');
        }
      }
    }
  }

  /// Méthode pour forcer la pause de toutes les vidéos
  void pauseAllVideos() {
    if (kDebugMode) {
      print('⏸️ Pause forcée de toutes les vidéos');
    }

    _videoManager.pauseAll();
  }

  /// Vérifier si l'app est en arrière-plan
  bool get isAppInBackground => _isAppInBackground;

  /// Obtenir le gestionnaire de vidéos
  EnhancedSimpleVideoManager get videoManager => _videoManager;
}
