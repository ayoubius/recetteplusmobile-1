import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service pour gérer l'actualisation automatique des données
class RefreshService {
  static final Map<String, Timer> _timers = {};
  static final Map<String, StreamController<bool>> _controllers = {};

  /// Démarrer l'actualisation automatique pour un type de données
  static void startAutoRefresh({
    required String key,
    required Duration interval,
    required Future<void> Function() onRefresh,
  }) {
    // Arrêter le timer existant s'il y en a un
    stopAutoRefresh(key);

    if (kDebugMode) {
      print('🔄 Démarrage de l\'actualisation automatique pour: $key');
      print('   Intervalle: ${interval.inSeconds}s');
    }

    // Créer un nouveau controller pour ce type de données
    _controllers[key] = StreamController<bool>.broadcast();

    // Créer le timer
    _timers[key] = Timer.periodic(interval, (timer) async {
      try {
        if (kDebugMode) {
          print('🔄 Actualisation automatique: $key');
        }

        // Notifier le début de l'actualisation
        _controllers[key]?.add(true);

        // Exécuter la fonction d'actualisation
        await onRefresh();

        // Notifier la fin de l'actualisation
        _controllers[key]?.add(false);

        if (kDebugMode) {
          print('✅ Actualisation terminée: $key');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur lors de l\'actualisation $key: $e');
        }

        // Notifier la fin même en cas d'erreur
        _controllers[key]?.add(false);
      }
    });
  }

  /// Arrêter l'actualisation automatique pour un type de données
  static void stopAutoRefresh(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);

    _controllers[key]?.close();
    _controllers.remove(key);

    if (kDebugMode) {
      print('⏹️ Arrêt de l\'actualisation automatique: $key');
    }
  }

  /// Obtenir le stream d'état d'actualisation pour un type de données
  static Stream<bool>? getRefreshStream(String key) {
    return _controllers[key]?.stream;
  }

  /// Vérifier si l'actualisation est active pour un type de données
  static bool isRefreshActive(String key) {
    return _timers.containsKey(key) && _timers[key]!.isActive;
  }

  /// Arrêter toutes les actualisations
  static void stopAllRefresh() {
    final keys = List<String>.from(_timers.keys);
    for (final key in keys) {
      stopAutoRefresh(key);
    }

    if (kDebugMode) {
      print('⏹️ Arrêt de toutes les actualisations automatiques');
    }
  }

  /// Actualiser manuellement un type de données
  static Future<void> manualRefresh({
    required String key,
    required Future<void> Function() onRefresh,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Actualisation manuelle: $key');
      }

      // Notifier le début de l'actualisation
      _controllers[key]?.add(true);

      // Exécuter la fonction d'actualisation
      await onRefresh();

      // Notifier la fin de l'actualisation
      _controllers[key]?.add(false);

      if (kDebugMode) {
        print('✅ Actualisation manuelle terminée: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'actualisation manuelle $key: $e');
      }

      // Notifier la fin même en cas d'erreur
      _controllers[key]?.add(false);
      rethrow;
    }
  }

  /// Obtenir les statistiques d'actualisation
  static Map<String, dynamic> getRefreshStats() {
    return {
      'active_refreshes': _timers.length,
      'refresh_keys': _timers.keys.toList(),
      'active_streams': _controllers.length,
    };
  }
}

/// Mixin pour faciliter l'utilisation du service d'actualisation dans les widgets
mixin RefreshMixin {
  final Map<String, StreamSubscription> _refreshSubscriptions = {};

  /// Démarrer l'écoute des actualisations pour un type de données
  void listenToRefresh(String key, void Function(bool isRefreshing) onRefreshStateChanged) {
    final stream = RefreshService.getRefreshStream(key);
    if (stream != null) {
      _refreshSubscriptions[key] = stream.listen(onRefreshStateChanged);
    }
  }

  /// Arrêter l'écoute des actualisations
  void stopListeningToRefresh(String key) {
    _refreshSubscriptions[key]?.cancel();
    _refreshSubscriptions.remove(key);
  }

  /// Nettoyer toutes les souscriptions (à appeler dans dispose)
  void disposeRefreshListeners() {
    for (final subscription in _refreshSubscriptions.values) {
      subscription.cancel();
    }
    _refreshSubscriptions.clear();
  }
}

/// Constantes pour les clés d'actualisation
class RefreshKeys {
  static const String orders = 'orders';
  static const String deliveryPersons = 'delivery_persons';
  static const String pendingOrders = 'pending_orders';
  static const String userOrders = 'user_orders';
  static const String activeDeliveries = 'active_deliveries';
  static const String orderTracking = 'order_tracking';
  static const String products = 'products';
  static const String recipes = 'recipes';
  static const String videos = 'videos';
  static const String cartItems = 'cart_items';
  static const String favorites = 'favorites';
  static const String userProfile = 'user_profile';
}

/// Intervalles d'actualisation recommandés
class RefreshIntervals {
  static const Duration realTime = Duration(seconds: 10);
  static const Duration frequent = Duration(seconds: 30);
  static const Duration normal = Duration(minutes: 1);
  static const Duration slow = Duration(minutes: 5);
  static const Duration verySlow = Duration(minutes: 15);
}