import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class VideoService {
  static final SupabaseClient _supabase = SupabaseService.client;

  // Récupérer toutes les vidéos avec pagination
  static Future<List<Map<String, dynamic>>> getVideos({
    int limit = 20,
    int offset = 0,
    String? category,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from('videos')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('title', '%$searchQuery%');
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors du chargement des vidéos: $e');
    }
  }

  // Récupérer une vidéo par ID
  static Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*')
          .eq('id', videoId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  // Liker une vidéo
  static Future<bool> likeVideo(String videoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Vérifier si déjà liké
      final existingLike = await _supabase
          .from('video_likes')
          .select('id')
          .eq('video_id', videoId)
          .eq('profile_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        return true; // Déjà liké
      }

      // Ajouter le like
      await _supabase.from('video_likes').insert({
        'video_id': videoId,
        'profile_id': userId,
      });

      // Incrémenter le compteur de likes
      await _supabase.rpc('increment_video_likes', params: {
        'video_id': videoId,
      });

      return true;
    } catch (e) {
      throw Exception('Erreur lors du like: $e');
    }
  }

  // Unliker une vidéo
  static Future<bool> unlikeVideo(String videoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Supprimer le like
      await _supabase
          .from('video_likes')
          .delete()
          .eq('video_id', videoId)
          .eq('profile_id', userId);

      // Décrémenter le compteur de likes
      await _supabase.rpc('decrement_video_likes', params: {
        'video_id': videoId,
      });

      return true;
    } catch (e) {
      throw Exception('Erreur lors du unlike: $e');
    }
  }

  // Vérifier si une vidéo est likée
  static Future<bool> isVideoLiked(String videoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('video_likes')
          .select('id')
          .eq('video_id', videoId)
          .eq('profile_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Récupérer les catégories de vidéos
  static Future<List<String>> getVideoCategories() async {
    try {
      final response = await _supabase
          .from('videos')
          .select('category')
          .not('category', 'is', null);

      final categories = <String>{};
      for (final item in response) {
        final category = item['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // Incrémenter le nombre de vues
  static Future<void> incrementViewCount(String videoId) async {
    try {
      await _supabase.rpc('increment_video_views', params: {
        'video_id': videoId,
      });
    } catch (e) {
      // Ignore les erreurs de vue
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
