import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../../shared/widgets/connectivity_dialog.dart';

class ConnectivityUtils {
  /// Vérifier la connectivité avant d'exécuter une action
  static Future<bool> checkBeforeAction(
    BuildContext context, {
    bool showDialog = true,
  }) async {
    final connectivityService = ConnectivityService();

    if (connectivityService.isConnected) {
      return true;
    }

    if (showDialog && context.mounted) {
      final result = await ConnectivityDialog.show(context);
      return result == true;
    }

    return false;
  }

  /// Exécuter une action avec vérification de connectivité
  static Future<T?> executeWithConnectivity<T>(
    BuildContext context,
    Future<T> Function() action, {
    bool showDialog = true,
    String? errorMessage,
  }) async {
    final isConnected =
        await checkBeforeAction(context, showDialog: showDialog);

    if (!isConnected) {
      if (errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    try {
      return await action();
    } catch (e) {
      // Vérifier si l'erreur est liée à la connectivité
      if (_isConnectivityError(e)) {
        if (showDialog && context.mounted) {
          await ConnectivityDialog.show(context);
        }
      }
      rethrow;
    }
  }

  /// Vérifier si une erreur est liée à la connectivité
  static bool _isConnectivityError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('internet');
  }

  /// Obtenir un message d'erreur convivial
  static String getFriendlyErrorMessage(dynamic error) {
    if (_isConnectivityError(error)) {
      return 'Problème de connexion internet. Vérifiez votre réseau.';
    }
    return 'Une erreur inattendue s\'est produite.';
  }

  /// Wrapper pour les appels API
  static Future<T?> apiCall<T>(
    BuildContext context,
    Future<T> Function() apiFunction, {
    String? errorMessage,
    bool showConnectivityDialog = true,
  }) async {
    return executeWithConnectivity(
      context,
      apiFunction,
      showDialog: showConnectivityDialog,
      errorMessage: errorMessage ?? 'Action impossible sans connexion internet',
    );
  }
}
