import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'RecettePlus/1.0.0';

  /// Obtenir l'adresse à partir des coordonnées (géocodage inverse)
  static Future<AddressInfo?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1&accept-language=fr',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && data['display_name'] != null) {
          return AddressInfo.fromJson(data);
        }
      }

      if (kDebugMode) {
        print('❌ Erreur géocodage inverse: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur géocodage inverse: $e');
      }
      return null;
    }
  }

  /// Rechercher des coordonnées à partir d'une adresse (géocodage direct)
  static Future<List<LocationResult>> searchLocation(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1&accept-language=fr',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) => LocationResult.fromJson(item)).toList();
      }

      if (kDebugMode) {
        print('❌ Erreur recherche de localisation: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur recherche de localisation: $e');
      }
      return [];
    }
  }

  /// Valider si des coordonnées sont dans une zone spécifique
  static bool isInBounds(
    double latitude,
    double longitude,
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  ) {
    return latitude >= minLat &&
           latitude <= maxLat &&
           longitude >= minLon &&
           longitude <= maxLon;
  }

  /// Calculer la distance entre deux points (en kilomètres)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Rayon de la Terre en km
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = (dLat / 2) * (dLat / 2) +
        _degreesToRadians(lat1) * _degreesToRadians(lat2) *
        (dLon / 2) * (dLon / 2);
    
    final double c = 2 * (a.sqrt());
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}

// Extension pour ajouter sqrt à double
extension DoubleExtension on double {
  double sqrt() {
    if (this < 0) return double.nan;
    if (this == 0) return 0;
    
    double x = this;
    double prev;
    
    // Méthode de Newton-Raphson
    do {
      prev = x;
      x = (x + this / x) / 2;
    } while ((x - prev).abs() > 0.000001);
    
    return x;
  }
}

/// Classe pour représenter les informations d'adresse
class AddressInfo {
  final String displayName;
  final String? houseNumber;
  final String? road;
  final String? neighbourhood;
  final String? suburb;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final double latitude;
  final double longitude;

  AddressInfo({
    required this.displayName,
    this.houseNumber,
    this.road,
    this.neighbourhood,
    this.suburb,
    this.city,
    this.state,
    this.postcode,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    
    return AddressInfo(
      displayName: json['display_name'] ?? '',
      houseNumber: address['house_number'],
      road: address['road'],
      neighbourhood: address['neighbourhood'] ?? address['suburb'],
      suburb: address['suburb'] ?? address['city_district'],
      city: address['city'] ?? address['town'] ?? address['village'],
      state: address['state'] ?? address['region'],
      postcode: address['postcode'],
      country: address['country'],
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
    );
  }

  /// Obtenir une adresse formatée courte
  String get shortAddress {
    final parts = <String>[];
    
    if (houseNumber != null && road != null) {
      parts.add('$houseNumber $road');
    } else if (road != null) {
      parts.add(road!);
    }
    
    if (neighbourhood != null) {
      parts.add(neighbourhood!);
    } else if (suburb != null) {
      parts.add(suburb!);
    }
    
    if (city != null) {
      parts.add(city!);
    }
    
    return parts.join(', ');
  }

  /// Obtenir une adresse formatée complète
  String get fullAddress {
    return displayName;
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'house_number': houseNumber,
      'road': road,
      'neighbourhood': neighbourhood,
      'suburb': suburb,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Classe pour représenter un résultat de recherche de localisation
class LocationResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  final double importance;

  LocationResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.importance,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      displayName: json['display_name'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      type: json['type'] ?? '',
      importance: double.tryParse(json['importance']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'importance': importance,
    };
  }
}