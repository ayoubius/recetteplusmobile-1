import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/utils/currency_utils.dart';

class ProductDetailDrawer extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onClose;
  final VoidCallback? onCartUpdated;

  const ProductDetailDrawer({
    super.key,
    required this.product,
    required this.onClose,
    this.onCartUpdated,
  });

  @override
  State<ProductDetailDrawer> createState() => _ProductDetailDrawerState();
}

class _ProductDetailDrawerState extends State<ProductDetailDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isAddingToCart = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _addToCart() async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      await CartService.addProductToPersonalCart(
        productId: widget.product['id'],
        quantity: _quantity,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product['name']} ajouté au panier'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: Colors.white,
              onPressed: () {
                widget.onCartUpdated?.call();
                _close();
              },
            ),
          ),
        );
        
        // Notifier la mise à jour du panier
        widget.onCartUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  void _updateQuantity(int newQuantity) {
    if (newQuantity > 0) {
      setState(() {
        _quantity = newQuantity;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInStock = widget.product['in_stock'] ?? true;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: AppColors.getCardBackground(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header avec bouton fermer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Détails du produit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        IconButton(
                          onPressed: _close,
                          icon: Icon(
                            Icons.close,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image du produit
                          Center(
                            child: Container(
                              width: double.infinity,
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: widget.product['image'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        widget.product['image'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 80,
                                            color: AppColors.primary,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 80,
                                      color: AppColors.primary,
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Nom et catégorie
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product['name'],
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.product['category'] ?? 'Autre',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Prix et unité
                          Row(
                            children: [
                              Text(
                                CurrencyUtils.formatPrice(widget.product['price']?.toDouble() ?? 0.0),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (widget.product['unit'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '/ ${widget.product['unit']}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Statut de disponibilité
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isInStock 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isInStock ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isInStock ? Icons.check_circle : Icons.cancel,
                                  color: isInStock ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isInStock ? 'En stock' : 'Rupture de stock',
                                  style: TextStyle(
                                    color: isInStock ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Description (si disponible)
                          if (widget.product['description'] != null) ...[
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.product['description'],
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.getTextSecondary(isDark),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Rating (si disponible)
                          if (widget.product['rating'] != null) ...[
                            Row(
                              children: [
                                Text(
                                  'Note: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < (widget.product['rating'] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 20,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${widget.product['rating']}/5)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Sélecteur de quantité
                          if (isInStock) ...[
                            Text(
                              'Quantité',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Bouton moins
                                GestureDetector(
                                  onTap: () => _updateQuantity(_quantity - 1),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.getBackground(isDark),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.getBorder(isDark),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                  ),
                                ),
                                
                                // Quantité
                                Container(
                                  width: 80,
                                  height: 40,
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                
                                // Bouton plus
                                GestureDetector(
                                  onTap: () => _updateQuantity(_quantity + 1),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Prix total
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.getTextSecondary(isDark),
                                      ),
                                    ),
                                    Text(
                                      CurrencyUtils.formatPrice(
                                        (widget.product['price']?.toDouble() ?? 0.0) * _quantity
                                      ),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Bouton d'ajout au panier
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getShadow(isDark),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isInStock && !_isAddingToCart ? _addToCart : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInStock ? AppColors.primary : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isAddingToCart
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_shopping_cart, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      isInStock 
                                          ? 'Ajouter au panier'
                                          : 'Produit indisponible',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
