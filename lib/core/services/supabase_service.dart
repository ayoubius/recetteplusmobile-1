import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Vérifier si Supabase est initialisé
  static bool get isInitialized {
    try {
      return Supabase.instance.client.supabaseUrl.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Données de test pour le mode hors ligne
  static final List<Map<String, dynamic>> _testRecipes = [
    {
      'id': '1',
      'title': 'Tarte aux pommes classique',
      'description': 'Une délicieuse tarte aux pommes avec une pâte brisée maison',
      'ingredients': ['4 pommes', '200g farine', '100g beurre', '50g sucre', '1 œuf'],
      'instructions': ['Préparer la pâte', 'Éplucher les pommes', 'Assembler', 'Cuire 45min à 180°C'],
      'prep_time': 30,
      'cook_time': 45,
      'servings': 6,
      'difficulty': 'Facile',
      'category': 'Desserts',
      'image_url': 'https://example.com/tarte-pommes.jpg',
      'created_at': '2024-01-01T10:00:00Z',
      'user_id': 'test-user-1',
      'rating': 4.5,
      'nutrition': {
        'calories': 280,
        'protein': 4,
        'carbs': 45,
        'fat': 12
      }
    },
    {
      'id': '2',
      'title': 'Salade César maison',
      'description': 'La vraie salade César avec sa sauce authentique',
      'ingredients': ['1 salade romaine', '100g parmesan', '2 œufs', '2 gousses ail', 'Croûtons', 'Anchois'],
      'instructions': ['Préparer la sauce', 'Laver la salade', 'Mélanger', 'Servir immédiatement'],
      'prep_time': 20,
      'cook_time': 0,
      'servings': 4,
      'difficulty': 'Moyen',
      'category': 'Entrées',
      'image_url': 'https://example.com/salade-cesar.jpg',
      'created_at': '2024-01-02T14:30:00Z',
      'user_id': 'test-user-2',
      'rating': 4.8,
      'nutrition': {
        'calories': 220,
        'protein': 12,
        'carbs': 8,
        'fat': 18
      }
    },
    {
      'id': '3',
      'title': 'Bœuf bourguignon traditionnel',
      'description': 'Le plat emblématique de la cuisine française',
      'ingredients': ['1kg bœuf', '200g lardons', '500ml vin rouge', 'Champignons', 'Oignons', 'Carottes'],
      'instructions': ['Faire revenir la viande', 'Ajouter le vin', 'Mijoter 2h', 'Ajouter les légumes'],
      'prep_time': 45,
      'cook_time': 150,
      'servings': 8,
      'difficulty': 'Difficile',
      'category': 'Plats principaux',
      'image_url': 'https://example.com/boeuf-bourguignon.jpg',
      'created_at': '2024-01-03T16:00:00Z',
      'user_id': 'test-user-1',
      'rating': 4.9,
      'nutrition': {
        'calories': 420,
        'protein': 35,
        'carbs': 12,
        'fat': 25
      }
    }
  ];

  static final List<Map<String, dynamic>> _testProducts = [
    {
      'id': '1',
      'name': 'Farine de blé T55',
      'description': 'Farine de qualité supérieure pour toutes vos pâtisseries',
      'price': 2.50,
      'category': 'Ingrédients de base',
      'image_url': 'https://example.com/farine.jpg',
      'stock': 50,
      'unit': 'kg',
      'brand': 'Francine',
      'created_at': '2024-01-01T10:00:00Z'
    },
    {
      'id': '2',
      'name': 'Beurre doux AOP',
      'description': 'Beurre de Normandie AOP, parfait pour la pâtisserie',
      'price': 4.20,
      'category': 'Produits laitiers',
      'image_url': 'https://example.com/beurre.jpg',
      'stock': 30,
      'unit': '250g',
      'brand': 'Isigny',
      'created_at': '2024-01-01T10:00:00Z'
    },
    {
      'id': '3',
      'name': 'Œufs bio de poules élevées au sol',
      'description': 'Œufs frais de poules élevées au sol, certification bio',
      'price': 3.80,
      'category': 'Œufs',
      'image_url': 'https://example.com/oeufs.jpg',
      'stock': 25,
      'unit': 'boîte de 12',
      'brand': 'Bio Village',
      'created_at': '2024-01-01T10:00:00Z'
    },
    {
      'id': '4',
      'name': 'Sucre en poudre',
      'description': 'Sucre blanc cristallisé, idéal pour toutes préparations',
      'price': 1.90,
      'category': 'Ingrédients de base',
      'image_url': 'https://example.com/sucre.jpg',
      'stock': 40,
      'unit': 'kg',
      'brand': 'Daddy',
      'created_at': '2024-01-01T10:00:00Z'
    }
  ];

  static final List<Map<String, dynamic>> _testVideos = [
    {
      'id': '1',
      'title': 'Technique de pétrissage de la pâte à pain',
      'description': 'Apprenez les gestes essentiels pour pétrir une pâte à pain parfaite',
      'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'thumbnail': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
      'duration': 180,
      'category': 'Technique',
      'views': 1250,
      'likes': 89,
      'created_at': '2024-01-01T10:00:00Z',
      'recipe_id': '1',
      'chef_name': 'Chef Martin',
      'difficulty': 'Intermédiaire'
    },
    {
      'id': '2',
      'title': 'Réaliser une pâte feuilletée maison',
      'description': 'Maîtrisez l\'art de la pâte feuilletée avec cette technique détaillée',
      'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      'thumbnail': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg',
      'duration': 420,
      'category': 'Pâtisserie',
      'views': 2100,
      'likes': 156,
      'created_at': '2024-01-02T14:30:00Z',
      'recipe_id': '2',
      'chef_name': 'Chef Sophie',
      'difficulty': 'Avancé'
    },
    {
      'id': '3',
      'title': 'Découpe et préparation des légumes',
      'description': 'Les techniques de base pour découper et préparer tous types de légumes',
      'video_url': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'thumbnail': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
      'duration': 240,
      'category': 'Technique',
      'views': 890,
      'likes': 67,
      'created_at': '2024-01-03T16:00:00Z',
      'recipe_id': '3',
      'chef_name': 'Chef Antoine',
      'difficulty': 'Débutant'
    }
  ];

  static final Map<String, dynamic> _testUserProfile = {
    'id': 'test-user-1',
    'email': 'test@example.com',
    'full_name': 'Utilisateur Test',
    'phone': '+33123456789',
    'address': '123 Rue de la Paix, 75001 Paris',
    'date_of_birth': '1990-01-01',
    'preferences': {
      'dietary_restrictions': ['Végétarien'],
      'favorite_cuisines': ['Française', 'Italienne'],
      'cooking_level': 'Intermédiaire'
    },
    'privacy_settings': {
      'profile_visibility': 'public',
      'email_notifications': true,
      'push_notifications': true,
      'data_sharing': false
    },
    'created_at': '2024-01-01T10:00:00Z',
    'updated_at': '2024-01-01T10:00:00Z'
  };

  // Méthodes pour les recettes
  static Future<List<Map<String, dynamic>>> getRecipes({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Utilisation des données de test pour les recettes');
        }
        
        var filteredRecipes = List<Map<String, dynamic>>.from(_testRecipes);
        
        if (searchQuery != null && searchQuery.isNotEmpty) {
          filteredRecipes = filteredRecipes.where((recipe) {
            return recipe['title'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                   recipe['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }
        
        if (category != null && category != 'Tous') {
          filteredRecipes = filteredRecipes.where((recipe) {
            return recipe['category'] == category;
          }).toList();
        }
        
        return filteredRecipes.skip(offset).take(limit).toList();
      }

      var query = client.from('recipes').select('*');
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }
      
      if (category != null && category != 'Tous') {
        query = query.eq('category', category);
      }
      
      final response = await query.range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des recettes: $e');
        print('🔄 Basculement vers les données de test');
      }
      return _testRecipes.skip(offset).take(limit).toList();
    }
  }

  static Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    try {
      if (!isInitialized) {
        return _testRecipes.firstWhere(
          (recipe) => recipe['id'] == recipeId,
          orElse: () => _testRecipes.first,
        );
      }

      final response = await client
          .from('recipes')
          .select('*')
          .eq('id', recipeId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération de la recette: $e');
      }
      return _testRecipes.firstWhere(
        (recipe) => recipe['id'] == recipeId,
        orElse: () => _testRecipes.first,
      );
    }
  }

  // Méthodes pour les produits
  static Future<List<Map<String, dynamic>>> getProducts({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Utilisation des données de test pour les produits');
        }
        
        var filteredProducts = List<Map<String, dynamic>>.from(_testProducts);
        
        if (searchQuery != null && searchQuery.isNotEmpty) {
          filteredProducts = filteredProducts.where((product) {
            return product['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                   product['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }
        
        if (category != null && category != 'Tous') {
          filteredProducts = filteredProducts.where((product) {
            return product['category'] == category;
          }).toList();
        }
        
        return filteredProducts.skip(offset).take(limit).toList();
      }

      var query = client.from('products').select('*');
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }
      
      if (category != null && category != 'Tous') {
        query = query.eq('category', category);
      }
      
      final response = await query.range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des produits: $e');
        print('🔄 Basculement vers les données de test');
      }
      return _testProducts.skip(offset).take(limit).toList();
    }
  }

  // Méthodes pour les vidéos
  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Utilisation des données de test pour les vidéos');
        }
        
        var filteredVideos = List<Map<String, dynamic>>.from(_testVideos);
        
        if (searchQuery != null && searchQuery.isNotEmpty) {
          filteredVideos = filteredVideos.where((video) {
            return video['title'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                   video['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }
        
        if (category != null && category != 'Tous') {
          filteredVideos = filteredVideos.where((video) {
            return video['category'] == category;
          }).toList();
        }
        
        return filteredVideos.skip(offset).take(limit).toList();
      }

      var query = client.from('videos').select('*');
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }
      
      if (category != null && category != 'Tous') {
        query = query.eq('category', category);
      }
      
      final response = await query.range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des vidéos: $e');
        print('🔄 Basculement vers les données de test');
      }
      return _testVideos.skip(offset).take(limit).toList();
    }
  }

  // Méthodes pour les profils utilisateur
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Utilisation du profil de test');
        }
        return Map<String, dynamic>.from(_testUserProfile);
      }

      final response = await client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération du profil: $e');
        print('🔄 Basculement vers le profil de test');
      }
      return Map<String, dynamic>.from(_testUserProfile);
    }
  }

  static Future<void> createUserProfile({
    required String userId,
    required String email,
    String? fullName,
    String? phone,
    String? address,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Simulation de création de profil');
        }
        return;
      }

      await client.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la création du profil: $e');
      }
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    String? dateOfBirth,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? privacySettings,
  }) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Simulation de mise à jour de profil');
        }
        return;
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (phone != null) updateData['phone'] = phone;
      if (address != null) updateData['address'] = address;
      if (dateOfBirth != null) updateData['date_of_birth'] = dateOfBirth;
      if (preferences != null) updateData['preferences'] = preferences;
      if (privacySettings != null) updateData['privacy_settings'] = privacySettings;

      await client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la mise à jour du profil: $e');
      }
    }
  }

  // Méthodes pour les favoris
  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Retour de favoris de test');
        }
        return [_testRecipes.first, _testProducts.first];
      }

      final user = client.auth.currentUser;
      if (user == null) return [];

      final response = await client
          .from('favorites')
          .select('*, recipes(*), products(*)')
          .eq('user_id', user.id);
      
      return List<Map<String, dynamic>>.from(response);
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
          print('🔄 Mode hors ligne - Simulation d\'ajout aux favoris');
        }
        return;
      }

      final user = client.auth.currentUser;
      if (user == null) return;

      await client.from('favorites').insert({
        'user_id': user.id,
        'item_id': itemId,
        'item_type': type,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'ajout aux favoris: $e');
      }
    }
  }

  static Future<void> removeFromFavorites(String itemId) async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Simulation de suppression des favoris');
        }
        return;
      }

      final user = client.auth.currentUser;
      if (user == null) return;

      await client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('item_id', itemId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression des favoris: $e');
      }
    }
  }

  // Méthodes pour l'historique
  static Future<List<Map<String, dynamic>>> getUserHistory() async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Retour d\'historique de test');
        }
        return [_testRecipes.last];
      }

      final user = client.auth.currentUser;
      if (user == null) return [];

      final response = await client
          .from('user_history')
          .select('*, recipes(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
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
          print('🔄 Mode hors ligne - Simulation d\'ajout à l\'historique');
        }
        return;
      }

      final user = client.auth.currentUser;
      if (user == null) return;

      await client.from('user_history').insert({
        'user_id': user.id,
        'recipe_id': itemId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'ajout à l\'historique: $e');
      }
    }
  }

  // Méthodes d'authentification
  static Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      return await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la connexion: $e');
      }
      rethrow;
    }
  }

  static Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      return await client.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'inscription: $e');
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      if (!isInitialized) {
        if (kDebugMode) {
          print('🔄 Mode hors ligne - Simulation de déconnexion');
        }
        return;
      }

      await client.auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la déconnexion: $e');
      }
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la réinitialisation du mot de passe: $e');
      }
      rethrow;
    }
  }

  // Getter pour l'utilisateur actuel
  static User? get currentUser => client.auth.currentUser;

  // Stream pour écouter les changements d'authentification
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
