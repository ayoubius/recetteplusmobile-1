class CurrencyUtils {
  static String formatPrice(double price) {
    if (price == 0) return '0 FCFA';

    // Format with thousands separator
    final formattedPrice = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );

    return '$formattedPrice FCFA';
  }

  static String formatPriceCompact(double price) {
    if (price == 0) return '0';

    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    }

    return price.toStringAsFixed(0);
  }

  static double parsePrice(String priceString) {
    // Remove FCFA and spaces, then parse
    final cleanString = priceString
        .replaceAll('FCFA', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    return double.tryParse(cleanString) ?? 0.0;
  }
}
