import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class VideoService {
  // Récupérer les vidéos avec pagination infinie
  static Future<List<Map<String, dynamic>>> getInfiniteVideos({
    int page = 0,
    int limit = 10,
    String? category,
  }) async {
    try {
      final offset = page * limit;
      return await SupabaseService.getVideos(
        category: category,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération des vidéos infinies: $e');
      }
      return [];
    }
  }

  // Rechercher des vidéos
  static Future<List<Map<String, dynamic>>> searchVideos({
    required String query,
    String? category,
    int limit = 20,
  }) async {
    try {
      return await SupabaseService.getVideos(
        searchQuery: query,
        category: category,
        limit: limit,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la recherche de vidéos: $e');
      }
      return [];
    }
  }

  // Récupérer toutes les vidéos
  static Future<List<Map<String, dynamic>>> getAllVideos({
    String? category,
    int limit = 50,
  }) async {
    try {
      return await SupabaseService.getVideos(
        category: category,
        limit: limit,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la récupération de toutes les vidéos: $e');
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
        print('❌ Erreur lors de la récupération de la vidéo par ID: $e');
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
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('❌ Supabase non initialisé, impossible d\'incrémenter les vues.');
        }
        return;
      }

      // Récupérer la vidéo actuelle
      final currentVideo = await SupabaseService.client
          .from('videos')
          .select('views')
          .eq('id', videoId)
          .maybeSingle();

      if (currentVideo != null) {
        final currentViews = currentVideo['views'] as int? ?? 0;
        
        // Mettre à jour le nombre de vues
        await SupabaseService.client
            .from('videos')
            .update({'views': currentViews + 1})
            .eq('id', videoId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'incrémentation des vues: $e');
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
}
