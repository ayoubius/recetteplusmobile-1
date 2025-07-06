import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/services/delivery_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../shared/widgets/enhanced_snackbar.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/enhanced_location_picker.dart';

class EnhancedOrderPage extends StatefulWidget {
  const EnhancedOrderPage({super.key});

  @override
  State<EnhancedOrderPage> createState() => _EnhancedOrderPageState();
}

class _EnhancedOrderPageState extends State<EnhancedOrderPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  // State variables
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  double _subtotal = 0.0;
  double _deliveryFee = 1000.0;
  double _total = 0.0;

  // Location data
  Map<String, dynamic>? _locationData;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCartData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
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

  Future<void> _loadCartData() async {
    try {
      final cartItems = await CartService.getMainCartItems();

      if (mounted) {
        setState(() {
          _cartItems = cartItems;
          _isLoading = false;
        });

        _calculateTotals();
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        EnhancedSnackBar.showError(
          context,
          'Erreur lors du chargement du panier: $e',
        );
      }
    }
  }

  void _calculateTotals() {
    _subtotal = 0.0;

    for (final cart in _cartItems) {
      _subtotal += (cart['cart_total_price'] as num?)?.toDouble() ?? 0.0;
    }

    _total = _subtotal + _deliveryFee;
  }

  void _onLocationSelected(Map<String, dynamic> locationData) {
    setState(() {
      _locationData = locationData;
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_locationData == null) {
      EnhancedSnackBar.showWarning(
        context,
        'Veuillez sélectionner une adresse de livraison',
      );
      return;
    }

    if (_cartItems.isEmpty) {
      EnhancedSnackBar.showWarning(
        context,
        'Votre panier est vide',
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Prepare order items
      final orderItems = <Map<String, dynamic>>[];

      for (final cart in _cartItems) {
        final products = cart['products'] as List<dynamic>? ?? [];
        for (final product in products) {
          orderItems.add({
            'product_id': product['product_id'] ?? product['id'],
            'name': product['name'],
            'quantity': product['quantity'],
            'price': product['price'],
            'total_price': product['total_price'],
          });
        }
      }

      // Prepare enhanced delivery data
      final deliveryData = {
        'delivery_address': _locationData!['full_address'],
        'delivery_notes': _notesController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'street_address': _locationData!['street_address'],
        'district': _locationData!['district'],
        'city': _locationData!['city'],
        'landmark': _locationData!['landmark'],
        'delivery_latitude': _locationData!['latitude'],
        'delivery_longitude': _locationData!['longitude'],
        'google_maps_link': _locationData!['google_maps_link'],
      };

      // Create order with enhanced location data
      final order = await DeliveryService.createOrderWithDelivery(
        userId: 'will_be_replaced_with_actual_user_id',
        totalAmount: _subtotal,
        items: orderItems,
        deliveryAddress: deliveryData['delivery_address'],
        deliveryNotes: deliveryData['delivery_notes']?.isNotEmpty == true
            ? deliveryData['delivery_notes']
            : null,
        additionalData: deliveryData,
      );

      if (order != null) {
        // Save order to db.json format
        await _saveOrderToDatabase(order.toJson(), deliveryData);

        // Clear cart after successful order
        await CartService.clearMainCart();

        HapticFeedback.heavyImpact();

        if (mounted) {
          // Show success dialog
          _showOrderSuccessDialog(order.toJson());
        }
      }
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors de la commande: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  Future<void> _saveOrderToDatabase(
      Map<String, dynamic> order, Map<String, dynamic> deliveryData) async {
    // This would save to your db.json in the specified format
    final orderData = {
      'id': order['id'],
      'user_id': order['user_id'],
      'total_amount': order['total_amount'],
      'delivery_fee': order['delivery_fee'],
      'status': order['status'],
      'created_at': order['created_at'],
      'qr_code': order['qr_code'],
      'items': order['items'],
      'delivery_info': {
        'full_address': deliveryData['delivery_address'],
        'street_address': deliveryData['street_address'],
        'district': deliveryData['district'],
        'city': deliveryData['city'],
        'landmark': deliveryData['landmark'],
        'phone_number': deliveryData['phone_number'],
        'delivery_notes': deliveryData['delivery_notes'],
        'coordinates': {
          'latitude': deliveryData['delivery_latitude'],
          'longitude': deliveryData['delivery_longitude'],
        },
        'google_maps_link': deliveryData['google_maps_link'],
      },
    };

    // TODO: Implement actual saving to db.json
    print('💾 Saving order to database: $orderData');
  }

  void _showOrderSuccessDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Commande confirmée !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Votre commande #${order['qr_code']} a été passée avec succès.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            Text(
              'Total: ${CurrencyUtils.formatPrice(order['total_amount'])}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (_locationData?['google_maps_link'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adresse de livraison enregistrée avec GPS',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/main',
                (route) => false,
              );
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        backgroundColor: AppColors.getSurface(isDark),
        elevation: 0,
      ),
      body: _isLoading ? _buildLoadingState() : _buildOrderForm(isDark),
      bottomNavigationBar: !_isLoading ? _buildPlaceOrderButton(isDark) : null,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement de votre commande...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderForm(bool isDark) {
    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Votre panier est vide',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des articles pour passer une commande',
              style: TextStyle(
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retour au panier'),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                OrderSummaryWidget(
                  cartItems: _cartItems,
                  subtotal: _subtotal,
                  deliveryFee: _deliveryFee,
                  total: _total,
                ),

                const SizedBox(height: 24),

                // Enhanced Location Picker
                EnhancedLocationPicker(
                  onLocationSelected: _onLocationSelected,
                ),

                const SizedBox(height: 24),

                // Phone Number
                Container(
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.phone,
                              color: AppColors.secondary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone *',
                          hintText: 'Ex: 77123456',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.getBackground(isDark),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le numéro de téléphone est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Instructions de livraison (optionnel)',
                          hintText: 'Ex: Sonner à la porte, 2ème étage...',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.getBackground(isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(bool isDark) {
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
                  'Total à payer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  CurrencyUtils.formatPrice(_total),
                  style: const TextStyle(
                    fontSize: 20,
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
                onPressed:
                    _isPlacingOrder || _cartItems.isEmpty ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isPlacingOrder
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirmer la commande',
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
}
