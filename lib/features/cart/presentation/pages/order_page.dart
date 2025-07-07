import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/delivery_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../shared/widgets/enhanced_snackbar.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/delivery_address_form.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();

  // State variables
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  bool _isDetectingLocation = false;
  double _subtotal = 0.0;
  double _deliveryFee = 1000.0;
  double _total = 0.0;

  // Location data with Google Maps integration (selon db.json)
  double? _latitude;
  double? _longitude;
  String? _detectedAddress;
  String? _googleMapsLink;

  // Reference to the delivery address form for getting enriched data
  final GlobalKey<DeliveryAddressFormState> _deliveryFormKey =
      GlobalKey<DeliveryAddressFormState>();

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
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
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

  Future<void> _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      // Check and request location permission
      final hasPermission =
          await LocationService.checkAndRequestLocationPermission();

      if (!hasPermission) {
        EnhancedSnackBar.showWarning(
          context,
          'Permission de localisation requise',
        );
        setState(() {
          _isDetectingLocation = false;
        });
        return;
      }

      // Get current position with complete details including Google Maps link
      final positionDetails =
          await LocationService.getCurrentPositionWithDetails();

      if (positionDetails != null) {
        _latitude = positionDetails['latitude'];
        _longitude = positionDetails['longitude'];
        _googleMapsLink = positionDetails['google_maps_link'];

        // Get address from coordinates
        final address = await LocationService.getAddressFromCoordinates(
          _latitude!,
          _longitude!,
        );

        if (address != null) {
          setState(() {
            _detectedAddress = address;
            _addressController.text = address;
          });

          HapticFeedback.lightImpact();
          EnhancedSnackBar.showSuccess(
            context,
            'Localisation détectée avec succès',
          );
        }
      }
    } catch (e) {
      EnhancedSnackBar.showError(
        context,
        'Erreur lors de la détection de localisation: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
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

      // Get enriched address data from the form (selon db.json structure)
      final enrichedAddressData =
          _deliveryFormKey.currentState?.getEnrichedAddressData() ??
              {
                'delivery_address': _addressController.text.trim(),
                'delivery_notes': _notesController.text.trim(),
                'phone_number': _phoneController.text.trim(),
                'latitude': _latitude,
                'longitude': _longitude,
                'google_maps_link': _googleMapsLink,
              };

      // Ensure we have GPS coordinates and Google Maps link
      if (_latitude != null && _longitude != null) {
        enrichedAddressData['latitude'] = _latitude;
        enrichedAddressData['longitude'] = _longitude;
        enrichedAddressData['google_maps_link'] = _googleMapsLink ??
            LocationService.generateGoogleMapsLink(_latitude!, _longitude!);
      }

      // Create order with delivery using enriched data including GPS and Google Maps
      final order = await DeliveryService.createOrderWithDelivery(
        userId:
            'will_be_replaced_with_actual_user_id', // This will be replaced in the service
        totalAmount: _subtotal,
        items: orderItems,
        deliveryAddress: enrichedAddressData['delivery_address'],
        deliveryNotes: enrichedAddressData['delivery_notes']?.isNotEmpty == true
            ? enrichedAddressData['delivery_notes']
            : null,
        additionalData: enrichedAddressData,
      );

      if (order != null) {
        // Clear cart after successful order
        await CartService.clearMainCart();

        HapticFeedback.heavyImpact();

        if (mounted) {
          // Show success dialog with GPS and Google Maps info
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
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Localisation GPS enregistrée',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Total: ${CurrencyUtils.formatPrice(order['total_amount'])}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
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

                // Delivery Address Section with enhanced form including GPS and Google Maps
                DeliveryAddressForm(
                  key: _deliveryFormKey,
                  addressController: _addressController,
                  notesController: _notesController,
                  phoneController: _phoneController,
                  isDetectingLocation: _isDetectingLocation,
                  onDetectLocation: _detectLocation,
                  detectedAddress: _detectedAddress,
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
