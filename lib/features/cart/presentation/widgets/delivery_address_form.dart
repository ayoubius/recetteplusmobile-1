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

class DeliveryAddressFormState extends State<DeliveryAddressForm> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  AddressInfo? _detectedAddressInfo;
  bool _showDetailedFields = false;

  @override
  void dispose() {
    _cityController.dispose();
    _districtController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _detectLocationWithDetails() async {
    try {
      // Vérifier et demander les permissions
      final hasPermission =
          await LocationService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        _showLocationPermissionDialog();
        return;
      }

      setState(() {
        // Déclencher l'animation de détection
      });

      // Obtenir la position actuelle
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showErrorSnackBar('Impossible d\'obtenir votre position');
        return;
      }

      // Obtenir les détails d'adresse complets
      final addressInfo =
          await LocationService.getDetailedAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (addressInfo != null) {
        setState(() {
          _detectedAddressInfo = addressInfo;
          _showDetailedFields = true;

          // Remplir les champs avec les informations détectées
          widget.addressController.text = addressInfo.shortAddress;
          _cityController.text = addressInfo.city ?? 'Bamako';
          _districtController.text =
              addressInfo.neighbourhood ?? addressInfo.suburb ?? '';

          // Si on a un point d'intérêt proche, l'utiliser comme repère
          if (addressInfo.displayName.contains(',')) {
            final parts = addressInfo.displayName.split(',');
            if (parts.length > 2) {
              _landmarkController.text = parts[1].trim();
            }
          }
        });

        HapticFeedback.lightImpact();
        _showSuccessSnackBar('Localisation détectée avec succès');
      } else {
        _showErrorSnackBar('Impossible de déterminer l\'adresse');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la détection: $e');
    }
  }

  void _showLocationPermissionDialog() {
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
      'delivery_city': _cityController.text.trim(),
      'delivery_district': _districtController.text.trim(),
      'delivery_landmark': _landmarkController.text.trim(),
      if (_detectedAddressInfo != null) ...{
        'delivery_latitude': _detectedAddressInfo!.latitude,
        'delivery_longitude': _detectedAddressInfo!.longitude,
      },
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

          if (_detectedAddressInfo != null) ...[
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
                        'Position détectée',
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
                    _detectedAddressInfo!.shortAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                  if (_detectedAddressInfo!.city != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ville: ${_detectedAddressInfo!.city}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
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

          // City field
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'Ville *',
              hintText: 'Ex: Bamako',
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

          // District/Neighborhood field
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
                return 'L\'adresse de livraison est requise';
              }
              if (value.trim().length < 10) {
                return 'Veuillez entrer une adresse plus détaillée';
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
              hintText: 'Ex: Près de la pharmacie, face à l\'école...',
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

          // Delivery info
        ],
      ),
    );
  }
}
