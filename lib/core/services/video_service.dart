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
        'thumbnail_url': 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Carbonara',
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
        'thumbnail_url': 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Tarte+Pommes',
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
        'thumbnail_url': 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Salade+César',
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
        'thumbnail_url': 'https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Soupe+Légumes',
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
        'thumbnail_url': 'https://via.placeholder.com/400x300/FECA57/FFFFFF?text=Cookies',
        'duration': 360,
        'category': 'Desserts',
        'likes': 1100,
        'views': 18000,
        'created_at': '2024-01-11T09:30:00Z',
        'recipe_id': '5',
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
    return ['Plats principaux', 'Desserts', 'Entrées', 'Soupes', 'Boissons'];
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
    return testVideos.firstWhere(
      (video) => video['id'] == videoId,
      orElse: () => {},
    );
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
