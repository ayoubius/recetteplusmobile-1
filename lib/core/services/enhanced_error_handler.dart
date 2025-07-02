import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ErrorType {
  network,
  authentication,
  validation,
  permission,
  server,
  unknown,
}

class AppError {
  final ErrorType type;
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'AppError(type: $type, message: $message, code: $code)';
  }
}

class EnhancedErrorHandler {
  static final List<AppError> _errorHistory = [];
  static const int maxErrorHistory = 100;

  static AppError handleError(dynamic error, [StackTrace? stackTrace]) {
    final appError = _categorizeError(error, stackTrace);
    _logError(appError);
    _addToHistory(appError);
    return appError;
  }

  static AppError _categorizeError(dynamic error, StackTrace? stackTrace) {
    if (error is AuthException) {
      return AppError(
        type: ErrorType.authentication,
        message: _getAuthErrorMessage(error),
        code: error.statusCode,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error is PostgrestException) {
      return AppError(
        type: ErrorType.server,
        message: error.message,
        code: error.code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error.toString().contains('SocketException') || 
        error.toString().contains('TimeoutException')) {
      return AppError(
        type: ErrorType.network,
        message: 'Problème de connexion réseau',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    return AppError(
      type: ErrorType.unknown,
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static String _getAuthErrorMessage(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return 'Données d\'authentification invalides';
      case '401':
        return 'Session expirée, veuillez vous reconnecter';
      case '403':
        return 'Accès non autorisé';
      case '422':
        return 'Email ou mot de passe incorrect';
      default:
        return 'Erreur d\'authentification';
    }
  }

  static void _logError(AppError error) {
    if (kDebugMode) {
      print('🔴 ERROR [${error.type}]: ${error.message}');
      if (error.stackTrace != null) {
        print('Stack trace: ${error.stackTrace}');
      }
    }
    
    // En production, envoyer à un service de monitoring
    if (kReleaseMode) {
      _sendToMonitoring(error);
    }
  }

  static void _addToHistory(AppError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  static void _sendToMonitoring(AppError error) {
    // Intégration avec Firebase Crashlytics ou Sentry
    // FirebaseCrashlytics.instance.recordError(
    //   error.originalError,
    //   error.stackTrace,
    //   information: [error.message],
    // );
  }

  static List<AppError> getErrorHistory() => List.unmodifiable(_errorHistory);
  
  static void clearErrorHistory() => _errorHistory.clear();
  
  static Map<ErrorType, int> getErrorStats() {
    final stats = <ErrorType, int>{};
    for (final error in _errorHistory) {
      stats[error.type] = (stats[error.type] ?? 0) + 1;
    }
    return stats;
  }
}
