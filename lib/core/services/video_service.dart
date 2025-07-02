import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class VideoService {
  static final SupabaseClient _supabase = SupabaseService.client;

  // Récupérer les vidéos avec pagination
  static Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await SupabaseService.getVideos(
        searchQuery: searchQuery,
        category: category,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.getVideos: $e');
      }
      return [];
    }
  }

  // Récupérer les vidéos avec pagination infinie
  static Future<List<Map<String, dynamic>>> getInfiniteVideos({
    required int offset,
    required int batchSize,
    List<String> excludeIds = const [],
  }) async {
    try {
      if (SupabaseService.isInitialized) {
        var query = SupabaseService.client.from('videos').select('*');
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
      if (kDebugMode) {
        print('❌ Erreur VideoService.getInfiniteVideos: $e');
      }
      return [];
    }
    return [];
  }

  // Rechercher des vidéos
  static Future<List<Map<String, dynamic>>> searchVideos({
    required String searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await SupabaseService.getVideos(
        searchQuery: searchQuery,
        category: category,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.searchVideos: $e');
      }
      return [];
    }
  }

  // Récupérer une vidéo par ID
  static Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      final videos = await SupabaseService.getVideos(limit: 100);
      return videos.firstWhere(
        (video) => video['id'] == videoId,
        orElse: () => {},
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.getVideoById: $e');
      }
      return null;
    }
  }

  // Récupérer les catégories de vidéos
  static Future<List<String>> getVideoCategories() async {
    try {
      final videos = await SupabaseService.getVideos(limit: 100);
      final categories = videos
          .map((video) => video['category'] as String?)
          .where((category) => category != null)
          .cast<String>()
          .toSet()
          .toList();
      return categories;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des catégories: $e');
      }
      return ['Technique', 'Boulangerie', 'Pâtisserie', 'Cuisine du monde'];
    }
  }

  // Liker une vidéo
  static Future<bool> likeVideo(String videoId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de liker la vidéo.');
        }
        return false;
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      // Vérifier si l'utilisateur a déjà liké cette vidéo
      final existingLike = await SupabaseService.client
          .from('video_likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_id', videoId)
          .maybeSingle();

      if (existingLike != null) {
        return true; // Déjà liké
      }

      // Ajouter le like
      await SupabaseService.client.from('video_likes').insert({
        'user_id': user.id,
        'video_id': videoId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Incrémenter le compteur de likes
      final currentVideo = await SupabaseService.client
          .from('videos')
          .select('likes')
          .eq('id', videoId)
          .maybeSingle();

      if (currentVideo != null) {
        final currentLikes = currentVideo['likes'] as int? ?? 0;
        await SupabaseService.client
            .from('videos')
            .update({'likes': currentLikes + 1}).eq('id', videoId);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du like: $e');
      }
      return false;
    }
  }

  // Unliker une vidéo
  static Future<bool> unlikeVideo(String videoId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible d\'unliker la vidéo.');
        }
        return false;
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      // Supprimer le like
      await SupabaseService.client
          .from('video_likes')
          .delete()
          .eq('user_id', user.id)
          .eq('video_id', videoId);

      // Décrémenter le compteur de likes
      final currentVideo = await SupabaseService.client
          .from('videos')
          .select('likes')
          .eq('id', videoId)
          .maybeSingle();

      if (currentVideo != null) {
        final currentLikes = currentVideo['likes'] as int? ?? 0;
        await SupabaseService.client.from('videos').update({
          'likes': (currentLikes - 1).clamp(0, double.infinity).toInt()
        }).eq('id', videoId);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du unlike: $e');
      }
      return false;
    }
  }

  // Vérifier si une vidéo est likée
  static Future<bool> isVideoLiked(String videoId) async {
    try {
      if (!SupabaseService.isInitialized) {
        return false;
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      final existingLike = await SupabaseService.client
          .from('video_likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_id', videoId)
          .maybeSingle();

      return existingLike != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la vérification du like: $e');
      }
      return false;
    }
  }

  // Incrémenter le nombre de vues d'une vidéo
  static Future<void> incrementViews(String videoId) async {
    try {
      if (kDebugMode) {
        print('📊 Incrémentation des vues pour la vidéo: $videoId');
      }
      // TODO: Implémenter l'incrémentation des vues dans Supabase
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.incrementViews: $e');
      }
    }
  }

  // Toggle like/unlike
  static Future<void> toggleLike(String videoId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de toggle le like.');
        }
        return;
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      // Vérifier si l'utilisateur a déjà liké cette vidéo
      final existingLike = await SupabaseService.client
          .from('video_likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_id', videoId)
          .maybeSingle();

      if (existingLike != null) {
        // Supprimer le like
        await SupabaseService.client
            .from('video_likes')
            .delete()
            .eq('user_id', user.id)
            .eq('video_id', videoId);

        // Décrémenter le compteur de likes
        final currentVideo = await SupabaseService.client
            .from('videos')
            .select('likes')
            .eq('id', videoId)
            .maybeSingle();

        if (currentVideo != null) {
          final currentLikes = currentVideo['likes'] as int? ?? 0;
          await SupabaseService.client.from('videos').update({
            'likes': (currentLikes - 1).clamp(0, double.infinity).toInt()
          }).eq('id', videoId);
        }
      } else {
        // Ajouter le like
        await SupabaseService.client.from('video_likes').insert({
          'user_id': user.id,
          'video_id': videoId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Incrémenter le compteur de likes
        final currentVideo = await SupabaseService.client
            .from('videos')
            .select('likes')
            .eq('id', videoId)
            .maybeSingle();

        if (currentVideo != null) {
          final currentLikes = currentVideo['likes'] as int? ?? 0;
          await SupabaseService.client
              .from('videos')
              .update({'likes': currentLikes + 1}).eq('id', videoId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du toggle like: $e');
      }
    }
  }

  // Récupérer les vidéos populaires
  static Future<List<Map<String, dynamic>>> getPopularVideos({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*')
          .order('likes', ascending: false)
          .order('views', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Récupérer les vidéos récentes
  static Future<List<Map<String, dynamic>>> getRecentVideos({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
