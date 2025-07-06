import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';

class EnhancedLocationPicker extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  final Map<String, dynamic>? initialLocation;

  const EnhancedLocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
  });

  @override
  State<EnhancedLocationPicker> createState() => _EnhancedLocationPickerState();
}

class _EnhancedLocationPickerState extends State<EnhancedLocationPicker> {
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController =
      TextEditingController(text: 'Bamako');
  final TextEditingController _landmarkController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _googleMapsLink;
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadInitialLocation();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _loadInitialLocation() {
    if (widget.initialLocation != null) {
      final location = widget.initialLocation!;
      _streetController.text = location['street_address'] ?? '';
      _districtController.text = location['district'] ?? '';
      _cityController.text = location['city'] ?? 'Bamako';
      _landmarkController.text = location['landmark'] ?? '';
      _latitude = location['latitude'];
      _longitude = location['longitude'];
      _googleMapsLink = location['google_maps_link'];
    }
  }

  Future<void> _checkLocationPermission() async {
    final hasPermission =
        await LocationService.checkAndRequestLocationPermission();
    setState(() {
      _hasLocationPermission = hasPermission;
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!_hasLocationPermission) {
      _showPermissionDialog();
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _googleMapsLink =
              _generateGoogleMapsLink(position.latitude, position.longitude);
        });

        // Get address from coordinates
        final addressInfo =
            await LocationService.getDetailedAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (addressInfo != null) {
          setState(() {
            _streetController.text = addressInfo.road ?? '';
            _districtController.text =
                addressInfo.neighbourhood ?? addressInfo.suburb ?? '';
            _cityController.text = addressInfo.city ?? 'Bamako';
          });
        }

        _notifyLocationChange();
        HapticFeedback.lightImpact();
        _showSuccessMessage('Localisation détectée avec succès');
      }
    } catch (e) {
      _showErrorMessage('Erreur lors de la détection: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _searchAddresses(String query) async {
    if (query.length < 3) {
      setState(() {
        _showSuggestions = false;
        _addressSuggestions = [];
      });
      return;
    }

    try {
      // Use Nominatim for address search
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}, Bamako, Mali&limit=5&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'RecettePlus/1.0.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _addressSuggestions = data
              .map((item) => {
                    'display_name': item['display_name'] ?? '',
                    'lat':
                        double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
                    'lon':
                        double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
                    'address': item['address'] ?? {},
                  })
              .toList();
          _showSuggestions = _addressSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Erreur recherche adresse: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final address = suggestion['address'] as Map<String, dynamic>;

    setState(() {
      _streetController.text = address['road'] ?? '';
      _districtController.text =
          address['neighbourhood'] ?? address['suburb'] ?? '';
      _cityController.text = address['city'] ?? address['town'] ?? 'Bamako';
      _latitude = suggestion['lat'];
      _longitude = suggestion['lon'];
      _googleMapsLink = _generateGoogleMapsLink(_latitude!, _longitude!);
      _showSuggestions = false;
      _addressSuggestions = [];
    });

    _notifyLocationChange();
  }

  String _generateGoogleMapsLink(double lat, double lon) {
    return 'https://www.google.com/maps?q=$lat,$lon';
  }

  void _notifyLocationChange() {
    final locationData = {
      'street_address': _streetController.text.trim(),
      'district': _districtController.text.trim(),
      'city': _cityController.text.trim(),
      'landmark': _landmarkController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'google_maps_link': _googleMapsLink,
      'full_address': _buildFullAddress(),
    };

    widget.onLocationSelected(locationData);
  }

  String _buildFullAddress() {
    final parts = <String>[];
    if (_streetController.text.isNotEmpty) parts.add(_streetController.text);
    if (_districtController.text.isNotEmpty)
      parts.add(_districtController.text);
    if (_cityController.text.isNotEmpty) parts.add(_cityController.text);
    return parts.join(', ');
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

  void _showSuccessMessage(String message) {
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

  void _showErrorMessage(String message) {
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
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

          // GPS Detection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLoadingLocation
                    ? 'Détection...'
                    : 'Détecter ma position GPS',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
                        'Position GPS détectée',
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
                    'Lat: ${_latitude!.toStringAsFixed(6)}, Lon: ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                  if (_googleMapsLink != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // TODO: Open Google Maps link
                        _showSuccessMessage('Lien Google Maps généré');
                      },
                      child: const Text(
                        'Voir sur Google Maps',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Street Address with Autocomplete
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _streetController,
                onChanged: (value) {
                  _searchAddresses(value);
                  _notifyLocationChange();
                },
                decoration: InputDecoration(
                  labelText: 'Adresse de la rue *',
                  hintText: 'Ex: Rue 123, Avenue de la Paix...',
                  prefixIcon: const Icon(Icons.home),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.getBackground(isDark),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'adresse de la rue est requise';
                  }
                  return null;
                },
              ),

              // Address Suggestions
              if (_showSuggestions && _addressSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _addressSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _addressSuggestions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on, size: 16),
                        title: Text(
                          suggestion['display_name'],
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // District/Commune
          TextFormField(
            controller: _districtController,
            onChanged: (_) => _notifyLocationChange(),
            decoration: InputDecoration(
              labelText: 'Quartier/Commune *',
              hintText: 'Ex: Hamdallaye, Badalabougou...',
              prefixIcon: const Icon(Icons.location_city),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.getBackground(isDark),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le quartier/commune est requis';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // City
          TextFormField(
            controller: _cityController,
            onChanged: (_) => _notifyLocationChange(),
            decoration: InputDecoration(
              labelText: 'Ville *',
              prefixIcon: const Icon(Icons.location_on),
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

          // Landmark
          TextFormField(
            controller: _landmarkController,
            onChanged: (_) => _notifyLocationChange(),
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

          // Location Summary
          if (_latitude != null && _longitude != null)
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
                        'Résumé de la localisation',
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
                    'Adresse complète: ${_buildFullAddress()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coordonnées: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
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
    );
  }
}
