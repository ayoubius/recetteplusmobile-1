import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class VideoService {
  static const String _baseUrl = 'http://localhost:3000'; // URL de votre serveur JSON
  
  // Méthode pour obtenir les vidéos avec gestion d'erreur améliorée
  static Future<List<Map<String, dynamic>>> getVideos({
    String? category,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      // D'abord essayer avec Supabase si disponible
      if (SupabaseService.isInitialized) {
        return await _getVideosFromSupabase(
          category: category,
          limit: limit,
          offset: offset,
        );
      }
      
      // Sinon utiliser le serveur JSON local
      return await _getVideosFromJson(
        category: category,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Erreur lors du chargement des vidéos: $e');
      // Retourner des vidéos de test en cas d'erreur
      return _getTestVideos();
    }
  }

  static Future<List<Map<String, dynamic>>> _getVideosFromSupabase({
    String? category,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = SupabaseService.client
          .from('videos')
          .select('*')
          .order('created_at', ascending: false);

      if (category != null && category != 'Tous') {
        query = query.eq('category', category);
      }

      final response = await query
          .range(offset, offset + limit - 1)
          .execute();

      if (response.error != null) {
        throw Exception('Erreur Supabase: ${response.error!.message}');
      }

      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((item) => _processVideoData(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Erreur Supabase: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _getVideosFromJson({
    String? category,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/videos'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        var videos = data.map((item) => _processVideoData(item as Map<String, dynamic>)).toList();

        // Filtrer par catégorie si spécifiée
        if (category != null && category != 'Tous') {
          videos = videos.where((video) => video['category'] == category).toList();
        }

        // Appliquer la pagination
        final startIndex = offset;
        final endIndex = (startIndex + limit).clamp(0, videos.length);
        
        if (startIndex >= videos.length) {
          return [];
        }

        return videos.sublist(startIndex, endIndex);
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors du chargement depuis JSON: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _processVideoData(Map<String, dynamic> videoData) {
    // Valider et nettoyer les données vidéo
    return {
      'id': videoData['id']?.toString() ?? '',
      'title': videoData['title']?.toString() ?? 'Vidéo sans titre',
      'description': videoData['description']?.toString() ?? '',
      'video_url': _validateVideoUrl(videoData['video_url']?.toString()),
      'thumbnail': _validateImageUrl(videoData['thumbnail']?.toString()),
      'duration': _parseDuration(videoData['duration']),
      'category': videoData['category']?.toString() ?? 'Général',
      'likes': _parseInt(videoData['likes']) ?? 0,
      'views': _parseInt(videoData['views']) ?? 0,
      'recipe_id': videoData['recipe_id']?.toString(),
      'created_at': videoData['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  static String? _validateVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Vérifier si l'URL est valide
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return url;
      }
    } catch (e) {
      print('URL vidéo invalide: $url');
    }
    
    return null;
  }

  static String? _validateImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return url;
      }
    } catch (e) {
      print('URL image invalide: $url');
    }
    
    return null;
  }

  static int _parseDuration(dynamic duration) {
    if (duration == null) return 0;
    
    if (duration is int) return duration;
    if (duration is String) {
      return int.tryParse(duration) ?? 0;
    }
    
    return 0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    
    return null;
  }

  // Vidéos de test pour le développement
  static List<Map<String, dynamic>> _getTestVideos() {
    return [
      {
        'id': 'test_1',
        'title': 'Recette de Pâtes Carbonara',
        'description': 'Une délicieuse recette de pâtes carbonara traditionnelle italienne.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail': 'https://via.placeholder.com/400x600/FF6B6B/FFFFFF?text=Carbonara',
        'duration': 180,
        'category': 'Plats principaux',
        'likes': 245,
        'views': 1520,
        'recipe_id': 'recipe_1',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'test_2',
        'title': 'Tarte aux Pommes Maison',
        'description': 'Apprenez à faire une tarte aux pommes parfaite avec une pâte croustillante.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'thumbnail': 'https://via.placeholder.com/400x600/4ECDC4/FFFFFF?text=Tarte+Pommes',
        'duration': 240,
        'category': 'Desserts',
        'likes': 189,
        'views': 892,
        'recipe_id': 'recipe_2',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'test_3',
        'title': 'Smoothie Vert Détox',
        'description': 'Un smoothie vert rafraîchissant et plein de vitamines pour bien commencer la journée.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'thumbnail': 'https://via.placeholder.com/400x600/95E1D3/FFFFFF?text=Smoothie+Vert',
        'duration': 120,
        'category': 'Boissons',
        'likes': 156,
        'views': 634,
        'recipe_id': 'recipe_3',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'id': 'test_4',
        'title': 'Salade César Authentique',
        'description': 'La vraie recette de la salade César avec sa sauce crémeuse et ses croûtons maison.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'thumbnail': 'https://via.placeholder.com/400x600/F38BA8/FFFFFF?text=Salade+César',
        'duration': 200,
        'category': 'Entrées',
        'likes': 203,
        'views': 1105,
        'recipe_id': 'recipe_4',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
      {
        'id': 'test_5',
        'title': 'Burger Végétarien Gourmand',
        'description': 'Un burger végétarien savoureux avec un steak de légumes fait maison.',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'thumbnail': 'https://via.placeholder.com/400x600/A8DADC/FFFFFF?text=Burger+Végé',
        'duration': 300,
        'category': 'Végétarien',
        'likes': 178,
        'views': 756,
        'recipe_id': 'recipe_5',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
    ];
  }

  static Future<List<Map<String, dynamic>>> getInfiniteVideos({
    required int offset,
    required int batchSize,
    List<String> excludeIds = const [],
  }) async {
    try {
      final allVideos = await getVideos(limit: 100); // Récupérer plus de vidéos
      
      // Exclure les vidéos déjà chargées
      final filteredVideos = allVideos
          .where((video) => !excludeIds.contains(video['id'].toString()))
          .toList();

      // Appliquer la pagination
      final startIndex = offset;
      final endIndex = (startIndex + batchSize).clamp(0, filteredVideos.length);
      
      if (startIndex >= filteredVideos.length) {
        return [];
      }

      return filteredVideos.sublist(startIndex, endIndex);
    } catch (e) {
      print('Erreur lors du chargement infini: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final allVideos = await getVideos(limit: 100);
      
      final searchQuery = query.toLowerCase();
      return allVideos.where((video) {
        final title = video['title']?.toString().toLowerCase() ?? '';
        final description = video['description']?.toString().toLowerCase() ?? '';
        final category = video['category']?.toString().toLowerCase() ?? '';
        
        return title.contains(searchQuery) ||
               description.contains(searchQuery) ||
               category.contains(searchQuery);
      }).toList();
    } catch (e) {
      print('Erreur lors de la recherche: $e');
      return [];
    }
  }

  // Méthode pour vérifier si une URL vidéo est accessible
  static Future<bool> isVideoUrlAccessible(String url) async {
    try {
      final response = await http.head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('URL vidéo non accessible: $url - $e');
      return false;
    }
  }

  // Méthode pour obtenir des statistiques sur les vidéos
  static Future<Map<String, dynamic>> getVideoStats() async {
    try {
      final videos = await getVideos(limit: 1000);
      
      final totalVideos = videos.length;
      final totalViews = videos.fold<int>(0, (sum, video) => sum + (video['views'] as int? ?? 0));
      final totalLikes = videos.fold<int>(0, (sum, video) => sum + (video['likes'] as int? ?? 0));
      
      final categoryCounts = <String, int>{};
      for (final video in videos) {
        final category = video['category'] as String? ?? 'Général';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      return {
        'total_videos': totalVideos,
        'total_views': totalViews,
        'total_likes': totalLikes,
        'categories': categoryCounts,
      };
    } catch (e) {
      print('Erreur lors du calcul des statistiques: $e');
      return {
        'total_videos': 0,
        'total_views': 0,
        'total_likes': 0,
        'categories': <String, int>{},
      };
    }
  }
}
