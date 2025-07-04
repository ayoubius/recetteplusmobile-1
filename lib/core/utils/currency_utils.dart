class CurrencyUtils {
  /// Formate un prix en FCFA
  static String formatPrice(double price) {
    if (price == 0) return '0 FCFA';

    // Arrondir à l'entier le plus proche
    final roundedPrice = price.round();

    // Formater avec des espaces pour les milliers
    final priceString = roundedPrice.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(priceString[i]);
    }

    return '${buffer.toString()} FCFA';
  }

  /// Formate un prix avec décimales si nécessaire
  static String formatPriceWithDecimals(double price) {
    if (price == 0) return '0 FCFA';

    // Si le prix est un entier, ne pas afficher les décimales
    if (price == price.roundToDouble()) {
      return formatPrice(price);
    }

    // Sinon, afficher avec 2 décimales maximum
    final formattedPrice = price.toStringAsFixed(2);
    return '$formattedPrice FCFA';
  }

  /// Parse un prix depuis une chaîne
  static double parsePrice(String priceString) {
    try {
      // Supprimer "FCFA" et les espaces
      final cleanString =
          priceString.replaceAll('FCFA', '').replaceAll(' ', '').trim();

      return double.parse(cleanString);
    } catch (e) {
      return 0.0;
    }
  }

  /// Calcule une remise
  static double calculateDiscount(
      double originalPrice, double discountPercent) {
    return originalPrice * (discountPercent / 100);
  }

  /// Calcule le prix après remise
  static double applyDiscount(double originalPrice, double discountPercent) {
    final discount = calculateDiscount(originalPrice, discountPercent);
    return originalPrice - discount;
  }

  /// Formate un pourcentage de remise
  static String formatDiscount(double discountPercent) {
    if (discountPercent == 0) return '';
    return '-${discountPercent.toStringAsFixed(0)}%';
  }
}
