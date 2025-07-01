import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class VideoService {
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
    int offset = 0,
    int batchSize = 10,
    List<String> excludeIds = const [],
  }) async {
    try {
      return await SupabaseService.getVideos(
        limit: batchSize,
        offset: offset,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.getInfiniteVideos: $e');
      }
      return [];
    }
  }

  // Rechercher des vidéos
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      return await SupabaseService.getVideos(
        searchQuery: query,
        limit: 50,
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

  // Liker/Unliker une vidéo
  static Future<void> toggleLike(String videoId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible de liker la vidéo.');
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
          await SupabaseService.client
              .from('videos')
              .update({'likes': (currentLikes - 1).clamp(0, double.infinity).toInt()})
              .eq('id', videoId);
        }
      } else {
        // Ajouter le like
        await SupabaseService.client
            .from('video_likes')
            .insert({
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
              .update({'likes': currentLikes + 1})
              .eq('id', videoId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du toggle like: $e');
      }
    }
  }

  // Vérifier si l'utilisateur a liké une vidéo
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

  // Liker une vidéo
  static Future<void> likeVideo(String videoId) async {
    try {
      if (kDebugMode) {
        print('👍 Like pour la vidéo: $videoId');
      }
      // TODO: Implémenter le système de likes dans Supabase
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur VideoService.likeVideo: $e');
      }
    }
  }
}
