import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Token Management
  static Future<void> storeSecureToken(String key, String token) async {
    await _storage.write(key: key, value: token);
  }

  static Future<String?> getSecureToken(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> clearSecureToken(String key) async {
    await _storage.delete(key: key);
  }

  // Data Encryption
  static String hashSensitiveData(String data) {
    var bytes = utf8.encode(data);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Input Validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);
  }

  // Rate Limiting
  static final Map<String, List<DateTime>> _rateLimitMap = {};
  
  static bool checkRateLimit(String identifier, int maxAttempts, Duration window) {
    final now = DateTime.now();
    final attempts = _rateLimitMap[identifier] ?? [];
    
    // Remove old attempts
    attempts.removeWhere((attempt) => now.difference(attempt) > window);
    
    if (attempts.length >= maxAttempts) {
      return false;
    }
    
    attempts.add(now);
    _rateLimitMap[identifier] = attempts;
    return true;
  }
}
