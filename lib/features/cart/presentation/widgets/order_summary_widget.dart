import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';

class OrderSummaryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const OrderSummaryWidget({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate total items
    int totalItems = 0;
    for (final cart in cartItems) {
      totalItems += (cart['items_count'] as num?)?.toInt() ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Résumé de commande',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    Text(
                      '$totalItems article${totalItems > 1 ? 's' : ''} • ${cartItems.length} panier${cartItems.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Cart items summary
          ...cartItems.map((cart) => _buildCartSummary(cart, isDark)),

          const SizedBox(height: 16),
          Divider(color: AppColors.getBorder(isDark)),
          const SizedBox(height: 16),

          // Pricing breakdown
          _buildPriceRow('Sous-total', subtotal, isDark),
          const SizedBox(height: 8),
          _buildPriceRow('Frais de livraison', deliveryFee, isDark),

          const SizedBox(height: 16),
          Divider(color: AppColors.getBorder(isDark)),
          const SizedBox(height: 16),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              Text(
                CurrencyUtils.formatPrice(total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(Map<String, dynamic> cart, bool isDark) {
    final cartName = cart['cart_name'] ?? 'Panier';
    final cartPrice = (cart['cart_total_price'] as num?)?.toDouble() ?? 0.0;
    final itemsCount = (cart['items_count'] as num?)?.toInt() ?? 0;
    final cartType = cart['cart_reference_type'] ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getBorder(isDark),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getCartTypeIcon(cartType),
            color: _getCartTypeColor(cartType),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  '$itemsCount article${itemsCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyUtils.formatPrice(cartPrice),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _getCartTypeColor(cartType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        Text(
          CurrencyUtils.formatPrice(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
      ],
    );
  }

  Color _getCartTypeColor(String type) {
    switch (type) {
      case 'personal':
        return AppColors.primary;
      case 'recipe':
        return AppColors.secondary;
      case 'preconfigured':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getCartTypeIcon(String type) {
    switch (type) {
      case 'personal':
        return Icons.shopping_bag;
      case 'recipe':
        return Icons.restaurant_menu;
      case 'preconfigured':
        return Icons.inventory;
      default:
        return Icons.shopping_cart;
    }
  }
}
