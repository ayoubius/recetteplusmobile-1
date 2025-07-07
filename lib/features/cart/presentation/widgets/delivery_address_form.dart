import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';

class DeliveryAddressForm extends StatefulWidget {
  final TextEditingController addressController;
  final TextEditingController notesController;
  final TextEditingController phoneController;
  final bool isDetectingLocation;
  final VoidCallback onDetectLocation;
  final String? detectedAddress;

  const DeliveryAddressForm({
    super.key,
    required this.addressController,
    required this.notesController,
    required this.phoneController,
    required this.isDetectingLocation,
    required this.onDetectLocation,
    this.detectedAddress,
  });

  @override
  State<DeliveryAddressForm> createState() => DeliveryAddressFormState();
}

class DeliveryAddressFormState extends State<DeliveryAddressForm>
    with TickerProviderStateMixin {
  double? _latitude;
  double? _longitude;
  String? _googleMapsLink;
  bool _isLoadingLocation = false;
  String _loadingMessage = 'Détection en cours...';

  // Animation controller pour l'indicateur de chargement
  late AnimationController _loadingController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
  }

  Future<void> _detectLocationWithDetails() async {
    setState(() {
      _isLoadingLocation = true;
      _loadingMessage = 'Vérification des permissions...';
    });

    _loadingController.repeat(reverse: true);

    try {
      // Vérifier et demander les permissions
      final hasPermission =
          await LocationService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        _showLocationPermissionDialog();
        return;
      }

      setState(() {
        _loadingMessage = 'Recherche de votre position...';
      });

      // Obtenir la position actuelle avec détails complets
      final positionDetails =
          await LocationService.getCurrentPositionWithDetails();
      if (positionDetails == null) {
        _showErrorSnackBar('Impossible d\'obtenir votre position');
        return;
      }

      setState(() {
        _loadingMessage = 'Récupération de l\'adresse...';
      });

      // Extraire les coordonnées et le lien Google Maps
      _latitude = positionDetails['latitude'];
      _longitude = positionDetails['longitude'];
      _googleMapsLink = positionDetails['google_maps_link'];

      // Obtenir les détails d'adresse complets
      final addressInfo =
          await LocationService.getDetailedAddressFromCoordinates(
        _latitude!,
        _longitude!,
      );

      if (addressInfo != null) {
        setState(() {
          // Remplir les champs avec les informations détectées
          widget.addressController.text = addressInfo.shortAddress;
          _loadingMessage = 'Localisation détectée !';
        });

        // Petit délai pour montrer le message de succès
        await Future.delayed(const Duration(milliseconds: 500));

        HapticFeedback.lightImpact();
        _showSuccessSnackBar('Localisation détectée avec succès');
      } else {
        _showErrorSnackBar('Impossible de déterminer l\'adresse');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la détection: $e');
    } finally {
      _loadingController.stop();
      setState(() {
        _isLoadingLocation = false;
        _loadingMessage = 'Détection en cours...';
      });
    }
  }

  void _showLocationPermissionDialog() {
    _loadingController.stop();
    setState(() {
      _isLoadingLocation = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission requise'),
        content: const Text(
          'L\'accès à votre localisation est nécessaire pour détecter automatiquement votre adresse de livraison.',
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

  // Obtenir les données d'adresse enrichies pour la commande
  Map<String, dynamic> getEnrichedAddressData() {
    return {
      'delivery_address': widget.addressController.text.trim(),
      'delivery_notes': widget.notesController.text.trim(),
      'phone_number': widget.phoneController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'google_maps_link': _googleMapsLink,
    };
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

          // Location detection button with enhanced loading
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_isLoadingLocation || widget.isDetectingLocation)
                  ? null
                  : _detectLocationWithDetails,
              icon: (_isLoadingLocation || widget.isDetectingLocation)
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.secondary),
                            ),
                          ),
                        );
                      },
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                (_isLoadingLocation || widget.isDetectingLocation)
                    ? _loadingMessage
                    : 'Détecter ma position GPS',
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

          // Enhanced loading indicator
          if (_isLoadingLocation || widget.isDetectingLocation) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.secondary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _loadingMessage,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          backgroundColor: AppColors.secondary.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.secondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Veuillez patienter pendant que nous localisons votre position...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(isDark),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Position GPS détectée avec succès',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Latitude: ${_latitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Longitude: ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Localisation enregistrée',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
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
              if (value.trim().length < 8) {
                return 'Numéro de téléphone invalide';
              }
              return null;
            },
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
                return 'L\'adresse de livraison est requise';
              }
              if (value.trim().length < 10) {
                return 'Veuillez entrer une adresse plus détaillée';
              }
              return null;
            },
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

          // Location summary (sans le lien Google Maps visible)
          if (_latitude != null &&
              _longitude != null &&
              _googleMapsLink != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.map,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Informations de localisation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Coordonnées GPS: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Localisation enregistrée pour la livraison',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
