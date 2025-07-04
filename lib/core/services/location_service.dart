import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';
import 'geocoding_service.dart';

// Classe pour représenter une position
class Position {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  Position({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Position.fromGeolocator(geo.Position position) {
    return Position(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class LocationService {
  static StreamController<Map<String, dynamic>>? _locationController;

  /// Vérifier et demander les permissions de localisation
  static Future<bool> checkAndRequestLocationPermission() async {
    try {
      if (kDebugMode) {
        print('📍 Vérification des permissions de localisation...');
      }

      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('❌ Service de localisation désactivé');
        }
        return false;
      }

      // Vérifier les permissions
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          if (kDebugMode) {
            print('❌ Permission de localisation refusée');
          }
          return false;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('❌ Permission de localisation refusée définitivement');
        }
        return false;
      }

      if (kDebugMode) {
        print('✅ Permissions de localisation accordées');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur vérification permissions: $e');
      }
      return false;
    }
  }

  /// Obtenir la position actuelle avec une vraie géolocalisation
  static Future<Position?> getCurrentPosition() async {
    try {
      if (kDebugMode) {
        print('📍 Obtention de la position actuelle...');
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (kDebugMode) {
        print('✅ Position obtenue: ${position.latitude}, ${position.longitude}');
        print('📏 Précision: ${position.accuracy}m');
      }

      return Position.fromGeolocator(position);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur obtention position: $e');
      }
      return null;
    }
  }

  /// Obtenir l'adresse à partir des coordonnées en utilisant OpenStreetMap
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      if (kDebugMode) {
        print('🗺️ Géocodification inverse: $latitude, $longitude');
      }

      final addressInfo = await GeocodingService.getAddressFromCoordinates(
        latitude,
        longitude,
      );

      if (addressInfo != null) {
        if (kDebugMode) {
          print('✅ Adresse trouvée: ${addressInfo.shortAddress}');
        }
        return addressInfo.shortAddress;
      }

      if (kDebugMode) {
        print('⚠️ Aucune adresse trouvée pour ces coordonnées');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur géocodification inverse: $e');
      }
      return null;
    }
  }

  /// Obtenir les informations d'adresse complètes
  static Future<AddressInfo?> getDetailedAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      if (kDebugMode) {
        print('🗺️ Géocodification détaillée: $latitude, $longitude');
      }

      final addressInfo = await GeocodingService.getAddressFromCoordinates(
        latitude,
        longitude,
      );

      if (addressInfo != null) {
        if (kDebugMode) {
          print('✅ Informations d\'adresse détaillées obtenues');
          print('   - Adresse courte: ${addressInfo.shortAddress}');
          print('   - Ville: ${addressInfo.city}');
          print('   - Quartier: ${addressInfo.neighbourhood}');
        }
      }

      return addressInfo;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur géocodification détaillée: $e');
      }
      return null;
    }
  }

  /// Rechercher des lieux par nom
  static Future<List<LocationResult>> searchLocations(String query) async {
    try {
      if (kDebugMode) {
        print('🔍 Recherche de lieux: $query');
      }

      final results = await GeocodingService.searchLocation(query);

      if (kDebugMode) {
        print('✅ ${results.length} résultats trouvés');
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur recherche de lieux: $e');
      }
      return [];
    }
  }

  /// S'abonner aux mises à jour de position d'une livraison
  static Stream<Map<String, dynamic>> subscribeToDeliveryUpdates(String orderId) {
    _locationController ??= StreamController<Map<String, dynamic>>.broadcast();
    
    // Simuler des mises à jour de position toutes les 15 secondes
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_locationController?.isClosed == true) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      // Coordonnées de base pour Yaoundé, Cameroun
      final baseLatitude = 3.848;
      final baseLongitude = 11.502;
      
      // Simuler un mouvement réaliste
      final latitude = baseLatitude + (now.millisecond / 100000) * (now.second % 2 == 0 ? 1 : -1);
      final longitude = baseLongitude + (now.second / 10000) * (now.minute % 2 == 0 ? 1 : -1);
      
      _locationController?.add({
        'order_id': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': now.toIso8601String(),
        'speed': 25.0 + (now.second % 10), // km/h simulée
        'heading': now.second * 6.0, // Direction simulée
      });
      
      if (kDebugMode) {
        print('📍 Position mise à jour pour $orderId: $latitude, $longitude');
      }
    });
    
    return _locationController!.stream;
  }

  /// Arrêter les mises à jour de position
  static void stopLocationUpdates() {
    _locationController?.close();
    _locationController = null;
  }

  /// Afficher une boîte de dialogue pour les permissions de localisation
  static Future<bool> showLocationPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission de localisation'),
          content: const Text(
            'Cette application a besoin d\'accéder à votre localisation pour vous proposer les meilleures options de livraison et suivre vos commandes en temps réel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Refuser'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Autoriser'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Ouvrir les paramètres de l'application
  static Future<void> openAppSettings() async {
    try {
      if (kDebugMode) {
        print('⚙️ Ouverture des paramètres de l\'application...');
      }
      
      await geo.Geolocator.openAppSettings();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ouverture paramètres: $e');
      }
    }
  }

  /// Calculer la distance entre deux points
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return GeocodingService.calculateDistance(lat1, lon1, lat2, lon2);
  }

  /// Calculer le temps estimé de trajet
  static Duration calculateEstimatedTravelTime(
    double lat1, double lon1,
    double lat2, double lon2, {
    double averageSpeed = 30.0, // km/h
  }) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    final timeInHours = distance / averageSpeed;
    final timeInMinutes = (timeInHours * 60).round();
    
    return Duration(minutes: timeInMinutes);
  }

  /// Vérifier si une position est dans une zone de livraison
  static bool isInDeliveryZone(
    double latitude,
    double longitude,
    double centerLat,
    double centerLon,
    double radiusKm,
  ) {
    final distance = calculateDistance(latitude, longitude, centerLat, centerLon);
    return distance <= radiusKm;
  }

  /// Obtenir la position en continu
  static Stream<Position> getPositionStream() {
    return geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      ),
    ).map((position) => Position.fromGeolocator(position));
  }
}