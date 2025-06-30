import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase n\'est pas initialisé. Appelez initialize() d\'abord.');
    }
    return _client!;
  }

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: true, // Pour le développement
      );
      
      _client = Supabase.instance.client;
      _isInitialized = true;
      
      print('Supabase initialisé avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation de Supabase: $e');
      _isInitialized = false;
      // Ne pas lancer d'exception pour permettre l'utilisation des données de test
    }
  }

  static Future<void> dispose() async {
    _client = null;
    _isInitialized = false;
  }

  // Méthodes utilitaires pour les requêtes communes
  static Future<PostgrestResponse<List<Map<String, dynamic>>>> select(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    if (!_isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    var query = _client!.from(table).select(columns);

    // Appliquer les filtres
    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }

    // Appliquer l'ordre
    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    // Appliquer la pagination
    if (limit != null) {
      if (offset != null) {
        query = query.range(offset, offset + limit - 1);
      } else {
        query = query.limit(limit);
      }
    }

    return await query.execute();
  }

  static Future<PostgrestResponse<List<Map<String, dynamic>>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (!_isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    return await _client!.from(table).insert(data).execute();
  }

  static Future<PostgrestResponse<List<Map<String, dynamic>>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    if (!_isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    var query = _client!.from(table).update(data);

    filters.forEach((key, value) {
      query = query.eq(key, value);
    });

    return await query.execute();
  }

  static Future<PostgrestResponse<List<Map<String, dynamic>>>> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    if (!_isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    var query = _client!.from(table).delete();

    filters.forEach((key, value) {
      query = query.eq(key, value);
    });

    return await query.execute();
  }
}
