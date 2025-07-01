import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  // Utiliser directement l'instance globale de Supabase
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
    if (!isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    dynamic query = client.from(table).select(columns);

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
    if (!isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    return await client.from(table).insert(data).select();
  }

  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    if (!isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    var query = client.from(table).update(data);

    filters.forEach((key, value) {
      query = query.eq(key, value);
    });

    return await query.select();
  }

  static Future<List<Map<String, dynamic>>> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    if (!isInitialized) {
      throw Exception('Supabase n\'est pas initialisé');
    }

    var query = client.from(table).delete();

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
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, utilisation des données de test pour les recettes.');
        }
        return _getTestRecipes();
      }

      var query = client.from('recipes').select('*');

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
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des recettes: $e');
        print('🔄 Utilisation des données de test...');
      }
      return _getTestRecipes();
    }
  }

  // Données de test pour les recettes
  static List<Map<String, dynamic>> _getTestRecipes() {
    return [
      {
        'id': '1',
        'title': 'Pasta Carbonara',
        'description': 'Un classique italien avec des œufs, du parmesan et du bacon',
        'image_url': 'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=400',
        'prep_time': 20,
        'cook_time': 15,
        'difficulty': 'Facile',
        'rating': 4.8,
        'category': 'Italien',
        'ingredients': ['Pâtes', 'Œufs', 'Parmesan', 'Bacon', 'Poivre noir'],
        'instructions': [
          'Faire cuire les pâtes',
          'Préparer la sauce aux œufs',
          'Mélanger et servir'
        ],
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': '2',
        'title': 'Salade César',
        'description': 'Salade fraîche avec croûtons et sauce césar maison',
        'image_url': 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=400',
        'prep_time': 15,
        'cook_time': 0,
        'difficulty': 'Facile',
        'rating': 4.5,
        'category': 'Salade',
        'ingredients': ['Laitue romaine', 'Croûtons', 'Parmesan', 'Anchois'],
        'instructions': [
          'Préparer la salade',
          'Faire la sauce',
          'Assembler et servir'
        ],
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': '3',
        'title': 'Coq au Vin',
        'description': 'Plat traditionnel français au vin rouge',
        'image_url': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400',
        'prep_time': 30,
        'cook_time': 90,
        'difficulty': 'Difficile',
        'rating': 4.9,
        'category': 'Français',
        'ingredients': ['Poulet', 'Vin rouge', 'Champignons', 'Lardons'],
        'instructions': [
          'Mariner le poulet',
          'Faire revenir les ingrédients',
          'Mijoter longuement'
        ],
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
  }

  // Méthodes spécifiques pour les vidéos
  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, utilisation des données de test pour les vidéos.');
        }
        return _getTestVideos();
      }

      var query = client.from('videos').select('*');

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
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des vidéos: $e');
        print('🔄 Utilisation des données de test...');
      }
      return _getTestVideos();
    }
  }

  // Données de test pour les vidéos
  static List<Map<String, dynamic>> _getTestVideos() {
    return [
      {
        'id': '1',
        'title': 'Comment faire des pâtes parfaites',
        'description': 'Apprenez les secrets pour des pâtes al dente',
        'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail_url': 'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=400',
        'duration': 300,
        'category': 'Technique',
        'views': 1250,
        'likes': 89,
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': '2',
        'title': 'Techniques de découpe des légumes',
        'description': 'Maîtrisez l\'art de la découpe comme un chef',
        'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'thumbnail_url': 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=400',
        'duration': 420,
        'category': 'Technique',
        'views': 2100,
        'likes': 156,
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': '3',
        'title': 'Recette de pain maison',
        'description': 'Du pain frais fait maison en quelques étapes',
        'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'thumbnail_url': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400',
        'duration': 600,
        'category': 'Boulangerie',
        'views': 3200,
        'likes': 245,
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
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
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, utilisation des données de test pour les produits.');
        }
        return _getTestProducts(shuffle: shuffle);
      }

      var query = client.from('products').select('*');

      // Appliquer les filtres
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
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

      List<Map<String, dynamic>> products =
          List<Map<String, dynamic>>.from(response);
      if (shuffle && products.isNotEmpty) {
        products.shuffle();
      }
      return products;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des produits: $e');
        print('🔄 Utilisation des données de test...');
      }
      return _getTestProducts(shuffle: shuffle);
    }
  }

  // Données de test pour les produits
  static List<Map<String, dynamic>> _getTestProducts({bool shuffle = false}) {
    List<Map<String, dynamic>> products = [
      {
        'id': '1',
        'name': 'Tomates cerises bio',
        'description': 'Tomates cerises fraîches et biologiques',
        'price': 3.50,
        'image_url': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400',
        'category': 'Légumes',
        'in_stock': true,
        'stock_quantity': 25,
        'unit': 'barquette',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': '2',
        'name': 'Pâtes italiennes',
        'description': 'Pâtes artisanales italiennes de qualité premium',
        'price': 4.20,
        'image_url': 'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=400',
        'category': 'Épicerie',
        'in_stock': true,
        'stock_quantity': 50,
        'unit': 'paquet',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': '3',
        'name': 'Fromage parmesan',
        'description': 'Parmesan italien AOP vieilli 24 mois',
        'price': 12.80,
        'image_url': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400',
        'category': 'Fromage',
        'in_stock': true,
        'stock_quantity': 15,
        'unit': 'morceau',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'id': '4',
        'name': 'Huile d\'olive extra vierge',
        'description': 'Huile d\'olive première pression à froid',
        'price': 8.90,
        'image_url': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400',
        'category': 'Épicerie',
        'in_stock': true,
        'stock_quantity': 30,
        'unit': 'bouteille',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
    ];

    if (shuffle) {
      products.shuffle();
    }
    return products;
  }

  // Méthodes pour les profils utilisateur
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de récupérer le profil.');
        }
        return null;
      }

      final response = await client
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération du profil: $e');
      }
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
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de créer le profil.');
        }
        return;
      }

      await client.from('user_profiles').insert({
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
      if (kDebugMode) {
        print('❌ Erreur lors de la création du profil: $e');
      }
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
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de mettre à jour le profil.');
        }
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

      await client
          .from('user_profiles')
          .update(updateData)
          .eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la mise à jour du profil: $e');
      }
      rethrow;
    }
  }

  // Méthodes pour les favoris
  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, retour de favoris vides.');
        }
        return [];
      }

      final user = client.auth.currentUser;
      if (user == null) return [];

      final response = await client
          .from('favorites')
          .select('recipe_id')
          .eq('user_id', user.id);

      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var favorite in response) {
          final recipe = await client
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
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des favoris: $e');
      }
      return [];
    }
  }

  static Future<void> addToFavorites(String itemId, String type) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible d\'ajouter aux favoris.');
        }
        return;
      }

      final user = client.auth.currentUser;
      if (user == null) return;

      await client.from('favorites').insert({
        'user_id': user.id,
        'recipe_id': itemId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'ajout aux favoris: $e');
      }
      rethrow;
    }
  }

  static Future<void> removeFromFavorites(String itemId) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de supprimer des favoris.');
        }
        return;
      }

      final user = client.auth.currentUser;
      if (user == null) return;

      await client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', itemId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression des favoris: $e');
      }
      rethrow;
    }
  }

  // Méthodes pour l'historique
  static Future<List<Map<String, dynamic>>> getUserHistory(
      {int limit = 20}) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, retour d\'historique vide.');
        }
        return [];
      }

      final user = client.auth.currentUser;
      if (user == null) return [];

      final response = await client
          .from('user_history')
          .select('recipe_id')
          .eq('user_id', user.id)
          .order('viewed_at', ascending: false)
          .limit(limit);

      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var history in response) {
          final recipe = await client
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
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération de l\'historique: $e');
      }
      return [];
    }
  }

  static Future<void> addToHistory(String itemId) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible d\'ajouter à l\'historique.');
        }
        return;
      }

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
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erreur lors de l\'ajout à l\'historique: $e');
      }
    }
  }
}
