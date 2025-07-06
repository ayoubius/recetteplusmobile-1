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

  // Location data
  double? _latitude;
  double? _longitude;
  String? _detectedAddress;

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

      // Get current position
      final position = await LocationService.getCurrentPosition();

      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;

        // Get address from coordinates
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
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

      // Get enriched address data from the form
      final enrichedAddressData =
          _deliveryFormKey.currentState?.getEnrichedAddressData() ??
              {
                'delivery_address': _addressController.text.trim(),
                'delivery_notes': _notesController.text.trim(),
                'phone_number': _phoneController.text.trim(),
              };

      // Add GPS coordinates if available
      if (_latitude != null && _longitude != null) {
        enrichedAddressData['delivery_latitude'] = _latitude;
        enrichedAddressData['delivery_longitude'] = _longitude;
      }

      // Create order with delivery using enriched data
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

                // Delivery Address Section with enhanced form
                EnhancedDeliveryAddressForm(
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

// Enhanced delivery address form with better location handling
class EnhancedDeliveryAddressForm extends StatefulWidget {
  final TextEditingController addressController;
  final TextEditingController notesController;
  final TextEditingController phoneController;
  final bool isDetectingLocation;
  final VoidCallback onDetectLocation;
  final String? detectedAddress;

  const EnhancedDeliveryAddressForm({
    super.key,
    required this.addressController,
    required this.notesController,
    required this.phoneController,
    required this.isDetectingLocation,
    required this.onDetectLocation,
    this.detectedAddress,
  });

  @override
  State<EnhancedDeliveryAddressForm> createState() =>
      _EnhancedDeliveryAddressFormState();
}

class _EnhancedDeliveryAddressFormState
    extends State<EnhancedDeliveryAddressForm> {
  final TextEditingController _cityController =
      TextEditingController(text: 'Bamako');
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _cityController.dispose();
    _districtController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  // Method to get enriched address data
  Map<String, dynamic> getEnrichedAddressData() {
    return {
      'delivery_address': widget.addressController.text.trim(),
      'delivery_notes': widget.notesController.text.trim(),
      'phone_number': widget.phoneController.text.trim(),
      'delivery_city': _cityController.text.trim(),
      'delivery_district': _districtController.text.trim(),
      'delivery_landmark': _landmarkController.text.trim(),
      if (_latitude != null && _longitude != null) ...{
        'delivery_latitude': _latitude,
        'delivery_longitude': _longitude,
      },
    };
  }

  Future<void> _detectLocationWithDetails() async {
    try {
      // Check permissions
      final hasPermission =
          await LocationService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        _showPermissionDialog();
        return;
      }

      // Get position
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showErrorSnackBar('Impossible d\'obtenir votre position');
        return;
      }

      // Get detailed address
      final addressInfo =
          await LocationService.getDetailedAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (addressInfo != null) {
        setState(() {
          _latitude = addressInfo.latitude;
          _longitude = addressInfo.longitude;

          // Fill form fields
          widget.addressController.text = addressInfo.shortAddress;
          _cityController.text = addressInfo.city ?? 'Bamako';
          _districtController.text =
              addressInfo.neighbourhood ?? addressInfo.suburb ?? '';

          // Extract landmark from display name if available
          if (addressInfo.displayName.contains(',')) {
            final parts = addressInfo.displayName.split(',');
            if (parts.length > 2) {
              _landmarkController.text = parts[1].trim();
            }
          }
        });

        _showSuccessSnackBar('Localisation détectée avec succès');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission requise'),
        content: const Text(
          'L\'accès à votre localisation est nécessaire pour détecter automatiquement votre adresse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              LocationService.openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Adresse de livraison',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Location detection button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.isDetectingLocation
                  ? null
                  : _detectLocationWithDetails,
              icon: widget.isDetectingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                widget.isDetectingLocation
                    ? 'Détection en cours...'
                    : 'Détecter ma position',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position détectée avec succès',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Phone number field
          TextFormField(
            controller: widget.phoneController,
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

          // City field
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'Ville *',
              prefixIcon: const Icon(Icons.location_city),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.getBackground(isDark),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'La ville est requise';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // District field
          TextFormField(
            controller: _districtController,
            decoration: InputDecoration(
              labelText: 'Quartier/Commune',
              hintText: 'Ex: Hamdallaye, Badalabougou...',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.getBackground(isDark),
            ),
          ),

          const SizedBox(height: 16),

          // Address field
          TextFormField(
            controller: widget.addressController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Adresse complète *',
              hintText: 'Rue, numéro, bâtiment...',
              prefixIcon: const Icon(Icons.home),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.getBackground(isDark),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'L\'adresse est requise';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Landmark field
          TextFormField(
            controller: _landmarkController,
            decoration: InputDecoration(
              labelText: 'Point de repère',
              hintText: 'Ex: Près de la pharmacie...',
              prefixIcon: const Icon(Icons.place),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.getBackground(isDark),
            ),
          ),

          const SizedBox(height: 16),

          // Notes field
          TextFormField(
            controller: widget.notesController,
            maxLines: 2,
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
