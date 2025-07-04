import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static bool get isInitialized {
    try {
      // Vérifier si Supabase est initialisé en tentant d'accéder au client
      final _ = Supabase.instance.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== MÉTHODES POUR LES RECETTES ====================

  static Future<List<Map<String, dynamic>>> getRecipes({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (isInitialized) {
        var query = client.from('recipes').select('*');

        if (searchQuery != null && searchQuery.isNotEmpty) {
          query = query.or(
              'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }

        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }

        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        if (response.isNotEmpty) {
          return response;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Supabase pour les recettes: $e');
      }
    }
    return [];
  }

  // ==================== MÉTHODES POUR LES PRODUITS ====================

  static Future<List<Map<String, dynamic>>> getProducts({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
    bool shuffle = false,
  }) async {
    try {
      if (isInitialized) {
        var query = client.from('products').select('*');

        if (searchQuery != null && searchQuery.isNotEmpty) {
          query = query
              .or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }

        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }

        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        if (response.isNotEmpty) {
          List<Map<String, dynamic>> products =
              List<Map<String, dynamic>>.from(response);
          if (shuffle) {
            products.shuffle();
          }
          return products;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Supabase pour les produits: $e');
      }
    }
    return [];
  }

  // ==================== MÉTHODES POUR LES VIDÉOS ====================

  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (isInitialized) {
        var query = client.from('videos').select('*');

        if (searchQuery != null && searchQuery.isNotEmpty) {
          query = query.or(
              'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }

        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }

        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        if (response.isNotEmpty) {
          return response;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Supabase pour les vidéos: $e');
      }
    }
    return [];
  }

  // ==================== MÉTHODES POUR LES PROFILS UTILISATEUR ====================

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (isInitialized) {
        final response = await client
            .from('profiles')
            .select('*')
            .eq('id', userId) // Correction: utiliser 'id' au lieu de 'user_id'
            .maybeSingle();

        if (response != null) {
          return response;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération du profil: $e');
      }
    }
    return null;
  }

  static Future<void> createUserProfile({
    required String userId,
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      if (isInitialized) {
        await client.from('profiles').insert({
          'id': userId, // Correction: utiliser 'id' au lieu de 'user_id'
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'display_name': firstName ?? email.split('@')[0],
          'phone_number': phone,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('✅ Profil utilisateur créé avec succès');
        }
      } else {
        if (kDebugMode) {
          print('📱 Simulation: Profil utilisateur créé (mode test)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la création du profil: $e');
      }
      // Ne pas faire échouer l'authentification pour un problème de profil
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (isInitialized) {
        Map<String, dynamic> updateData = {
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (firstName != null) {
          updateData['first_name'] = firstName;
          updateData['display_name'] = firstName;
        }
        if (lastName != null) updateData['last_name'] = lastName;
        if (phone != null) updateData['phone_number'] = phone;
        if (additionalData != null) updateData.addAll(additionalData);

        await client
            .from('profiles')
            .update(updateData)
            .eq('id', userId); // Correction: utiliser 'id'

        if (kDebugMode) {
          print('✅ Profil utilisateur mis à jour avec succès');
        }
      } else {
        if (kDebugMode) {
          print('📱 Simulation: Profil utilisateur mis à jour (mode test)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la mise à jour du profil: $e');
      }
      rethrow;
    }
  }

  // ==================== MÉTHODES POUR LES FAVORIS ====================

  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user == null) return [];

        final response = await client
            .from('favorites')
            .select('item_id, type, created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des favoris: $e');
      }
    }
    return [];
  }

  static Future<void> addToFavorites(String itemId, String type) async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user == null) return;

        await client.from('favorites').insert({
          'user_id': user.id,
          'item_id': itemId,
          'type': type,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('✅ Ajouté aux favoris: $itemId');
        }
      } else {
        if (kDebugMode) {
          print('📱 Simulation: Ajouté aux favoris (mode test)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'ajout aux favoris: $e');
      }
      rethrow;
    }
  }

  static Future<void> removeFromFavorites(String itemId) async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user == null) return;

        await client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('item_id', itemId);

        if (kDebugMode) {
          print('✅ Supprimé des favoris: $itemId');
        }
      } else {
        if (kDebugMode) {
          print('📱 Simulation: Supprimé des favoris (mode test)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression des favoris: $e');
      }
      rethrow;
    }
  }

  // ==================== MÉTHODES POUR L'HISTORIQUE ====================

  static Future<List<Map<String, dynamic>>> getUserHistory(
      {int limit = 20}) async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user == null) return [];

        final response = await client
            .from('user_history')
            .select('*, recipes(*)')
            .eq('user_id', user.id)
            .order('viewed_at', ascending: false)
            .limit(limit);

        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération de l\'historique: $e');
      }
    }
    return [];
  }

  static Future<void> addToHistory(String itemId) async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user == null) return;

        // Supprimer l'entrée existante s'il y en a une
        await client
            .from('user_history')
            .delete()
            .eq('user_id', user.id)
            .eq('recipe_id', itemId);

        // Ajouter la nouvelle entrée
        await client.from('user_history').insert({
          'user_id': user.id,
          'recipe_id': itemId,
          'viewed_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('✅ Ajouté à l\'historique: $itemId');
        }
      } else {
        if (kDebugMode) {
          print('📱 Simulation: Ajouté à l\'historique (mode test)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erreur lors de l\'ajout à l\'historique: $e');
      }
      // Ne pas faire échouer l'opération principale pour un problème d'historique
    }
  }

  // ==================== MÉTHODES POUR LES RECETTES UTILISATEUR ====================

  /// Obtenir les recettes créées par un utilisateur
  static Future<List<Map<String, dynamic>>> getUserRecipes(
      String userId) async {
    try {
      if (isInitialized) {
        final response = await client
            .from('recipes')
            .select('*')
            .eq('created_by', userId)
            .order('created_at', ascending: false);

        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des recettes utilisateur: $e');
      }
    }
    return [];
  }

  // ==================== DONNÉES DE TEST ====================
  // Les méthodes de données de test sont désactivées :
  // _getTestRecipes, _getTestProducts, _getTestVideos ne sont plus utilisées.
}
