import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class VideoService {
  static const String _baseUrl = 'http://localhost:3000';

  // Cache des vidéos
  static final Map<String, List<Map<String, dynamic>>> _videoCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 15);

  // Configuration des retry
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Métriques
  static final Map<String, int> _requestCount = {};
  static final Map<String, int> _errorCount = {};
  static final Map<String, Duration> _responseTimes = {};

  // Configuration
  static bool _enableCache = true;
  static bool _enableRetry = true;
  static bool _enableMetrics = true;
  static Duration _timeout = const Duration(seconds: 10);

  // Getters pour la configuration
  static bool get enableCache => _enableCache;
  static bool get enableRetry => _enableRetry;
  static bool get enableMetrics => _enableMetrics;
  static Duration get timeout => _timeout;

  // Setters pour la configuration
  static set enableCache(bool value) => _enableCache = value;
  static set enableRetry(bool value) => _enableRetry = value;
  static set enableMetrics(bool value) => _enableMetrics = value;
  static set timeout(Duration value) => _timeout = value;

  /// Obtient les vidéos avec gestion d'erreur améliorée, cache, et mélange aléatoire si demandé
  static Future<List<Map<String, dynamic>>> getVideos({
    String? category,
    int limit = 10,
    int offset = 0,
    bool forceRefresh = false,
    bool shuffle = false,
  }) async {
    final cacheKey = 'videos_${category ?? 'all'}_${limit}_$offset${shuffle ? '_shuffled' : ''}';

    // Vérifier le cache
    if (_enableCache && !forceRefresh && _isCacheValid(cacheKey)) {
      _incrementRequestCount('cache_hit');
      return _videoCache[cacheKey]!;
    }

    _incrementRequestCount('api_request');
    final stopwatch = Stopwatch()..start();

    try {
      List<Map<String, dynamic>> videos = [];

      // Essayer Supabase en premier
      if (SupabaseService.isInitialized) {
        videos = await _getVideosDirectFromSupabase(
          category: category,
          limit: limit,
          offset: offset,
        );
      } else {
        // Fallback vers JSON local
        videos = await _getVideosFromJsonWithRetry(
          category: category,
          limit: limit,
          offset: offset,
        );
      }

      // Mélanger si demandé
      if (shuffle && videos.isNotEmpty) {
        videos.shuffle();
      }

      // Mettre en cache
      if (_enableCache) {
        _videoCache[cacheKey] = videos;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      _recordResponseTime('getVideos', stopwatch.elapsed);
      return videos;
    } catch (e) {
      _incrementErrorCount('getVideos');
      _recordResponseTime('getVideos', stopwatch.elapsed);
      print('Erreur lors du chargement des vidéos: $e');
      // Retourner le cache expiré si disponible
      if (_enableCache && _videoCache.containsKey(cacheKey)) {
        print('Utilisation du cache expiré en cas d\'erreur');
        return _videoCache[cacheKey]!;
      }
      // Retourner des vidéos de test en dernier recours
      return _getTestVideos();
    }
  }

  /// Version directe, simple et robuste pour Supabase (inspirée old-lib)
  static Future<List<Map<String, dynamic>>> _getVideosDirectFromSupabase({
    String? category,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = SupabaseService.client.from('videos').select();
      if (category != null && category.isNotEmpty && category != 'Tous') {
        query = query.eq('category', category);
      }
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final videos = List<Map<String, dynamic>>.from(response);
      return videos.map(_processVideoData).toList();
    } catch (e) {
      print('❌ Erreur récupération vidéos Supabase: $e');
      return [];
    }
  }

  /// Obtient les vidéos depuis JSON avec retry
  static Future<List<Map<String, dynamic>>> _getVideosFromJsonWithRetry({
    String? category,
    int limit = 10,
    int offset = 0,
  }) async {
    int attempts = 0;

    while (attempts < (_enableRetry ? _maxRetries : 1)) {
      try {
        return await _getVideosFromJson(
          category: category,
          limit: limit,
          offset: offset,
        );
      } catch (e) {
        attempts++;
        _incrementErrorCount('json_request');

        if (attempts >= _maxRetries) {
          rethrow;
        }

        print(
            'Tentative $attempts échouée, nouvelle tentative dans ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay * attempts);
      }
    }

    throw Exception('Échec après $_maxRetries tentatives');
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
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        var videos = data
            .map((item) => _processVideoData(item as Map<String, dynamic>))
            .toList();

        // Filtrer par catégorie si spécifiée
        if (category != null && category != 'Tous') {
          videos =
              videos.where((video) => video['category'] == category).toList();
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

  static Map<String, dynamic> _processVideoData(
      Map<String, dynamic> videoData) {
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
      'created_at': videoData['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
      'quality': _parseVideoQuality(videoData['quality']),
      'tags': _parseTags(videoData['tags']),
    };
  }

  static String? _validateVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;

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

  static String _parseVideoQuality(dynamic quality) {
    if (quality == null) return 'auto';

    final qualityStr = quality.toString().toLowerCase();
    if (['low', 'medium', 'high', 'auto'].contains(qualityStr)) {
      return qualityStr;
    }

    return 'auto';
  }

  static List<String> _parseTags(dynamic tags) {
    if (tags == null) return [];

    if (tags is List) {
      return tags.map((tag) => tag.toString()).toList();
    }

    if (tags is String) {
      return tags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    return [];
  }

  // Méthodes de gestion du cache
  static bool _isCacheValid(String key) {
    if (!_videoCache.containsKey(key)) return false;

    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiration;
  }

  static void clearCache() {
    _videoCache.clear();
    _cacheTimestamps.clear();
    print('Cache vidéo vidé');
  }

  static void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) >= _cacheExpiration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _videoCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      print('${expiredKeys.length} entrées de cache expirées supprimées');
    }
  }

  // Méthodes de métriques
  static void _incrementRequestCount(String type) {
    if (!_enableMetrics) return;
    _requestCount[type] = (_requestCount[type] ?? 0) + 1;
  }

  static void _incrementErrorCount(String type) {
    if (!_enableMetrics) return;
    _errorCount[type] = (_errorCount[type] ?? 0) + 1;
  }

  static void _recordResponseTime(String operation, Duration duration) {
    if (!_enableMetrics) return;
    _responseTimes[operation] = duration;
  }

  static Map<String, dynamic> getMetrics() {
    if (!_enableMetrics) return {};

    return {
      'requests': Map<String, int>.from(_requestCount),
      'errors': Map<String, int>.from(_errorCount),
      'response_times': _responseTimes
          .map((key, value) => MapEntry(key, value.inMilliseconds)),
      'cache_size': _videoCache.length,
      'cache_hit_rate': _calculateCacheHitRate(),
    };
  }

  static double _calculateCacheHitRate() {
    final totalRequests =
        _requestCount.values.fold(0, (sum, count) => sum + count);
    final cacheHits = _requestCount['cache_hit'] ?? 0;

    if (totalRequests == 0) return 0.0;
    return cacheHits / totalRequests;
  }

  // Vidéos de test pour le développement
  static List<Map<String, dynamic>> _getTestVideos() {
    return [
      {
        'id': 'test_1',
        'title': 'Recette de Pâtes Carbonara',
        'description':
            'Une délicieuse recette de pâtes carbonara traditionnelle italienne.',
        'video_url':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail':
            'https://via.placeholder.com/400x600/FF6B6B/FFFFFF?text=Carbonara',
        'duration': 180,
        'category': 'Plats principaux',
        'likes': 245,
        'views': 1520,
        'recipe_id': 'recipe_1',
        'created_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'quality': 'high',
        'tags': ['italien', 'pâtes', 'carbonara', 'traditionnel'],
      },
      {
        'id': 'test_2',
        'title': 'Tarte aux Pommes Maison',
        'description':
            'Apprenez à faire une tarte aux pommes parfaite avec une pâte croustillante.',
        'video_url':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'thumbnail':
            'https://via.placeholder.com/400x600/4ECDC4/FFFFFF?text=Tarte+Pommes',
        'duration': 240,
        'category': 'Desserts',
        'likes': 189,
        'views': 892,
        'recipe_id': 'recipe_2',
        'created_at':
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'quality': 'medium',
        'tags': ['dessert', 'tarte', 'pommes', 'maison'],
      },
      {
        'id': 'test_3',
        'title': 'Smoothie Vert Détox',
        'description':
            'Un smoothie vert rafraîchissant et plein de vitamines pour bien commencer la journée.',
        'video_url':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'thumbnail':
            'https://via.placeholder.com/400x600/95E1D3/FFFFFF?text=Smoothie+Vert',
        'duration': 120,
        'category': 'Boissons',
        'likes': 156,
        'views': 634,
        'recipe_id': 'recipe_3',
        'created_at':
            DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'quality': 'low',
        'tags': ['smoothie', 'détox', 'vert', 'vitamines'],
      },
      {
        'id': 'test_4',
        'title': 'Salade César Authentique',
        'description':
            'La vraie recette de la salade César avec sa sauce crémeuse et ses croûtons maison.',
        'video_url':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'thumbnail':
            'https://via.placeholder.com/400x600/F38BA8/FFFFFF?text=Salade+César',
        'duration': 200,
        'category': 'Entrées',
        'likes': 203,
        'views': 1105,
        'recipe_id': 'recipe_4',
        'created_at':
            DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'quality': 'high',
        'tags': ['salade', 'césar', 'authentique', 'entrée'],
      },
      {
        'id': 'test_5',
        'title': 'Burger Végétarien Gourmand',
        'description':
            'Un burger végétarien savoureux avec un steak de légumes fait maison.',
        'video_url':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'thumbnail':
            'https://via.placeholder.com/400x600/A8DADC/FFFFFF?text=Burger+Végé',
        'duration': 300,
        'category': 'Végétarien',
        'likes': 178,
        'views': 756,
        'recipe_id': 'recipe_5',
        'created_at':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'quality': 'medium',
        'tags': ['burger', 'végétarien', 'gourmand', 'légumes'],
      },
    ];
  }

  static Future<List<Map<String, dynamic>>> getInfiniteVideos({
    required int offset,
    required int batchSize,
    List<String> excludeIds = const [],
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'infinite_$offset\_$batchSize\_${excludeIds.join('_')}';

    if (_enableCache && !forceRefresh && _isCacheValid(cacheKey)) {
      _incrementRequestCount('cache_hit');
      return _videoCache[cacheKey]!;
    }

    _incrementRequestCount('infinite_request');
    final stopwatch = Stopwatch()..start();

    try {
      final allVideos = await getVideos(limit: 100, forceRefresh: forceRefresh);

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

      final result = filteredVideos.sublist(startIndex, endIndex);

      // Mettre en cache
      if (_enableCache) {
        _videoCache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      _recordResponseTime('getInfiniteVideos', stopwatch.elapsed);
      return result;
    } catch (e) {
      _incrementErrorCount('infinite_request');
      _recordResponseTime('getInfiniteVideos', stopwatch.elapsed);

      print('Erreur lors du chargement infini: $e');

      // Retourner le cache expiré si disponible
      if (_enableCache && _videoCache.containsKey(cacheKey)) {
        return _videoCache[cacheKey]!;
      }

      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchVideos(
    String query, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'search_$query';

    if (_enableCache && !forceRefresh && _isCacheValid(cacheKey)) {
      _incrementRequestCount('cache_hit');
      return _videoCache[cacheKey]!;
    }

    _incrementRequestCount('search_request');
    final stopwatch = Stopwatch()..start();

    try {
      final allVideos = await getVideos(limit: 100, forceRefresh: forceRefresh);

      final searchQuery = query.toLowerCase();
      final results = allVideos.where((video) {
        final title = video['title']?.toString().toLowerCase() ?? '';
        final description =
            video['description']?.toString().toLowerCase() ?? '';
        final category = video['category']?.toString().toLowerCase() ?? '';
        final tags = (video['tags'] as List<String>? ?? [])
            .map((tag) => tag.toLowerCase())
            .toList();

        return title.contains(searchQuery) ||
            description.contains(searchQuery) ||
            category.contains(searchQuery) ||
            tags.any((tag) => tag.contains(searchQuery));
      }).toList();

      // Mettre en cache
      if (_enableCache) {
        _videoCache[cacheKey] = results;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      _recordResponseTime('searchVideos', stopwatch.elapsed);
      return results;
    } catch (e) {
      _incrementErrorCount('search_request');
      _recordResponseTime('searchVideos', stopwatch.elapsed);

      print('Erreur lors de la recherche: $e');

      // Retourner le cache expiré si disponible
      if (_enableCache && _videoCache.containsKey(cacheKey)) {
        return _videoCache[cacheKey]!;
      }

      return [];
    }
  }

  /// Like une vidéo (ajoute dans video_likes et incrémente le compteur, fallback si besoin)
  static Future<void> likeVideo(String videoId) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      // Vérifier si déjà liké
      final existing = await SupabaseService.client
          .from('video_likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_id', videoId)
          .maybeSingle();
      if (existing != null) {
        throw Exception('Déjà liké');
      }
      // Ajouter le like
      await SupabaseService.client.from('video_likes').insert({
        'user_id': user.id,
        'video_id': videoId,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Incrémenter le compteur de likes sur la vidéo (RPC ou fallback)
      try {
        await SupabaseService.client
            .rpc('increment_video_likes', params: {'video_id': videoId});
      } catch (e) {
        print('⚠️ Erreur RPC increment_video_likes, fallback: $e');
        final video = await SupabaseService.client
            .from('videos')
            .select('likes')
            .eq('id', videoId)
            .maybeSingle();
        if (video != null) {
          final currentLikes = video['likes'] ?? 0;
          await SupabaseService.client
              .from('videos')
              .update({'likes': currentLikes + 1})
              .eq('id', videoId);
        }
      }
    } catch (e) {
      print('Erreur lors du like vidéo: $e');
      // Ne pas rethrow pour éviter crash UI
    }
  }

  /// Unlike une vidéo (supprime dans video_likes et décrémente le compteur, fallback si besoin)
  static Future<void> unlikeVideo(String videoId) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      // Vérifier si déjà liké
      final existing = await SupabaseService.client
          .from('video_likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_id', videoId)
          .maybeSingle();
      if (existing == null) {
        throw Exception('Pas encore liké');
      }
      // Supprimer le like
      await SupabaseService.client
          .from('video_likes')
          .delete()
          .eq('user_id', user.id)
          .eq('video_id', videoId);
      // Décrémenter le compteur de likes sur la vidéo (RPC ou fallback)
      try {
        await SupabaseService.client
            .rpc('decrement_video_likes', params: {'video_id': videoId});
      } catch (e) {
        print('⚠️ Erreur RPC decrement_video_likes, fallback: $e');
        final video = await SupabaseService.client
            .from('videos')
            .select('likes')
            .eq('id', videoId)
            .maybeSingle();
        if (video != null && (video['likes'] ?? 0) > 0) {
          await SupabaseService.client
              .from('videos')
              .update({'likes': (video['likes'] ?? 1) - 1})
              .eq('id', videoId);
        }
      }
    } catch (e) {
      print('Erreur lors du unlike vidéo: $e');
      // Ne pas rethrow pour éviter crash UI
    }
  }

  // Méthode pour vérifier si une URL vidéo est accessible avec retry
  static Future<bool> isVideoUrlAccessible(String url,
      {int maxRetries = 2}) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        final response =
            await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (e) {
        attempts++;
        print('Tentative $attempts échouée pour vérifier l\'URL: $url');

        if (attempts >= maxRetries) {
          print('URL vidéo non accessible après $maxRetries tentatives: $url');
          return false;
        }

        await Future.delayed(Duration(seconds: attempts));
      }
    }

    return false;
  }

  // Méthode pour obtenir des statistiques sur les vidéos
  static Future<Map<String, dynamic>> getVideoStats() async {
    try {
      final videos = await getVideos(limit: 1000);

      final totalVideos = videos.length;
      final totalViews = videos.fold<int>(
          0, (sum, video) => sum + (video['views'] as int? ?? 0));
      final totalLikes = videos.fold<int>(
          0, (sum, video) => sum + (video['likes'] as int? ?? 0));

      final categoryCounts = <String, int>{};
      final qualityCounts = <String, int>{};
      final tagCounts = <String, int>{};

      for (final video in videos) {
        final category = video['category'] as String? ?? 'Général';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

        final quality = video['quality'] as String? ?? 'auto';
        qualityCounts[quality] = (qualityCounts[quality] ?? 0) + 1;

        final tags = video['tags'] as List<String>? ?? [];
        for (final tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final popularTags = sortedTags
          .take(10)
          .map((e) => {'tag': e.key, 'count': e.value})
          .toList();

      return {
        'total_videos': totalVideos,
        'total_views': totalViews,
        'total_likes': totalLikes,
        'categories': categoryCounts,
        'qualities': qualityCounts,
        'popular_tags': popularTags,
        'service_metrics': getMetrics(),
      };
    } catch (e) {
      print('Erreur lors du calcul des statistiques: $e');
      return {
        'total_videos': 0,
        'total_views': 0,
        'total_likes': 0,
        'categories': <String, int>{},
        'qualities': <String, int>{},
        'popular_tags': <Map<String, dynamic>>[],
        'service_metrics': getMetrics(),
      };
    }
  }
}
