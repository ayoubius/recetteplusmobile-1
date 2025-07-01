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
          query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
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

    // Données de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation des données de test pour les recettes');
    }
    
    return _getTestRecipes(searchQuery: searchQuery, category: category, limit: limit, offset: offset);
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
          query = query.or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }
        
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        
        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        if (response.isNotEmpty) {
          List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(response);
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

    // Données de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation des données de test pour les produits');
    }
    
    return _getTestProducts(searchQuery: searchQuery, category: category, limit: limit, offset: offset, shuffle: shuffle);
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
          query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
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

    // Données de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation des données de test pour les vidéos');
    }
    
    return _getTestVideos(searchQuery: searchQuery, category: category, limit: limit, offset: offset);
  }

  // ==================== MÉTHODES POUR LES PROFILS UTILISATEUR ====================
  
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (isInitialized) {
        final response = await client
            .from('user_profiles')
            .select('*')
            .eq('user_id', userId)
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

    // Profil de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation du profil de test');
    }
    
    return {
      'user_id': userId,
      'email': 'test@example.com',
      'display_name': 'Utilisateur Test',
      'first_name': 'Utilisateur',
      'last_name': 'Test',
      'phone_number': '+223 XX XX XX XX',
      'photo_url': null,
      'bio': 'Passionné de cuisine',
      'location': 'Bamako, Mali',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
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
        await client.from('user_profiles').insert({
          'user_id': userId,
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
            .from('user_profiles')
            .update(updateData)
            .eq('user_id', userId);
        
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

    // Favoris de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation des favoris de test');
    }
    
    return [
      {
        'item_id': '1',
        'type': 'recipe',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'item_id': '2',
        'type': 'recipe',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];
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
  
  static Future<List<Map<String, dynamic>>> getUserHistory({int limit = 20}) async {
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

    // Historique de test en fallback
    if (kDebugMode) {
      print('📱 Utilisation de l\'historique de test');
    }
    
    return [
      {
        'recipe_id': '1',
        'viewed_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'recipes': {
          'id': '1',
          'title': 'Pâtes Carbonara Authentiques',
          'description': 'La vraie recette italienne des pâtes carbonara.',
          'image_url': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
        }
      },
      {
        'recipe_id': '2',
        'viewed_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'recipes': {
          'id': '2',
          'title': 'Tarte Tatin aux Pommes',
          'description': 'Dessert français classique avec des pommes caramélisées.',
          'image_url': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Tatin',
        }
      },
    ];
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

  // ==================== DONNÉES DE TEST ====================
  
  static List<Map<String, dynamic>> _getTestRecipes({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) {
    List<Map<String, dynamic>> testRecipes = [
      {
        'id': '1',
        'title': 'Pâtes Carbonara Authentiques',
        'description': 'La vraie recette italienne des pâtes carbonara avec œufs, pecorino et guanciale.',
        'image': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
        'prep_time': 15,
        'cook_time': 20,
        'servings': 4,
        'difficulty': 'Facile',
        'category': 'Plats principaux',
        'rating': 4.8,
        'created_at': '2024-01-15T10:00:00Z',
      },
      {
        'id': '2',
        'title': 'Tarte Tatin aux Pommes',
        'description': 'Dessert français classique avec des pommes caramélisées et une pâte brisée.',
        'image': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Tatin',
        'prep_time': 30,
        'cook_time': 45,
        'servings': 8,
        'difficulty': 'Moyen',
        'category': 'Desserts',
        'rating': 4.6,
        'created_at': '2024-01-14T14:30:00Z',
      },
      {
        'id': '3',
        'title': 'Salade César Maison',
        'description': 'Salade fraîche avec sa sauce césar authentique et ses croûtons dorés.',
        'image': 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Salade+César',
        'prep_time': 20,
        'cook_time': 10,
        'servings': 4,
        'difficulty': 'Facile',
        'category': 'Entrées',
        'rating': 4.4,
        'created_at': '2024-01-13T16:45:00Z',
      },
    ];

    // Appliquer les filtres
    List<Map<String, dynamic>> filteredRecipes = testRecipes;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredRecipes = filteredRecipes.where((recipe) {
        final title = recipe['title']?.toString().toLowerCase() ?? '';
        final description = recipe['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    if (category != null && category.isNotEmpty) {
      filteredRecipes = filteredRecipes.where((recipe) {
        return recipe['category']?.toString() == category;
      }).toList();
    }

    // Appliquer la pagination
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredRecipes.length);
    
    if (startIndex >= filteredRecipes.length) {
      return [];
    }

    return filteredRecipes.sublist(startIndex, endIndex);
  }

  static List<Map<String, dynamic>> _getTestProducts({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
    bool shuffle = false,
  }) {
    List<Map<String, dynamic>> testProducts = [
      {
        'id': '1',
        'name': 'Huile d\'Olive Extra Vierge',
        'description': 'Huile d\'olive de première pression à froid, idéale pour assaisonnements.',
        'image_url': 'https://via.placeholder.com/300x300/96CEB4/FFFFFF?text=Huile+Olive',
        'price': 12.99,
        'unit': '500ml',
        'category': 'Huiles et Vinaigres',
        'in_stock': true,
        'stock_quantity': 25,
        'created_at': '2024-01-15T10:00:00Z',
      },
      {
        'id': '2',
        'name': 'Parmesan AOP 24 mois',
        'description': 'Fromage Parmigiano Reggiano affiné 24 mois, au goût intense et fruité.',
        'image_url': 'https://via.placeholder.com/300x300/FECA57/FFFFFF?text=Parmesan',
        'price': 8.50,
        'unit': '200g',
        'category': 'Fromages',
        'in_stock': true,
        'stock_quantity': 15,
        'created_at': '2024-01-14T14:30:00Z',
      },
      {
        'id': '3',
        'name': 'Pâtes Spaghetti Bio',
        'description': 'Spaghetti biologiques de blé dur, texture parfaite pour tous vos plats.',
        'image_url': 'https://via.placeholder.com/300x300/FF9F43/FFFFFF?text=Spaghetti',
        'price': 3.20,
        'unit': '500g',
        'category': 'Pâtes et Riz',
        'in_stock': true,
        'stock_quantity': 40,
        'created_at': '2024-01-13T16:45:00Z',
      },
      {
        'id': '4',
        'name': 'Tomates San Marzano',
        'description': 'Tomates pelées italiennes San Marzano DOP, parfaites pour les sauces.',
        'image_url': 'https://via.placeholder.com/300x300/FF6B6B/FFFFFF?text=Tomates',
        'price': 4.80,
        'unit': '400g',
        'category': 'Conserves',
        'in_stock': true,
        'stock_quantity': 30,
        'created_at': '2024-01-12T12:15:00Z',
      },
    ];

    // Appliquer les filtres
    List<Map<String, dynamic>> filteredProducts = testProducts;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final description = product['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    if (category != null && category.isNotEmpty) {
      filteredProducts = filteredProducts.where((product) {
        return product['category']?.toString() == category;
      }).toList();
    }

    // Mélanger si demandé
    if (shuffle) {
      filteredProducts.shuffle();
    }

    // Appliquer la pagination
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredProducts.length);
    
    if (startIndex >= filteredProducts.length) {
      return [];
    }

    return filteredProducts.sublist(startIndex, endIndex);
  }

  static List<Map<String, dynamic>> _getTestVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) {
    List<Map<String, dynamic>> testVideos = [
      {
        'id': '1',
        'title': 'Technique de la Carbonara',
        'description': 'Apprenez la vraie technique italienne pour réussir vos carbonara.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
        'duration': 300,
        'category': 'Technique',
        'likes': 1250,
        'views': 15000,
        'created_at': '2024-01-15T10:00:00Z',
        'recipe_id': '1',
      },
      {
        'id': '2',
        'title': 'Pâtisserie: Tarte Tatin',
        'description': 'Maîtrisez l\'art de la tarte tatin avec nos conseils de chef.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Tatin',
        'duration': 420,
        'category': 'Pâtisserie',
        'likes': 890,
        'views': 12000,
        'created_at': '2024-01-14T14:30:00Z',
        'recipe_id': '2',
      },
      {
        'id': '3',
        'title': 'Salade César Parfaite',
        'description': 'Les secrets d\'une salade césar réussie avec sa sauce maison.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Salade+César',
        'duration': 180,
        'category': 'Technique',
        'likes': 650,
        'views': 8500,
        'created_at': '2024-01-13T16:45:00Z',
        'recipe_id': '3',
      },
    ];

    // Appliquer les filtres
    List<Map<String, dynamic>> filteredVideos = testVideos;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredVideos = filteredVideos.where((video) {
        final title = video['title']?.toString().toLowerCase() ?? '';
        final description = video['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    if (category != null && category.isNotEmpty) {
      filteredVideos = filteredVideos.where((video) {
        return video['category']?.toString() == category;
      }).toList();
    }

    // Appliquer la pagination
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredVideos.length);
    
    if (startIndex >= filteredVideos.length) {
      return [];
    }

    return filteredVideos.sublist(startIndex, endIndex);
  }
}
