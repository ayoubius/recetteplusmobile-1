import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

enum ConnectivityStatus {
  connected,
  disconnected,
  checking,
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  ConnectivityStatus _status = ConnectivityStatus.checking;
  Timer? _timer;
  bool _isInitialized = false;
  String? _lastError;
  DateTime? _lastCheckTime;

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 10);
  static const Duration _timeoutDuration = Duration(seconds: 5);
  static const int _maxRetries = 3;

  // Getters
  ConnectivityStatus get status => _status;
  bool get isConnected => _status == ConnectivityStatus.connected;
  bool get isDisconnected => _status == ConnectivityStatus.disconnected;
  bool get isChecking => _status == ConnectivityStatus.checking;
  String? get lastError => _lastError;
  DateTime? get lastCheckTime => _lastCheckTime;

  /// Initialiser le service de connectivité
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print('🌐 Initialisation du service de connectivité...');
    }

    // Vérification initiale
    await _checkConnectivity();

    // Démarrer la vérification périodique
    _startPeriodicCheck();

    _isInitialized = true;

    if (kDebugMode) {
      print('✅ Service de connectivité initialisé');
    }
  }

  /// Démarrer la vérification périodique
  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) => _checkConnectivity());
  }

  /// Arrêter la vérification périodique
  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Vérifier la connectivité
  Future<bool> _checkConnectivity() async {
    _setStatus(ConnectivityStatus.checking);
    _lastCheckTime = DateTime.now();

    try {
      // Test 1: Vérifier la connectivité réseau basique
      final hasBasicConnectivity = await _hasBasicConnectivity();
      if (!hasBasicConnectivity) {
        _setStatus(ConnectivityStatus.disconnected);
        _lastError = 'Aucune connectivité réseau détectée';
        return false;
      }

      // Test 2: Vérifier la connectivité avec Supabase
      final hasSupabaseConnectivity = await _checkSupabaseConnectivity();
      if (!hasSupabaseConnectivity) {
        _setStatus(ConnectivityStatus.disconnected);
        _lastError = 'Impossible de se connecter aux services';
        return false;
      }

      // Test 3: Vérifier la connectivité internet générale
      final hasInternetConnectivity = await _checkInternetConnectivity();
      if (!hasInternetConnectivity) {
        _setStatus(ConnectivityStatus.disconnected);
        _lastError = 'Pas d\'accès à internet';
        return false;
      }

      _setStatus(ConnectivityStatus.connected);
      _lastError = null;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la vérification de connectivité: $e');
      }
      _setStatus(ConnectivityStatus.disconnected);
      _lastError = 'Erreur de connectivité: $e';
      return false;
    }
  }

  /// Vérifier la connectivité réseau basique
  Future<bool> _hasBasicConnectivity() async {
    try {
      final result =
          await InternetAddress.lookup('google.com').timeout(_timeoutDuration);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Vérifier la connectivité avec Supabase
  Future<bool> _checkSupabaseConnectivity() async {
    try {
      if (!SupabaseService.isInitialized) {
        return false;
      }

      // Test simple avec Supabase
      await SupabaseService.client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(_timeoutDuration);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Connectivité Supabase échouée: $e');
      }
      return false;
    }
  }

  /// Vérifier la connectivité internet générale
  Future<bool> _checkInternetConnectivity() async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('https://www.google.com'))
          .timeout(_timeoutDuration);
      final httpResponse = await response.close().timeout(_timeoutDuration);
      return httpResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Mettre à jour le statut et notifier les listeners
  void _setStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;

      if (kDebugMode) {
        print(
            '🌐 Connectivité: ${_statusToString(oldStatus)} → ${_statusToString(newStatus)}');
      }

      notifyListeners();
    }
  }

  /// Convertir le statut en string pour le debug
  String _statusToString(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.connected:
        return 'Connecté';
      case ConnectivityStatus.disconnected:
        return 'Déconnecté';
      case ConnectivityStatus.checking:
        return 'Vérification...';
    }
  }

  /// Forcer une vérification manuelle
  Future<bool> checkNow() async {
    if (kDebugMode) {
      print('🔄 Vérification manuelle de la connectivité...');
    }
    return await _checkConnectivity();
  }

  /// Vérification avec retry
  Future<bool> checkWithRetry({int retries = _maxRetries}) async {
    for (int i = 0; i < retries; i++) {
      final isConnected = await _checkConnectivity();
      if (isConnected) return true;

      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    return false;
  }

  /// Obtenir des informations détaillées sur la connectivité
  Future<Map<String, dynamic>> getDetailedStatus() async {
    final basicConnectivity = await _hasBasicConnectivity();
    final supabaseConnectivity = await _checkSupabaseConnectivity();
    final internetConnectivity = await _checkInternetConnectivity();

    return {
      'overall_status': _statusToString(_status),
      'basic_connectivity': basicConnectivity,
      'supabase_connectivity': supabaseConnectivity,
      'internet_connectivity': internetConnectivity,
      'last_check': _lastCheckTime?.toIso8601String(),
      'last_error': _lastError,
      'is_initialized': _isInitialized,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
