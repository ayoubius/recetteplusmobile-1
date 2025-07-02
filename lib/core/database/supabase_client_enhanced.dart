import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientEnhanced {
  static final SupabaseClient _client = Supabase.instance.client;
  
  // Méthodes pour les tables principales
  static SupabaseQueryBuilder get videos => _client.from('videos');
  static SupabaseQueryBuilder get recipes => _client.from('recipes');
  static SupabaseQueryBuilder get products => _client.from('products');
  static SupabaseQueryBuilder get profiles => _client.from('profiles');
  static SupabaseQueryBuilder get orders => _client.from('orders');
  
  // Méthodes pour les paniers (système complexe)
  static SupabaseQueryBuilder get cartItems => _client.from('cart_items');
  static SupabaseQueryBuilder get userCarts => _client.from('user_carts');
  static SupabaseQueryBuilder get recipeCarts => _client.from('recipe_carts');
  static SupabaseQueryBuilder get personalCarts => _client.from('personal_carts');
  static SupabaseQueryBuilder get preconfiguredCarts => _client.from('preconfigured_carts');
  
  // Méthodes pour la gestion
  static SupabaseQueryBuilder get adminPermissions => _client.from('admin_permissions');
  static SupabaseQueryBuilder get deliveryZones => _client.from('delivery_zones');
  static SupabaseQueryBuilder get deliveryTracking => _client.from('delivery_tracking');
  
  // Méthodes pour les catégories
  static SupabaseQueryBuilder get productCategories => _client.from('product_categories');
  static SupabaseQueryBuilder get recipeCategories => _client.from('recipe_categories');
  
  // Méthodes utilitaires
  static SupabaseQueryBuilder get favorites => _client.from('favorites');
  static SupabaseQueryBuilder get userHistory => _client.from('user_history');
  static SupabaseQueryBuilder get userLocations => _client.from('user_locations');
  static SupabaseQueryBuilder get videoLikes => _client.from('video_likes');
  
  // Fonctions RPC
  static Future<bool> hasAdminPermission(String permissionType) async {
    final response = await _client.rpc('has_admin_permission', 
      params: {'permission_type': permissionType});
    return response as bool;
  }
  
  static Future<void> incrementVideoViews(String videoId) async {
    await _client.rpc('increment_video_views', 
      params: {'video_id': videoId});
  }
  
  static Future<void> incrementRecipeViews(String recipeId) async {
    await _client.rpc('increment_recipe_views', 
      params: {'recipe_uuid': recipeId});
  }
  
  static Future<Map<String, dynamic>> getPersonalCartDetails(String cartId) async {
    final response = await _client.rpc('get_personal_cart_details', 
      params: {'cart_id': cartId});
    return response as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getRecipeCartDetails(String cartId) async {
    final response = await _client.rpc('get_recipe_cart_details', 
      params: {'cart_id': cartId});
    return response as Map<String, dynamic>;
  }
}
