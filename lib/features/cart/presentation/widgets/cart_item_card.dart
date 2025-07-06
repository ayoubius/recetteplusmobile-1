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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
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
          // Cart header - responsive
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: _getCartTypeColor(cartType).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _buildCartHeader(
                isDark, isSmallScreen, cartType, cartName, totalPrice),
          ),

          // Products list
          if (products.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              itemCount: products.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductItem(product, isDark, isSmallScreen);
              },
            )
          else
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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

  Widget _buildCartHeader(bool isDark, bool isSmallScreen, String cartType,
      String cartName, double totalPrice) {
    if (isSmallScreen) {
      // Stack layout for small screens
      return Column(
        children: [
          Row(
            children: [
              Icon(
                _getCartTypeIcon(cartType),
                color: _getCartTypeColor(cartType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getCartTypeLabel(cartType),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getCartTypeColor(cartType),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onRemoveCart(cart['id']),
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
                tooltip: 'Supprimer le panier',
                iconSize: 20,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.formatPrice(totalPrice),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getCartTypeColor(cartType),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Row layout for normal screens
      return Row(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      );
    }
  }

  Widget _buildProductItem(
      Map<String, dynamic> product, bool isDark, bool isSmallScreen) {
    final productId = product['product_id'] ?? product['id'] ?? '';
    final cartId = cart['cart_reference_id'] ?? cart['id'] ?? '';
    final itemKey = '${cartId}_$productId';
    final isUpdating = updatingItems.contains(itemKey);
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice =
        (product['total_price'] as num?)?.toDouble() ?? (price * quantity);

    if (isSmallScreen) {
      // Column layout for small screens
      return Column(
        children: [
          Row(
            children: [
              // Product image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.getBackground(isDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: product['image'] != null
                      ? Image.network(
                          product['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.getTextSecondary(isDark),
                              size: 24,
                            );
                          },
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.getTextSecondary(isDark),
                          size: 24,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatPrice(price),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                    Text(
                      'Total: ${CurrencyUtils.formatPrice(totalPrice)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quantity controls on separate row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildQuantityControls(
                cartId,
                productId,
                quantity,
                isUpdating,
                isDark,
                isSmallScreen,
              ),
            ],
          ),
        ],
      );
    } else {
      // Row layout for normal screens
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
                    Flexible(
                      child: Text(
                        CurrencyUtils.formatPrice(price),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                        ),
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
          _buildQuantityControls(
            cartId,
            productId,
            quantity,
            isUpdating,
            isDark,
            isSmallScreen,
          ),
        ],
      );
    }
  }

  Widget _buildQuantityControls(
    String cartId,
    String productId,
    int quantity,
    bool isUpdating,
    bool isDark,
    bool isSmallScreen,
  ) {
    final buttonSize = isSmallScreen ? 28.0 : 32.0;
    final quantityWidth = isSmallScreen ? 40.0 : 50.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    final fontSize = isSmallScreen ? 12.0 : 14.0;

    if (isUpdating) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decrease button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onQuantityChanged(cartId, productId, quantity - 1);
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: AppColors.getBackground(isDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Icon(
              quantity > 1 ? Icons.remove : Icons.delete_outline,
              size: iconSize,
              color: quantity > 1
                  ? AppColors.getTextSecondary(isDark)
                  : AppColors.error,
            ),
          ),
        ),
        // Quantity display
        Container(
          width: quantityWidth,
          height: buttonSize,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            quantity.toString(),
            style: TextStyle(
              fontSize: fontSize,
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
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add,
              size: iconSize,
              color: Colors.white,
            ),
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

  String _getCartTypeLabel(String type) {
    switch (type) {
      case 'personal':
        return 'Panier personnel';
      case 'recipe':
        return 'Panier recette';
      case 'preconfigured':
        return 'Panier préconfigé';
      default:
        return 'Panier';
    }
  }
}
