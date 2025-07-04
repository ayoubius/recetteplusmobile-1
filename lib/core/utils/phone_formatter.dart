import 'package:flutter/services.dart';

class PhoneValidator {
  /// Normaliser un numéro de téléphone malien
  static String normalizePhone(String phone) {
    if (phone.isEmpty) return phone;

    // Supprimer tous les caractères non numériques sauf le +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Si le numéro commence par +223, le garder tel quel
    if (cleaned.startsWith('+223')) {
      return cleaned;
    }

    // Si le numéro commence par 223, ajouter le +
    if (cleaned.startsWith('223')) {
      return '+$cleaned';
    }

    // Si le numéro fait 8 chiffres, ajouter +223
    if (cleaned.length == 8 && RegExp(r'^\d{8}$').hasMatch(cleaned)) {
      return '+223$cleaned';
    }

    // Retourner le numéro tel quel si aucun format ne correspond
    return phone;
  }

  /// Formater un numéro pour l'affichage
  static String formatForDisplay(String phone) {
    final normalized = normalizePhone(phone);

    if (normalized.startsWith('+223') && normalized.length == 12) {
      // Format: +223 XX XX XX XX
      final number = normalized.substring(4);
      return '+223 ${number.substring(0, 2)} ${number.substring(2, 4)} ${number.substring(4, 6)} ${number.substring(6, 8)}';
    }

    return phone;
  }

  /// Vérifier si un numéro est valide
  static bool isValid(String phone) {
    final normalized = normalizePhone(phone);

    // Vérifier le format malien: +223 suivi de 8 chiffres
    return RegExp(r'^\+223\d{8}$').hasMatch(normalized);
  }
}

/// Formatter pour les numéros de téléphone maliens
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PhoneValidator.formatForDisplay(newValue.text);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
