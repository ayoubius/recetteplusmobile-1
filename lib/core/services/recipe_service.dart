import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class RecipeService {
  // Helper to get client safely
  static SupabaseClient? get _client =>
      SupabaseService.isInitialized ? SupabaseService.client : null;

  // Récupérer une recette par ID avec ses produits
  static Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible de récupérer la recette.');
      return null;
    }
    try {
      final response = await _client!
          .from('recipes')
          .select('*')
          .eq('id', recipeId)
          .maybeSingle();
      if (response != null) {
        return await _formatRecipeData(response);
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération de la recette: $e');
      return null;
    }
  }

  // Récupérer toutes les recettes avec filtres optionnels
  static Future<List<Map<String, dynamic>>> getRecipes({
    String? searchQuery,
    String? category,
    String? difficulty,
    int? maxPrepTime,
    double? minRating,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible de récupérer les recettes.');
      return [];
    }
    try {
      var query = _client!.from('recipes').select('*');

      // Appliquer les filtres
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.eq('difficulty', difficulty);
      }

      if (maxPrepTime != null) {
        query = query.lte('prep_time', maxPrepTime);
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      final response = await query
          .order('rating', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var recipe in response) {
          final formattedRecipe = await _formatRecipeData(recipe);
          recipes.add(formattedRecipe);
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des recettes: $e');
      return [];
    }
  }

  // Récupérer les recettes populaires
  static Future<List<Map<String, dynamic>>> getPopularRecipes(
      {int limit = 10}) async {
    if (!SupabaseService.isInitialized) {
      print(
          '❌ Supabase non initialisé, impossible de récupérer les recettes populaires.');
      return [];
    }
    try {
      final response = await _client!
          .from('recipes')
          .select('*')
          .order('rating', ascending: false)
          .order('view_count', ascending: false)
          .limit(limit);
      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var recipe in response) {
          final formattedRecipe = await _formatRecipeData(recipe);
          recipes.add(formattedRecipe);
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des recettes populaires: $e');
      return [];
    }
  }

  // Récupérer les recettes récentes
  static Future<List<Map<String, dynamic>>> getRecentRecipes(
      {int limit = 10}) async {
    if (!SupabaseService.isInitialized) {
      print(
          '❌ Supabase non initialisé, impossible de récupérer les recettes récentes.');
      return [];
    }
    try {
      final response = await _client!
          .from('recipes')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var recipe in response) {
          final formattedRecipe = await _formatRecipeData(recipe);
          recipes.add(formattedRecipe);
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des recettes récentes: $e');
      return [];
    }
  }

  // Incrémenter le compteur de vues
  static Future<void> incrementViewCount(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible d\'incrémenter les vues.');
      return;
    }
    try {
      await _client!
          .rpc('increment_recipe_views', params: {'recipe_uuid': recipeId});
    } catch (e) {
      print('⚠️ Erreur lors de l\'incrémentation des vues: $e');
      // Fallback: mise à jour manuelle
      try {
        final recipe = await _client!
            .from('recipes')
            .select('view_count')
            .eq('id', recipeId)
            .maybeSingle();
        final currentViews = recipe?['view_count'] ?? 0;
        await _client!
            .from('recipes')
            .update({'view_count': currentViews + 1}).eq('id', recipeId);
      } catch (fallbackError) {
        print('❌ Erreur fallback incrémentation vues: $fallbackError');
      }
    }
  }

  // Ajouter aux favoris (nécessite authentification)
  static Future<bool> addToFavorites(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible d\'ajouter aux favoris.');
      return false;
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return false;
      await _client!.from('favorites').insert({
        'user_id': user.id,
        'recipe_id': recipeId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'ajout aux favoris: $e');
      return false;
    }
  }

  // Retirer des favoris
  static Future<bool> removeFromFavorites(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible de retirer des favoris.');
      return false;
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return false;
      await _client!
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId);
      return true;
    } catch (e) {
      print('❌ Erreur lors de la suppression des favoris: $e');
      return false;
    }
  }

  // Vérifier si une recette est en favoris
  static Future<bool> isFavorite(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible de vérifier les favoris.');
      return false;
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return false;
      final response = await _client!
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('❌ Erreur lors de la vérification des favoris: $e');
      return false;
    }
  }

  // Récupérer les favoris de l'utilisateur
  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    if (!SupabaseService.isInitialized) {
      print('❌ Supabase non initialisé, impossible de récupérer les favoris.');
      return [];
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return [];
      final response = await _client!
          .from('favorites')
          .select('recipe_id')
          .eq('user_id', user.id);
      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var favorite in response) {
          final recipe = await getRecipeById(favorite['recipe_id']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des favoris: $e');
      return [];
    }
  }

  // Ajouter à l'historique
  static Future<void> addToHistory(String recipeId) async {
    if (!SupabaseService.isInitialized) {
      print(
          '❌ Supabase non initialisé, impossible d\'ajouter à l\'historique.');
      return;
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return;
      // Supprimer l'entrée existante s'il y en a une
      await _client!
          .from('user_history')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId);
      // Ajouter la nouvelle entrée
      await _client!.from('user_history').insert({
        'user_id': user.id,
        'recipe_id': recipeId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Erreur lors de l\'ajout à l\'historique: $e');
    }
  }

  // Récupérer l'historique de l'utilisateur
  static Future<List<Map<String, dynamic>>> getUserHistory(
      {int limit = 20}) async {
    if (!SupabaseService.isInitialized) {
      print(
          '❌ Supabase non initialisé, impossible de récupérer l\'historique.');
      return [];
    }
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return [];
      final response = await _client!
          .from('user_history')
          .select('recipe_id')
          .eq('user_id', user.id)
          .order('viewed_at', ascending: false)
          .limit(limit);
      if (response.isNotEmpty) {
        List<Map<String, dynamic>> recipes = [];
        for (var history in response) {
          final recipe = await getRecipeById(history['recipe_id']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        return recipes;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  // Formater les données de recette avec récupération des produits
  static Future<Map<String, dynamic>> _formatRecipeData(
      Map<String, dynamic> rawData) async {
    // Formater le temps de préparation
    String formatTime(int? minutes) {
      if (minutes == null || minutes == 0) return '0 min';
      if (minutes < 60) return '$minutes min';
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) return '${hours}h';
      return '${hours}h ${remainingMinutes}min';
    }

    // Récupérer et formater les ingrédients avec les informations des produits
    Future<List<Map<String, dynamic>>> formatIngredients(
        dynamic ingredientsData) async {
      if (ingredientsData == null) return [];

      List<dynamic> ingredientsList = [];
      if (ingredientsData is List) {
        ingredientsList = ingredientsData;
      } else {
        return [];
      }

      List<Map<String, dynamic>> formattedIngredients = [];

      for (var ingredient in ingredientsList) {
        if (ingredient is Map<String, dynamic> &&
            ingredient.containsKey('productId')) {
          try {
            // Récupérer les informations du produit
            final productResponse = await _client!
                .from('products')
                .select('*')
                .eq('id', ingredient['productId'])
                .maybeSingle();

            if (productResponse != null) {
              formattedIngredients.add({
                'product_id': ingredient['productId'],
                'name': productResponse['name'] ?? 'Produit inconnu',
                'quantity': _parseQuantity(ingredient['quantity']),
                'unit': ingredient['unit'] ?? 'pièce',
                'price': (productResponse['price'] ?? 0.0).toDouble(),
                'image': productResponse['image'],
                'category': productResponse['category'] ?? 'Autre',
                'in_stock': productResponse['in_stock'] ?? true,
                'is_optional': false,
              });
            }
          } catch (e) {
            print(
                '⚠️ Erreur récupération produit ${ingredient['productId']}: $e');
          }
        }
      }

      return formattedIngredients;
    }

    // Formater les instructions
    List<String> formatInstructions(dynamic instructions) {
      if (instructions == null) return [];

      if (instructions is String) {
        return instructions
            .split(RegExp(r'\n|\d+\.'))
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();
      } else if (instructions is List) {
        return instructions
            .map((step) => step?.toString() ?? '')
            .where((step) => step.isNotEmpty)
            .toList();
      }

      return [];
    }

    // Récupérer les ingrédients formatés
    final ingredients = await formatIngredients(rawData['ingredients']);

    // Calculer le coût total de la recette
    double calculateTotalCost(List<Map<String, dynamic>> ingredients) {
      return ingredients.fold(0.0, (total, ingredient) {
        final price = (ingredient['price'] ?? 0.0).toDouble();
        final quantity = (ingredient['quantity'] ?? 0).toDouble();
        return total + (price * quantity);
      });
    }

    return {
      'id': rawData['id']?.toString() ?? '',
      'title': rawData['title']?.toString() ?? 'Recette sans titre',
      'description': rawData['description']?.toString() ?? '',
      'image': rawData['image']?.toString(),
      'category': rawData['category']?.toString() ?? 'Autre',
      'difficulty': rawData['difficulty']?.toString() ?? 'Non spécifiée',
      'prep_time': rawData['prep_time'] ?? 0,
      'cook_time': rawData['cook_time'] ?? 0,
      'total_time': (rawData['prep_time'] ?? 0) + (rawData['cook_time'] ?? 0),
      'servings': rawData['servings'] ?? 1,
      'rating': (rawData['rating'] ?? 0.0).toDouble(),
      'view_count': rawData['view_count'] ?? 0,
      'created_at': rawData['created_at']?.toString() ?? '',
      'updated_at': rawData['updated_at']?.toString() ?? '',
      'formatted_time':
          formatTime((rawData['prep_time'] ?? 0) + (rawData['cook_time'] ?? 0)),
      'ingredients': ingredients,
      'instructions': formatInstructions(rawData['instructions']),
      'total_cost': calculateTotalCost(ingredients),
      'ingredients_count': ingredients.length,
      'available_ingredients_count':
          ingredients.where((i) => i['in_stock'] == true).length,
    };
  }

  // Parser la quantité (convertir les fractions et textes en nombres)
  static double _parseQuantity(dynamic quantity) {
    if (quantity == null) return 1.0;

    if (quantity is num) return quantity.toDouble();

    if (quantity is String) {
      // Gérer les fractions courantes
      final fractions = {
        '1/2': 0.5,
        '1/3': 0.33,
        '2/3': 0.67,
        '1/4': 0.25,
        '3/4': 0.75,
        '1/8': 0.125,
      };

      for (final fraction in fractions.entries) {
        if (quantity.contains(fraction.key)) {
          return fraction.value;
        }
      }

      // Essayer de parser comme nombre
      final parsed =
          double.tryParse(quantity.replaceAll(RegExp(r'[^\d.,]'), ''));
      return parsed ?? 1.0;
    }

    return 1.0;
  }

  // Récupérer les catégories disponibles
  static Future<List<String>> getCategories() async {
    try {
      final response = await _client!
          .from('recipes')
          .select('category')
          .not('category', 'is', null);

      if (response.isNotEmpty) {
        final categories = response
            .map((item) => item['category']?.toString())
            .where((category) => category != null && category.isNotEmpty)
            .map((category) => category!)
            .toSet()
            .toList();
        categories.sort();
        return categories;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }

  // Créer un panier à partir d'une recette
  static Future<bool> createCartFromRecipe(String recipeId) async {
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return false;

      final recipe = await getRecipeById(recipeId);
      if (recipe == null) return false;

      // Créer un nouveau panier recette
      final cartResponse = await _client!
          .from('recipe_carts')
          .insert({
            'user_id': user.id,
            'recipe_id': recipeId,
            'recipe_name': recipe['title'],
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final cartId = cartResponse['id'];

      // Ajouter les ingrédients au panier
      final ingredients = recipe['ingredients'] as List<Map<String, dynamic>>;
      for (final ingredient in ingredients) {
        await _client!.from('cart_items').insert({
          'cart_id': cartId,
          'product_id': ingredient['product_id'],
          'quantity': ingredient['quantity'].round(),
          'unit_price': ingredient['price'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e) {
      print('❌ Erreur lors de la création du panier: $e');
      return false;
    }
  }

  // Toggle favorite status for a recipe
  static Future<bool> toggleRecipeFavorite(String recipeId) async {
    final isFav = await isFavorite(recipeId);
    if (isFav) {
      await removeFromFavorites(recipeId);
      return false;
    } else {
      await addToFavorites(recipeId);
      return true;
    }
  }

  // Aliases for compatibility with RecipeDrawer
  static Future<bool> isRecipeFavorite(String recipeId) => isFavorite(recipeId);
  static Future<void> addRecipeToHistory(String recipeId) =>
      addToHistory(recipeId);
  static Future<void> incrementRecipeViews(String recipeId) =>
      incrementViewCount(recipeId);
}
