import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';

class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> cart;
  final Function(String cartId, String productId, int quantity)
      onQuantityChanged;
  final Function(String cartId, String productId) onRemoveItem;
  final Function(String cartId) onRemoveCart;
  final Set<String> updatingItems;

  const CartItemCard({
    super.key,
    required this.cart,
    required this.onQuantityChanged,
    required this.onRemoveItem,
    required this.onRemoveCart,
    required this.updatingItems,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartType = cart['cart_reference_type'] ?? 'unknown';
    final cartName = cart['cart_name'] ?? 'Panier';
    final products = cart['products'] as List<dynamic>? ?? [];
    final totalPrice = (cart['cart_total_price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Cart header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getCartTypeColor(cartType).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  _getCartTypeIcon(cartType),
                  color: _getCartTypeColor(cartType),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      Text(
                        _getCartTypeLabel(cartType),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getCartTypeColor(cartType),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatPrice(totalPrice),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getCartTypeColor(cartType),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onRemoveCart(cart['id']),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Supprimer le panier',
                ),
              ],
            ),
          ),

          // Products list
          if (products.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductItem(product, isDark);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucun produit dans ce panier',
                  style: TextStyle(
                    color: AppColors.getTextSecondary(isDark),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product, bool isDark) {
    final productId = product['product_id'] ?? product['id'] ?? '';
    final cartId = cart['cart_reference_id'] ?? cart['id'] ?? '';
    final itemKey = '${cartId}_$productId';
    final isUpdating = updatingItems.contains(itemKey);
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice =
        (product['total_price'] as num?)?.toDouble() ?? (price * quantity);

    return Row(
      children: [
        // Product image
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.getBackground(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product['image'] != null
                ? Image.network(
                    product['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.getTextSecondary(isDark),
                        size: 30,
                      );
                    },
                  )
                : Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.getTextSecondary(isDark),
                    size: 30,
                  ),
          ),
        ),

        const SizedBox(width: 12),

        // Product details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['name'] ?? 'Produit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(isDark),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    CurrencyUtils.formatPrice(price),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  if (product['unit'] != null) ...[
                    Text(
                      ' / ${product['unit']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${CurrencyUtils.formatPrice(totalPrice)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Quantity controls
        if (isUpdating)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrease button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onQuantityChanged(cartId, productId, quantity - 1);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getBackground(isDark),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Icon(
                    quantity > 1 ? Icons.remove : Icons.delete_outline,
                    size: 16,
                    color: quantity > 1
                        ? AppColors.getTextSecondary(isDark)
                        : AppColors.error,
                  ),
                ),
              ),

              // Quantity display
              Container(
                width: 50,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quantity.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Increase button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onQuantityChanged(cartId, productId, quantity + 1);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
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

  String _getCartTypeLabel(String type) {
    switch (type) {
      case 'personal':
        return 'Panier personnel';
      case 'recipe':
        return 'Panier recette';
      case 'preconfigured':
        return 'Panier préconfigué';
      default:
        return 'Panier';
    }
  }
}
