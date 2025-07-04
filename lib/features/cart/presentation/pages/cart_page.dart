import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/services/delivery_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/utils/currency_utils.dart';
import 'dart:async';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  double _subtotal = 0.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadCartData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCartData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (kDebugMode) {
        print('🔄 Chargement des données du panier...');
      }

      // Récupérer les items du panier depuis la base de données
      final cartItems = await CartService.getMainCartItems();
      double subtotal = 0.0;

      if (kDebugMode) {
        print('📦 ${cartItems.length} items trouvés dans le panier');
      }

      // Calculer correctement le sous-total
      for (final item in cartItems) {
        final itemTotal = (item['cart_total_price'] as num?)?.toDouble() ?? 0.0;
        subtotal += itemTotal;

        if (kDebugMode) {
          print('💰 Item: ${item['cart_name']} - Prix: $itemTotal FCFA');
        }
      }

      if (mounted) {
        setState(() {
          _cartItems = cartItems;
          _subtotal = subtotal;
          _isLoading = false;
        });

        if (!silent) {
          _animationController.forward();
        }

        if (kDebugMode) {
          print(
              '✅ Panier chargé: ${cartItems.length} items, Total: $subtotal FCFA');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du chargement du panier: $e');
      }

      if (mounted) {
        setState(() {
          _cartItems = [];
          _subtotal = 0.0;
          _isLoading = false;
        });

        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du chargement du panier: $e'),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: 'Réessayer',
                onPressed: () => _loadCartData(),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Suppression de l\'item: $itemId');
      }

      await CartService.removeFromMainCart(itemId);
      await _loadCartData();

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article supprimé du panier'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression item: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearCart() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text('Êtes-vous sûr de vouloir vider votre panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      try {
        if (kDebugMode) {
          print('🧹 Vidage du panier...');
        }

        await CartService.clearMainCart();
        await _loadCartData();

        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Panier vidé avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur vidage panier: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showCheckoutDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckoutDrawer(
        subtotal: _subtotal,
        cartItems: _cartItems,
        onOrderCompleted: () {
          Navigator.pop(context);
          _loadCartData();
        },
      ),
    );
  }

  void _showCartItemDetails(Map<String, dynamic> cartItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CartItemDetailsDrawer(cartItem: cartItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(
            'Mon Panier${_cartItems.isNotEmpty ? ' (${_cartItems.length})' : ''}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearCart,
              tooltip: 'Vider le panier',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCartData(),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement du panier...'),
                ],
              ),
            )
          : _cartItems.isEmpty
              ? _buildEmptyCart(isDark)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Informations du panier
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: AppColors.primary.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_cartItems.length} panier${_cartItems.length > 1 ? 's' : ''} dans votre commande',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                  ),
                                  Text(
                                    'Total: ${CurrencyUtils.formatPrice(_subtotal)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Liste des articles
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            return _buildCartItem(item, isDark, index);
                          },
                        ),
                      ),

                      // Résumé et bouton de commande
                      _buildCartSummary(isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: AppColors.getTextSecondary(isDark),
          ),
          const SizedBox(height: 24),
          Text(
            'Votre panier est vide',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Découvrez nos délicieuses recettes et\najoutez des ingrédients à votre panier',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Découvrir les recettes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, bool isDark, int index) {
    final products = item['products'] as List<dynamic>? ?? [];
    final hasProducts = products.isNotEmpty;
    final cartName = item['cart_name'] ?? 'Panier ${index + 1}';
    final itemsCount = item['items_count'] ?? 0;
    final totalPrice = (item['cart_total_price'] as num?)?.toDouble() ?? 0.0;

    // Obtenir l'image du premier produit ou une image par défaut
    String? imageUrl;
    if (hasProducts && products.first['image'] != null) {
      imageUrl = products.first['image'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: hasProducts ? () => _showCartItemDetails(item) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // En-tête du panier
              Row(
                children: [
                  // Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.shopping_basket,
                                  color: AppColors.primary,
                                  size: 32,
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                            ),
                          )
                        : Icon(
                            _getCartTypeIcon(item['cart_reference_type']),
                            color: AppColors.primary,
                            size: 32,
                          ),
                  ),

                  const SizedBox(width: 16),

                  // Informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cartName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildCartTypeChip(
                                item['cart_reference_type'], isDark),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemsCount article${itemsCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                        if (hasProducts && products.length > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${products.length} produits différents',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          CurrencyUtils.formatPrice(totalPrice),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Boutons d'action
                  Column(
                    children: [
                      if (hasProducts)
                        IconButton(
                          onPressed: () => _showCartItemDetails(item),
                          icon: Icon(
                            Icons.visibility_outlined,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Voir détails',
                        ),
                      IconButton(
                        onPressed: () => _removeFromCart(item['id']),
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ),
                ],
              ),

              // Aperçu des produits (si disponibles)
              if (hasProducts && products.length > 1) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contient ${products.length} produits différents',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                    Text(
                      'Voir détails',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCartTypeIcon(String? cartType) {
    switch (cartType) {
      case 'personal':
        return Icons.person;
      case 'recipe':
        return Icons.restaurant_menu;
      case 'preconfigured':
        return Icons.inventory;
      default:
        return Icons.shopping_basket;
    }
  }

  Widget _buildCartTypeChip(String? cartType, bool isDark) {
    String label;
    Color color;

    switch (cartType) {
      case 'personal':
        label = 'Personnel';
        color = Colors.blue;
        break;
      case 'recipe':
        label = 'Recette';
        color = Colors.green;
        break;
      case 'preconfigured':
        label = 'Pack';
        color = Colors.orange;
        break;
      default:
        label = 'Panier';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCartSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sous-total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sous-total',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                Text(
                  CurrencyUtils.formatPrice(_subtotal),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Note sur les frais de livraison
            Text(
              'Frais de livraison: 1 000 FCFA',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextSecondary(isDark),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Bouton commander
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessingOrder ? null : _showCheckoutDrawer,
                icon: _isProcessingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(_isProcessingOrder ? 'Traitement...' : 'Commander'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour afficher les détails d'un panier
class CartItemDetailsDrawer extends StatelessWidget {
  final Map<String, dynamic> cartItem;

  const CartItemDetailsDrawer({
    super.key,
    required this.cartItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = cartItem['products'] as List<dynamic>? ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getTextSecondary(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cartItem['cart_name'] ?? 'Détails du panier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Liste des produits
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun produit dans ce panier',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildProductItem(product, isDark);
                    },
                  ),
          ),

          // Résumé
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(isDark),
              border: Border(
                top: BorderSide(color: AppColors.getBorder(isDark)),
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total du panier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatPrice(
                      (cartItem['cart_total_price'] as num?)?.toDouble() ?? 0.0,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product, bool isDark) {
    final quantity = product['quantity'] ?? 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice =
        (product['total_price'] as num?)?.toDouble() ?? (price * quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          // Image du produit
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: product['image'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.shopping_basket,
                          color: AppColors.primary,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.shopping_basket,
                    color: AppColors.primary,
                    size: 24,
                  ),
          ),

          const SizedBox(width: 12),

          // Informations du produit
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
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity ${product['unit'] ?? 'pièce'}${quantity > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${CurrencyUtils.formatPrice(price)} / ${product['unit'] ?? 'pièce'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),

          // Prix total
          Text(
            CurrencyUtils.formatPrice(totalPrice),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget pour le checkout avec système de localisation (géolocalisation uniquement)
class CheckoutDrawer extends StatefulWidget {
  final double subtotal;
  final List<Map<String, dynamic>> cartItems;
  final VoidCallback onOrderCompleted;

  const CheckoutDrawer({
    super.key,
    required this.subtotal,
    required this.cartItems,
    required this.onOrderCompleted,
  });

  @override
  State<CheckoutDrawer> createState() => _CheckoutDrawerState();
}

class _CheckoutDrawerState extends State<CheckoutDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  bool _isProcessingOrder = false;
  bool _isLoadingLocation = false;
  double _deliveryFee = 1000.0;
  double _total = 0.0;

  // Données de localisation
  Position? _currentPosition;
  AddressInfo? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _total = widget.subtotal + _deliveryFee;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Vérifier les permissions
      final hasPermission =
          await LocationService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission requise'),
              content: const Text(
                'L\'accès à la localisation est nécessaire pour déterminer votre adresse de livraison. Voulez-vous ouvrir les paramètres ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Paramètres'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await LocationService.openAppSettings();
          }
        }
        return;
      }

      // Obtenir la position
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Impossible d\'obtenir votre position');
      }

      // Obtenir l\'adresse
      final addressInfo =
          await LocationService.getDetailedAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (addressInfo == null) {
        throw Exception('Impossible de déterminer votre adresse');
      }

      setState(() {
        _currentPosition = position;
        _selectedAddress = addressInfo;
      });

      if (kDebugMode) {
        print(
            '📍 Position actuelle: ${position.latitude}, ${position.longitude}');
        print('🏠 Adresse: ${addressInfo.shortAddress}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position détectée avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur géolocalisation: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de géolocalisation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _processOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Veuillez utiliser votre position actuelle pour la livraison'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (kDebugMode) {
        print('🛒 Traitement de la commande...');
        print('📦 ${widget.cartItems.length} paniers dans la commande');
        print('💰 Montant total: ${widget.subtotal} FCFA');
        print('📍 Adresse: ${_selectedAddress!.displayName}');
        print(
            '🗺️ Coordonnées: ${_selectedAddress!.latitude}, ${_selectedAddress!.longitude}');
      }

      // Préparer les items pour la commande
      final orderItems = widget.cartItems
          .map((item) => {
                'cart_name': item['cart_name'],
                'items_count': item['items_count'],
                'cart_total_price': item['cart_total_price'],
                'products': item['products'],
              })
          .toList();

      // Préparer les données additionnelles avec coordonnées GPS
      final additionalData = <String, dynamic>{
        'delivery_latitude': _selectedAddress!.latitude,
        'delivery_longitude': _selectedAddress!.longitude,
        'address_info': _selectedAddress!.toJson(),
      };

      // Créer la commande avec les coordonnées GPS
      final order = await DeliveryService.createOrderWithDelivery(
        userId: user.id,
        totalAmount: widget.subtotal,
        items: orderItems,
        deliveryAddress: _selectedAddress!.displayName,
        deliveryNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        additionalData: additionalData,
      );

      if (order != null && mounted) {
        if (kDebugMode) {
          print('✅ Commande créée avec succès: ${order.id}');
        }

        // Vider le panier après commande réussie
        await CartService.clearMainCart();

        // Afficher le succès
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Commande passée avec succès ! N° ${order.id.substring(0, 8)}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );

        // Fermer le drawer et rafraîchir
        widget.onOrderCompleted();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la commande: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la commande: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getTextSecondary(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Finaliser la commande',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Contenu scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section localisation
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Adresse de livraison',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bouton géolocalisation
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: InkWell(
                        onTap: _isLoadingLocation ? null : _getCurrentLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (_isLoadingLocation)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.my_location,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isLoadingLocation
                                          ? 'Localisation en cours...'
                                          : 'Utiliser ma position actuelle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (_selectedAddress != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedAddress!.shortAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextSecondary(
                                              isDark),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Affichage de l'adresse sélectionnée
                    if (_selectedAddress != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Adresse confirmée',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedAddress!.shortAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            if (_currentPosition != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Coordonnées: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Notes de livraison
                    Text(
                      'Notes de livraison (optionnel)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Instructions spéciales pour le livreur',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 32),

                    // Résumé de la commande
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getCardBackground(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getBorder(isDark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Résumé de la commande',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sous-total',
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                              Text(
                                CurrencyUtils.formatPrice(widget.subtotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Frais de livraison',
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                              Text(
                                CurrencyUtils.formatPrice(_deliveryFee),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Livraison estimée: 45 minutes',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                              Text(
                                CurrencyUtils.formatPrice(_total),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bouton de commande fixe en bas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(isDark),
              border: Border(
                top: BorderSide(color: AppColors.getBorder(isDark)),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessingOrder ? null : _processOrder,
                  icon: _isProcessingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _isProcessingOrder
                        ? 'Traitement en cours...'
                        : 'Confirmer la commande',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
