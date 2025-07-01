import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  static bool get isInitialized => Supabase.instance.client.supabaseUrl.isNotEmpty;

  // Récupérer les recettes avec données de test en fallback
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

  // Récupérer les produits avec données de test en fallback
  static Future<List<Map<String, dynamic>>> getProducts({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
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
          return response;
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
    
    return _getTestProducts(searchQuery: searchQuery, category: category, limit: limit, offset: offset);
  }

  // Récupérer les vidéos avec données de test en fallback
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

  // Récupérer le profil utilisateur
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (isInitialized) {
        final user = client.auth.currentUser;
        if (user != null) {
          final response = await client
              .from('profiles')
              .select('*')
              .eq('id', user.id)
              .maybeSingle();
          
          if (response != null) {
            return response;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération du profil: $e');
      }
    }

    // Profil de test en fallback
    return {
      'id': 'test-user-id',
      'email': 'test@example.com',
      'full_name': 'Utilisateur Test',
      'avatar_url': 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=UT',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Données de test pour les recettes
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
        'image_url': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
        'prep_time': 15,
        'cook_time': 20,
        'servings': 4,
        'difficulty': 'Facile',
        'category': 'Plats principaux',
        'ingredients': [
          {'name': 'Spaghetti', 'quantity': '400g'},
          {'name': 'Œufs', 'quantity': '4'},
          {'name': 'Pecorino Romano', 'quantity': '100g'},
          {'name': 'Guanciale', 'quantity': '150g'},
          {'name': 'Poivre noir', 'quantity': 'Au goût'},
        ],
        'instructions': [
          'Faire cuire les pâtes dans l\'eau salée',
          'Faire revenir le guanciale',
          'Mélanger œufs et fromage',
          'Combiner le tout hors du feu',
        ],
        'created_at': '2024-01-15T10:00:00Z',
        'likes': 245,
        'rating': 4.8,
      },
      {
        'id': '2',
        'title': 'Tarte Tatin aux Pommes',
        'description': 'Dessert français classique avec des pommes caramélisées et une pâte brisée.',
        'image_url': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Tatin',
        'prep_time': 30,
        'cook_time': 45,
        'servings': 8,
        'difficulty': 'Moyen',
        'category': 'Desserts',
        'ingredients': [
          {'name': 'Pommes', 'quantity': '8'},
          {'name': 'Sucre', 'quantity': '150g'},
          {'name': 'Beurre', 'quantity': '50g'},
          {'name': 'Pâte brisée', 'quantity': '1'},
        ],
        'instructions': [
          'Préparer le caramel',
          'Disposer les pommes',
          'Recouvrir de pâte',
          'Cuire au four',
        ],
        'created_at': '2024-01-14T14:30:00Z',
        'likes': 189,
        'rating': 4.6,
      },
      {
        'id': '3',
        'title': 'Salade César Maison',
        'description': 'Salade fraîche avec sa sauce césar authentique et ses croûtons dorés.',
        'image_url': 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Salade+César',
        'prep_time': 20,
        'cook_time': 10,
        'servings': 4,
        'difficulty': 'Facile',
        'category': 'Entrées',
        'ingredients': [
          {'name': 'Laitue romaine', 'quantity': '2 têtes'},
          {'name': 'Parmesan', 'quantity': '100g'},
          {'name': 'Pain', 'quantity': '4 tranches'},
          {'name': 'Anchois', 'quantity': '6 filets'},
          {'name': 'Œuf', 'quantity': '1'},
        ],
        'instructions': [
          'Préparer la sauce',
          'Faire les croûtons',
          'Laver la salade',
          'Assembler et servir',
        ],
        'created_at': '2024-01-13T16:45:00Z',
        'likes': 156,
        'rating': 4.4,
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

  // Données de test pour les produits
  static List<Map<String, dynamic>> _getTestProducts({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
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
        'rating': 4.7,
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
        'rating': 4.9,
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
        'rating': 4.5,
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
        'rating': 4.6,
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

    // Appliquer la pagination
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredProducts.length);
    
    if (startIndex >= filteredProducts.length) {
      return [];
    }

    return filteredProducts.sublist(startIndex, endIndex);
  }

  // Données de test pour les vidéos
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
