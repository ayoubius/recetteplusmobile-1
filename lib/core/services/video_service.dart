import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class VideoService {
  static const String _testDataPath = 'assets/data/test_videos.json';

  // Récupérer les vidéos depuis Supabase ou les données de test
  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (SupabaseService.isInitialized) {
        print('🔄 Récupération des vidéos depuis Supabase...');
        final videos = await SupabaseService.getVideos(
          searchQuery: searchQuery,
          category: category,
          limit: limit,
          offset: offset,
        );
        
        if (videos.isNotEmpty) {
          print('✅ ${videos.length} vidéos récupérées depuis Supabase');
          return videos;
        } else {
          print('⚠️ Aucune vidéo trouvée dans Supabase, utilisation des données de test');
        }
      } else {
        print('⚠️ Supabase non initialisé, utilisation des données de test');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des vidéos depuis Supabase: $e');
    }

    // Fallback vers les données de test
    return _getTestVideos(
      searchQuery: searchQuery,
      category: category,
      limit: limit,
      offset: offset,
    );
  }

  // Méthode pour récupérer des vidéos infinies (pagination)
  static Future<List<Map<String, dynamic>>> getInfiniteVideos({
    required int offset,
    required int batchSize,
    List<String> excludeIds = const [],
  }) async {
    try {
      if (SupabaseService.isInitialized) {
        var query = SupabaseService.client.from('videos').select('*');
        
        // Exclure les IDs déjà chargés
        if (excludeIds.isNotEmpty) {
          query = query.not('id', 'in', '(${excludeIds.join(',')})');
        }
        
        final videos = await query
            .order('created_at', ascending: false)
            .range(offset, offset + batchSize - 1);
        
        if (videos.isNotEmpty) {
          return videos;
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des vidéos infinies: $e');
    }

    // Fallback vers les données de test
    final testVideos = await _getTestVideos();
    final filteredVideos = testVideos
        .where((video) => !excludeIds.contains(video['id'].toString()))
        .toList();
    
    final startIndex = offset;
    final endIndex = (startIndex + batchSize).clamp(0, filteredVideos.length);
    
    if (startIndex >= filteredVideos.length) {
      return [];
    }
    
    return filteredVideos.sublist(startIndex, endIndex);
  }

  // Méthode pour rechercher des vidéos
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      if (SupabaseService.isInitialized) {
        final videos = await SupabaseService.client
            .from('videos')
            .select('*')
            .or('title.ilike.%$query%,description.ilike.%$query%')
            .order('created_at', ascending: false);
        
        if (videos.isNotEmpty) {
          return videos;
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la recherche de vidéos: $e');
    }

    // Fallback vers les données de test
    final testVideos = await _getTestVideos();
    final searchQuery = query.toLowerCase();
    
    return testVideos.where((video) {
      final title = video['title']?.toString().toLowerCase() ?? '';
      final description = video['description']?.toString().toLowerCase() ?? '';
      final category = video['category']?.toString().toLowerCase() ?? '';
      
      return title.contains(searchQuery) ||
          description.contains(searchQuery) ||
          category.contains(searchQuery);
    }).toList();
  }

  // Données de test pour les vidéos
  static Future<List<Map<String, dynamic>>> _getTestVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    print('📱 Utilisation des données de test pour les vidéos');
    
    List<Map<String, dynamic>> testVideos = [
      {
        'id': '1',
        'title': 'Recette de Pâtes Carbonara',
        'description': 'Une délicieuse recette de pâtes carbonara authentique',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
        'duration': 300,
        'category': 'Plats principaux',
        'likes': 1250,
        'views': 15000,
        'created_at': '2024-01-15T10:00:00Z',
        'recipe_id': '1',
      },
      {
        'id': '2',
        'title': 'Tarte aux Pommes Maison',
        'description': 'Apprenez à faire une tarte aux pommes parfaite',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Pommes',
        'duration': 420,
        'category': 'Desserts',
        'likes': 890,
        'views': 12000,
        'created_at': '2024-01-14T14:30:00Z',
        'recipe_id': '2',
      },
      {
        'id': '3',
        'title': 'Salade César Fraîche',
        'description': 'Une salade césar croquante et savoureuse',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Salade+César',
        'duration': 180,
        'category': 'Entrées',
        'likes': 650,
        'views': 8500,
        'created_at': '2024-01-13T16:45:00Z',
        'recipe_id': '3',
      },
      {
        'id': '4',
        'title': 'Soupe de Légumes d\'Hiver',
        'description': 'Une soupe réconfortante pour les jours froids',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Soupe+Légumes',
        'duration': 240,
        'category': 'Soupes',
        'likes': 420,
        'views': 6200,
        'created_at': '2024-01-12T12:15:00Z',
        'recipe_id': '4',
      },
      {
        'id': '5',
        'title': 'Cookies aux Pépites de Chocolat',
        'description': 'Des cookies moelleux et délicieux',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/FECA57/FFFFFF?text=Cookies',
        'duration': 360,
        'category': 'Desserts',
        'likes': 1100,
        'views': 18000,
        'created_at': '2024-01-11T09:30:00Z',
        'recipe_id': '5',
      },
      {
        'id': '6',
        'title': 'Smoothie Vert Détox',
        'description': 'Un smoothie vert rafraîchissant et plein de vitamines',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/95E1D3/FFFFFF?text=Smoothie+Vert',
        'duration': 120,
        'category': 'Boissons',
        'likes': 756,
        'views': 9200,
        'created_at': '2024-01-10T08:15:00Z',
        'recipe_id': '6',
      },
      {
        'id': '7',
        'title': 'Pizza Margherita Authentique',
        'description': 'La vraie pizza margherita italienne',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/FF9F43/FFFFFF?text=Pizza+Margherita',
        'duration': 480,
        'category': 'Plats principaux',
        'likes': 1580,
        'views': 22000,
        'created_at': '2024-01-09T19:30:00Z',
        'recipe_id': '7',
      },
      {
        'id': '8',
        'title': 'Crème Brûlée Parfaite',
        'description': 'Le secret d\'une crème brûlée réussie',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/F8B500/FFFFFF?text=Crème+Brûlée',
        'duration': 390,
        'category': 'Desserts',
        'likes': 920,
        'views': 13500,
        'created_at': '2024-01-08T15:45:00Z',
        'recipe_id': '8',
      },
      {
        'id': '9',
        'title': 'Ratatouille Provençale',
        'description': 'Un plat traditionnel de Provence',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/6C5CE7/FFFFFF?text=Ratatouille',
        'duration': 350,
        'category': 'Végétarien',
        'likes': 680,
        'views': 8900,
        'created_at': '2024-01-07T12:20:00Z',
        'recipe_id': '9',
      },
      {
        'id': '10',
        'title': 'Sushi Maison',
        'description': 'Apprenez à faire des sushis comme un chef',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
        'thumbnail': 'https://via.placeholder.com/400x300/00B894/FFFFFF?text=Sushi+Maison',
        'duration': 600,
        'category': 'Plats principaux',
        'likes': 1340,
        'views': 19800,
        'created_at': '2024-01-06T17:10:00Z',
        'recipe_id': '10',
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

    if (category != null && category.isNotEmpty && category != 'Tous') {
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

  // Vérifier si une URL vidéo est accessible
  static Future<bool> isVideoUrlAccessible(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la vérification de l\'URL vidéo: $e');
      return false;
    }
  }

  // Obtenir les catégories de vidéos
  static Future<List<String>> getVideoCategories() async {
    try {
      if (SupabaseService.isInitialized) {
        final response = await SupabaseService.client
            .from('videos')
            .select('category')
            .not('category', 'is', null);
        
        final categories = response
            .map((item) => item['category']?.toString())
            .where((category) => category != null && category.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
        
        categories.sort();
        return categories;
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des catégories: $e');
    }

    // Fallback vers les catégories de test
    return ['Plats principaux', 'Desserts', 'Entrées', 'Soupes', 'Boissons', 'Végétarien'];
  }

  // Obtenir une vidéo par ID
  static Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      if (SupabaseService.isInitialized) {
        final response = await SupabaseService.client
            .from('videos')
            .select('*')
            .eq('id', videoId)
            .maybeSingle();
        
        if (response != null) {
          return response;
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la vidéo: $e');
    }

    // Fallback vers les données de test
    final testVideos = await _getTestVideos();
    try {
      return testVideos.firstWhere(
        (video) => video['id'] == videoId,
      );
    } catch (e) {
      return null;
    }
  }

  // Incrémenter le nombre de vues
  static Future<void> incrementViews(String videoId) async {
    try {
      if (SupabaseService.isInitialized) {
        await SupabaseService.client.rpc('increment_video_views', params: {
          'video_id': videoId,
        });
      }
    } catch (e) {
      print('❌ Erreur lors de l\'incrémentation des vues: $e');
    }
  }

  // Liker une vidéo
  static Future<void> likeVideo(String videoId) async {
    try {
      if (SupabaseService.isInitialized) {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          await SupabaseService.client.from('video_likes').insert({
            'user_id': user.id,
            'video_id': videoId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      print('❌ Erreur lors du like de la vidéo: $e');
    }
  }

  // Unliker une vidéo
  static Future<void> unlikeVideo(String videoId) async {
    try {
      if (SupabaseService.isInitialized) {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          await SupabaseService.client
              .from('video_likes')
              .delete()
              .eq('user_id', user.id)
              .eq('video_id', videoId);
        }
      }
    } catch (e) {
      print('❌ Erreur lors de l\'unlike de la vidéo: $e');
    }
  }
}
