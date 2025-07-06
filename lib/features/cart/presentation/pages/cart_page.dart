import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../shared/widgets/enhanced_snackbar.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/cart_summary_card.dart';
import '../widgets/cart_loading_widget.dart';
import 'order_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _subtotal = 0.0;
  double _deliveryFee = 1000.0; // Fixed delivery fee
  double _total = 0.0;

  // Update tracking
  final Set<String> _updatingItems = {};
  Timer? _refreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCartItems();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) {
        _loadCartItems(showLoading: false);
      }
    });
  }

  Future<void> _loadCartItems({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      final cartItems = await CartService.getMainCartItems();

      if (mounted) {
        setState(() {
          _cartItems = cartItems;
          _isLoading = false;
          _hasError = false;
        });

        _calculateTotals();

        if (showLoading) {
          _fadeController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _calculateTotals() {
    _subtotal = 0.0;

    for (final cart in _cartItems) {
      _subtotal += (cart['cart_total_price'] as num?)?.toDouble() ?? 0.0;
    }

    // Total sans TVA
    _total = _subtotal + _deliveryFee;
  }

  Future<void> _updateItemQuantity(
      String cartId, String productId, int newQuantity) async {
    final itemKey = '${cartId}_$productId';

    if (_updatingItems.contains(itemKey)) return;

    setState(() {
      _updatingItems.add(itemKey);
    });

    try {
      if (newQuantity <= 0) {
        await _removeItem(cartId, productId);
      } else {
        await CartService.updateProductQuantity(
          cartId: cartId,
          productId: productId,
          quantity: newQuantity,
        );

        HapticFeedback.lightImpact();
        EnhancedSnackBar.showSuccess(
          context,
          'Quantité mise à jour',
          duration: const Duration(seconds: 1),
        );

        await _loadCartItems(showLoading: false);
      }
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors de la mise à jour: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(itemKey);
        });
      }
    }
  }

  Future<void> _removeItem(String cartId, String productId) async {
    try {
      await CartService.removeProductFromCart(
        cartId: cartId,
        productId: productId,
      );

      HapticFeedback.mediumImpact();
      EnhancedSnackBar.showSuccess(
        context,
        'Produit retiré du panier',
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo functionality
          },
        ),
      );

      await _loadCartItems(showLoading: false);
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors de la suppression: $e',
      );
    }
  }

  Future<void> _removeCart(String cartId) async {
    try {
      await CartService.removeFromMainCart(cartId);

      HapticFeedback.mediumImpact();
      EnhancedSnackBar.showSuccess(
        context,
        'Panier supprimé',
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo functionality
          },
        ),
      );

      await _loadCartItems(showLoading: false);
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors de la suppression: $e',
      );
    }
  }

  Future<void> _clearAllCarts() async {
    final confirmed = await _showClearConfirmationDialog();
    if (!confirmed) return;

    try {
      await CartService.clearMainCart();

      HapticFeedback.heavyImpact();
      EnhancedSnackBar.showSuccess(
        context,
        'Tous les paniers ont été vidés',
      );

      // Rafraîchissement automatique après vidage
      await _loadCartItems(showLoading: true);
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors du vidage: $e',
      );
    }
  }

  Future<bool> _showClearConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vider le panier'),
            content: const Text(
                'Êtes-vous sûr de vouloir supprimer tous les articles de votre panier ?'),
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
        ) ??
        false;
  }

  void _proceedToCheckout() {
    if (_cartItems.isEmpty) {
      EnhancedSnackBar.showWarning(
        context,
        'Votre panier est vide',
      );
      return;
    }

    // Navigate to order page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrderPage(),
      ),
    ).then((_) {
      // Refresh cart when returning from order page
      _loadCartItems(showLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(
          'Mon Panier',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.getSurface(isDark),
        elevation: 0,
        actions: [
          if (_cartItems.isNotEmpty)
            IconButton(
              onPressed: _clearAllCarts,
              icon: Icon(
                Icons.delete_sweep,
                color: AppColors.error,
              ),
              tooltip: 'Vider le panier',
            ),
          IconButton(
            onPressed: () => _loadCartItems(),
            icon: Icon(
              Icons.refresh,
              color: AppColors.getTextSecondary(isDark),
            ),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(isDark),
      bottomNavigationBar:
          _cartItems.isNotEmpty ? _buildCheckoutBar(isDark) : null,
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const CartLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorState(isDark);
    }

    if (_cartItems.isEmpty) {
      return _buildEmptyCart(isDark);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _loadCartItems,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Cart summary (sans TVA)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CartSummaryCard(
                    itemsCount: _cartItems.fold<int>(
                      0,
                      (sum, cart) =>
                          sum + ((cart['items_count'] as num?)?.toInt() ?? 0),
                    ),
                    subtotal: _subtotal,
                    deliveryFee: _deliveryFee,
                    total: _total,
                  ),
                ),
              ),

              // Cart items
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cart = _cartItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: CartItemCard(
                        cart: cart,
                        onQuantityChanged: _updateItemQuantity,
                        onRemoveItem: _removeItem,
                        onRemoveCart: _removeCart,
                        updatingItems: _updatingItems,
                      ),
                    );
                  },
                  childCount: _cartItems.length,
                ),
              ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.error.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Impossible de charger votre panier.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadCartItems,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  CurrencyUtils.formatPrice(_total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Passer la commande',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
            size: 80,
            color: AppColors.getTextSecondary(isDark),
          ),
          const SizedBox(height: 24),
          Text(
            'Votre panier est vide',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ajoutez des articles à votre panier pour commencer vos achats.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/main',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Continuer vos achats'),
          ),
        ],
      ),
    );
  }
}
