import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
          'Supabase n\'est pas initialisé. Appelez initialize() d\'abord.');
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
        debug: kDebugMode,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;

      print('Supabase initialisé avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation de Supabase: $e');
      _isInitialized = false;
    }
  }

  static Future<void> dispose() async {
    _client = null;
    _isInitialized = false;
  }

  // Méthodes utilitaires pour les requêtes communes
  static Future<List<Map<String, dynamic>>> select(
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

    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      if (offset != null) {
        return await query.range(offset, offset + limit - 1);
      } else {
        return await query.limit(limit);
      }
    } else {
      return await query;
    }
  }

  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (!_isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    return await _client!.from(table).insert(data).select();
  }

  static Future<List<Map<String, dynamic>>> update(
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

    return await query.select();
  }

  static Future<List<Map<String, dynamic>>> delete(
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

    return await query.select();
  }

  // Méthodes spécifiques pour les recettes
  static Future<List<Map<String, dynamic>>> getRecipes({
    String? searchQuery,
    String? category,
    String? difficulty,
    int? maxPrepTime,
    double? minRating,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de récupérer les recettes.');
        return [];
      }

      var query = _client!.from('recipes').select('*');

      // Appliquer les filtres
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.eq('difficulty', difficulty);
      }

      if (maxPrepTime != null) {
        query = query.lte('prep_time', maxPrepTime);
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      final response = await query
          .order('rating', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response;
    } catch (e) {
      print('❌ Erreur lors de la récupération des recettes: $e');
      return [];
    }
  }

  // Méthodes spécifiques pour les vidéos
  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de récupérer les vidéos.');
        return [];
      }

      var query = _client!.from('videos').select('*');

      // Appliquer les filtres
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response;
    } catch (e) {
      print('❌ Erreur lors de la récupération des vidéos: $e');
      return [];
    }
  }

  // Méthodes spécifiques pour les produits
  static Future<List<Map<String, dynamic>>> getProducts({
    String? searchQuery,
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int limit = 20,
    int offset = 0,
    bool shuffle = false,
  }) async {
    if (!_isInitialized) {
      print('❌ Supabase non initialisé, impossible de récupérer les produits.');
      return [];
    }
    try {
      var query = _client!.from('products').select('*');
      
      // Appliquer les filtres
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }
      if (inStock != null) {
        query = query.eq('in_stock', inStock);
      }
      
      final response = await query
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);

      List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(response);
      if (shuffle && products.isNotEmpty) {
        products.shuffle();
      }
      return products;
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits: $e');
      return [];
    }
  }

  // Méthodes pour les profils utilisateur
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de récupérer le profil.');
        return null;
      }

      final response = await _client!
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Erreur lors de la récupération du profil: $e');
      return null;
    }
  }

  static Future<void> createUserProfile({
    required String userId,
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatar,
  }) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de créer le profil.');
        return;
      }

      await _client!.from('user_profiles').insert({
        'user_id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'avatar': avatar,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erreur lors de la création du profil: $e');
      rethrow;
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatar,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de mettre à jour le profil.');
        return;
      }

      Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (phone != null) updateData['phone'] = phone;
      if (avatar != null) updateData['avatar'] = avatar;
      if (additionalData != null) updateData.addAll(additionalData);

      await _client!
          .from('user_profiles')
          .update(updateData)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du profil: $e');
      rethrow;
    }
  }

  // Méthodes pour les favoris
  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de récupérer les favoris.');
        return [];
      }

      final user = _client!.auth.currentUser;
      if (user == null) return [];

      final response = await _client!
          .from('favorites')
          .select('recipe_id')
          .eq('user_id', user.id);

      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var favorite in response) {
          final recipe = await _client!
              .from('recipes')
              .select('*')
              .eq('id', favorite['recipe_id'])
              .maybeSingle();
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des favoris: $e');
      return [];
    }
  }

  static Future<void> addToFavorites(String itemId, String type) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible d\'ajouter aux favoris.');
        return;
      }

      final user = _client!.auth.currentUser;
      if (user == null) return;

      await _client!.from('favorites').insert({
        'user_id': user.id,
        'recipe_id': itemId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erreur lors de l\'ajout aux favoris: $e');
      rethrow;
    }
  }

  static Future<void> removeFromFavorites(String itemId) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de supprimer des favoris.');
        return;
      }

      final user = _client!.auth.currentUser;
      if (user == null) return;

      await _client!
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', itemId);
    } catch (e) {
      print('❌ Erreur lors de la suppression des favoris: $e');
      rethrow;
    }
  }

  // Méthodes pour l'historique
  static Future<List<Map<String, dynamic>>> getUserHistory(
      {int limit = 20}) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible de récupérer l\'historique.');
        return [];
      }

      final user = _client!.auth.currentUser;
      if (user == null) return [];

      final response = await _client!
          .from('user_history')
          .select('recipe_id')
          .eq('user_id', user.id)
          .order('viewed_at', ascending: false)
          .limit(limit);

      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var history in response) {
          final recipe = await _client!
              .from('recipes')
              .select('*')
              .eq('id', history['recipe_id'])
              .maybeSingle();
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  static Future<void> addToHistory(String itemId) async {
    try {
      if (!_isInitialized) {
        print('❌ Supabase non initialisé, impossible d\'ajouter à l\'historique.');
        return;
      }

      final user = _client!.auth.currentUser;
      if (user == null) return;

      // Supprimer l'entrée existante s'il y en a une
      await _client!
          .from('user_history')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', itemId);

      // Ajouter la nouvelle entrée
      await _client!.from('user_history').insert({
        'user_id': user.id,
        'recipe_id': itemId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Erreur lors de l\'ajout à l\'historique: $e');
    }
  }
}
