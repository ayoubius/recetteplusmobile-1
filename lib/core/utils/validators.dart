class Validators {
  /// Valider un nom complet
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom complet est requis';
    }

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }

    if (trimmed.length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères';
    }

    // Vérifier que le nom contient uniquement des lettres, espaces et tirets
    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Le nom ne peut contenir que des lettres, espaces et tirets';
    }

    return null;
  }

  /// Valider une adresse email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'adresse email est requise';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Veuillez entrer une adresse email valide';
    }

    return null;
  }

  /// Valider un mot de passe
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }

    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }

    if (value.length > 128) {
      return 'Le mot de passe ne peut pas dépasser 128 caractères';
    }

    // Vérifier qu'il contient au moins une lettre minuscule
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre minuscule';
    }

    // Vérifier qu'il contient au moins une lettre majuscule
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre majuscule';
    }

    // Vérifier qu'il contient au moins un chiffre
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }

    return null;
  }

  /// Valider un mot de passe pour la connexion (aucune complexité, juste requis)
  static String? validatePasswordForSignIn(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    return null;
  }

  /// Valider la confirmation de mot de passe
  static String? validatePasswordConfirmation(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'La confirmation du mot de passe est requise';
    }

    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }

    return null;
  }

  /// Alias pour la validation de la confirmation du mot de passe
  static String? validateConfirmPassword(String? value, String? password) {
    return validatePasswordConfirmation(value, password);
  }

  /// Valider un numéro de téléphone (optionnel)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Format Mali: +223XXXXXXXX ou XXXXXXXX (8 chiffres)
    final maliRegex = RegExp(r'^(\+223)?[0-9]{8}$');

    if (!maliRegex.hasMatch(cleaned)) {
      return 'Format invalide. Utilisez +223XXXXXXXX ou XXXXXXXX';
    }

    return null;
  }

  /// Valider un champ requis générique
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  /// Valider une URL (optionnel)
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }

    try {
      final uri = Uri.parse(value.trim());
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'URL invalide';
      }
      return null;
    } catch (e) {
      return 'URL invalide';
    }
  }

  /// Valider une longueur de texte
  static String? validateLength(
    String? value,
    String fieldName, {
    int? minLength,
    int? maxLength,
  }) {
    if (value == null || value.trim().isEmpty) {
      return null; // Laisser d'autres validateurs gérer les champs requis
    }

    final length = value.trim().length;

    if (minLength != null && length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }

    if (maxLength != null && length > maxLength) {
      return '$fieldName ne peut pas dépasser $maxLength caractères';
    }

    return null;
  }
}
