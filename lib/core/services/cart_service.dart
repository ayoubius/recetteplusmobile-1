import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class CartService {
  static final SupabaseClient _client = Supabase.instance.client;

  static bool get isInitialized {
    try {
      final _ = Supabase.instance.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PANIER PRINCIPAL (VUE UNIFIÉE) ====================

  /// Obtenir tous les paniers de l'utilisateur (vue unifiée)
  static Future<List<Map<String, dynamic>>> getMainCartItems() async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (kDebugMode) {
        print('🔍 Récupération des paniers pour l\'utilisateur: $userId');
      }

      List<Map<String, dynamic>> allCarts = [];

      // 1. Récupérer le panier personnel s'il existe et a des items
      try {
        final personalCart = await _client
            .from('personal_carts')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();

        if (personalCart != null) {
          final personalItems = await getPersonalCartItems(personalCart['id']);

          if (personalItems.isNotEmpty) {
            double totalPrice = 0;
            int itemsCount = 0;

            for (final item in personalItems) {
              totalPrice += item['total_price'] ?? 0.0;
              itemsCount += (item['quantity'] as num?)?.toInt() ?? 0;
            }

            allCarts.add({
              'id': 'personal_${personalCart['id']}',
              'cart_reference_type': 'personal',
              'cart_reference_id': personalCart['id'],
              'cart_name': 'Mon panier personnel',
              'cart_total_price': totalPrice,
              'items_count': itemsCount,
              'created_at': personalCart['created_at'],
              'products': personalItems,
            });

            if (kDebugMode) {
              print(
                  '✅ Panier personnel trouvé: $itemsCount items, ${totalPrice.toStringAsFixed(0)} FCFA');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur panier personnel: $e');
        }
      }

      // 2. Récupérer les paniers de recettes
      try {
        final recipeCarts = await _client
            .from('recipe_user_carts')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        for (final recipeCart in recipeCarts) {
          final recipeItems = await getRecipeCartItems(recipeCart['id']);

          if (recipeItems.isNotEmpty) {
            double totalPrice = 0;
            int itemsCount = 0;

            for (final item in recipeItems) {
              totalPrice += item['total_price'] ?? 0.0;
              itemsCount += (item['quantity'] as num?)?.toInt() ?? 0;
            }

            allCarts.add({
              'id': 'recipe_${recipeCart['id']}',
              'cart_reference_type': 'recipe',
              'cart_reference_id': recipeCart['id'],
              'cart_name': recipeCart['cart_name'] ?? 'Recette',
              'cart_total_price': totalPrice,
              'items_count': itemsCount,
              'created_at': recipeCart['created_at'],
              'products': recipeItems,
            });

            if (kDebugMode) {
              print(
                  '✅ Panier recette trouvé: ${recipeCart['cart_name']} - $itemsCount items, ${totalPrice.toStringAsFixed(0)} FCFA');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur paniers recettes: $e');
        }
      }

      // 3. Récupérer les paniers préconfigurés
      try {
        final userPreconfiguredCarts =
            await _client.from('user_preconfigured_carts').select('''
              *,
              preconfigured_cart:preconfigured_carts (*)
            ''').eq('user_id', userId).order('created_at', ascending: false);

        for (final userCart in userPreconfiguredCarts) {
          final preconfiguredCart = userCart['preconfigured_cart'];
          if (preconfiguredCart != null) {
            final preconfiguredItems =
                await getPreconfiguredCartItems(preconfiguredCart['id']);

            if (preconfiguredItems.isNotEmpty) {
              double totalPrice = 0;
              int itemsCount = 0;

              for (final item in preconfiguredItems) {
                totalPrice += item['total_price'] ?? 0.0;
                itemsCount += (item['quantity'] as num?)?.toInt() ?? 0;
              }

              allCarts.add({
                'id': 'preconfigured_${userCart['id']}',
                'cart_reference_type': 'preconfigured',
                'cart_reference_id': preconfiguredCart['id'],
                'cart_name': preconfiguredCart['name'] ?? 'Pack',
                'cart_total_price': totalPrice,
                'items_count': itemsCount,
                'created_at': userCart['created_at'],
                'products': preconfiguredItems,
              });

              if (kDebugMode) {
                print(
                    '✅ Panier préconfigué trouvé: ${preconfiguredCart['name']} - $itemsCount items, ${totalPrice.toStringAsFixed(0)} FCFA');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur paniers préconfigurés: $e');
        }
      }

      // Trier par date de création (plus récent en premier)
      allCarts.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      if (kDebugMode) {
        print('📦 Total des paniers trouvés: ${allCarts.length}');
        double grandTotal = 0;
        for (final cart in allCarts) {
          grandTotal += cart['cart_total_price'] ?? 0.0;
        }
        print('💰 Total général: ${grandTotal.toStringAsFixed(0)} FCFA');
      }

      return allCarts;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération paniers: $e');
      }
      throw Exception('Impossible de charger les paniers: $e');
    }
  }

  // ==================== PANIER PERSONNEL ====================

  /// Obtenir ou créer le panier personnel de l'utilisateur
  static Future<Map<String, dynamic>?> getOrCreatePersonalCart() async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Essayer de récupérer le panier personnel existant
      try {
        final response = await _client
            .from('personal_carts')
            .select()
            .eq('user_id', userId)
            .single();
        return response;
      } catch (e) {
        // Si aucun panier personnel n'existe, en créer un
        final newCart = await _client
            .from('personal_carts')
            .insert({
              'user_id': userId,
              'is_added_to_main_cart': false,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        return newCart;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération/création panier personnel: $e');
      }
      throw Exception('Impossible de créer le panier personnel: $e');
    }
  }

  /// Ajouter un produit au panier personnel
  static Future<void> addProductToPersonalCart({
    required String productId,
    required int quantity,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final personalCart = await getOrCreatePersonalCart();
      if (personalCart == null) {
        throw Exception('Impossible de créer le panier personnel');
      }

      // Vérifier si le produit existe déjà
      final existingItems = await _client
          .from('personal_cart_items')
          .select()
          .eq('personal_cart_id', personalCart['id'])
          .eq('product_id', productId);

      if (existingItems.isNotEmpty) {
        // Mettre à jour la quantité
        final currentQuantity =
            (existingItems.first['quantity'] as num).toInt();
        await _client
            .from('personal_cart_items')
            .update({'quantity': currentQuantity + quantity}).eq(
                'id', existingItems.first['id']);
      } else {
        // Ajouter un nouvel item
        await _client.from('personal_cart_items').insert({
          'personal_cart_id': personalCart['id'],
          'product_id': productId,
          'quantity': quantity,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (kDebugMode) {
        print('✅ Produit ajouté au panier personnel');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout au panier personnel: $e');
      }
      throw Exception('Impossible d\'ajouter le produit au panier: $e');
    }
  }

  /// Obtenir les items du panier personnel avec détails des produits
  static Future<List<Map<String, dynamic>>> getPersonalCartItems(
      String personalCartId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final response = await _client
          .from('personal_cart_items')
          .select('''
            *,
            product:products (
              id,
              name,
              price,
              unit,
              image
            )
          ''')
          .eq('personal_cart_id', personalCartId)
          .order('created_at', ascending: false);

      // Transformer les données pour un format plus facile à utiliser
      return List<Map<String, dynamic>>.from(response).map((item) {
        final product = item['product'] as Map<String, dynamic>? ?? {};
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;

        return {
          'id': item['id'],
          'product_id': item['product_id'],
          'quantity': quantity,
          'name': product['name'] ?? 'Produit',
          'image': product['image'],
          'price': price,
          'unit': product['unit'] ?? 'pièce',
          'total_price': price * quantity,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération items panier personnel: $e');
      }
      throw Exception(
          'Impossible de charger les produits du panier personnel: $e');
    }
  }

  // ==================== PANIERS RECETTE ====================

  /// Créer un panier pour une recette
  static Future<String?> createRecipeCart({
    required String recipeId,
    required String recipeName,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final response = await _client
          .from('recipe_user_carts')
          .insert({
            'user_id': userId,
            'recipe_id': recipeId,
            'cart_name': recipeName,
            'is_added_to_main_cart': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur création panier recette: $e');
      }
      throw Exception('Impossible de créer le panier recette: $e');
    }
  }

  /// Ajouter les ingrédients d'une recette au panier
  static Future<void> addRecipeToCart({
    required String recipeId,
    required String recipeName,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      // Créer le panier recette
      final recipeCartId = await createRecipeCart(
        recipeId: recipeId,
        recipeName: recipeName,
      );

      if (recipeCartId == null) {
        throw Exception('Impossible de créer le panier recette');
      }

      // Ajouter chaque ingrédient
      for (final ingredient in ingredients) {
        await _client.from('recipe_cart_items').insert({
          'recipe_cart_id': recipeCartId,
          'product_id': ingredient['product_id'],
          'quantity': ingredient['quantity'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (kDebugMode) {
        print('✅ Recette ajoutée au panier');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout recette au panier: $e');
      }
      throw Exception('Impossible d\'ajouter la recette au panier: $e');
    }
  }

  /// Obtenir les paniers recette de l'utilisateur
  static Future<List<Map<String, dynamic>>> getRecipeCarts() async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('recipe_user_carts')
          .select('*, recipe_cart_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération paniers recette: $e');
      }
      throw Exception('Impossible de charger les paniers recette: $e');
    }
  }

  /// Obtenir les items d'un panier recette avec détails des produits
  static Future<List<Map<String, dynamic>>> getRecipeCartItems(
      String recipeCartId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final response = await _client
          .from('recipe_cart_items')
          .select('''
            *,
            product:products (
              id,
              name,
              price,
              unit,
              image
            )
          ''')
          .eq('recipe_cart_id', recipeCartId)
          .order('created_at', ascending: false);

      // Transformer les données pour un format plus facile à utiliser
      return List<Map<String, dynamic>>.from(response).map((item) {
        final product = item['product'] as Map<String, dynamic>? ?? {};
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;

        return {
          'id': item['id'],
          'product_id': item['product_id'],
          'quantity': quantity,
          'name': product['name'] ?? 'Ingrédient',
          'image': product['image'],
          'price': price,
          'unit': product['unit'] ?? 'g',
          'total_price': price * quantity,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération items panier recette: $e');
      }
      throw Exception(
          'Impossible de charger les ingrédients de la recette: $e');
    }
  }

  // ==================== PANIERS PRÉCONFIGURÉS ====================

  /// Obtenir les paniers préconfigurés en vedette
  static Future<List<Map<String, dynamic>>>
      getFeaturedPreconfiguredCarts() async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final response = await _client
          .from('preconfigured_carts')
          .select()
          .eq('is_active', true)
          .eq('is_featured', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération paniers préconfigurés: $e');
      }
      throw Exception('Impossible de charger les paniers préconfigurés: $e');
    }
  }

  /// Ajouter un panier préconfigué à l'utilisateur
  static Future<void> addPreconfiguredCartToUser(
      String preconfiguredCartId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // Vérifier si l'utilisateur a déjà ce panier
      final existing = await _client
          .from('user_preconfigured_carts')
          .select()
          .eq('user_id', userId)
          .eq('preconfigured_cart_id', preconfiguredCartId);

      if (existing.isEmpty) {
        await _client.from('user_preconfigured_carts').insert({
          'user_id': userId,
          'preconfigured_cart_id': preconfiguredCartId,
          'is_added_to_main_cart': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('✅ Panier préconfigué ajouté');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Panier préconfigué déjà ajouté');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout panier préconfigué: $e');
      }
      throw Exception('Impossible d\'ajouter le panier préconfiguré: $e');
    }
  }

  /// Obtenir les items d'un panier préconfiguré
  static Future<List<Map<String, dynamic>>> getPreconfiguredCartItems(
      String preconfiguredCartId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final response = await _client
          .from('preconfigured_carts')
          .select()
          .eq('id', preconfiguredCartId)
          .single();

      final items = response['items'] as List<dynamic>? ?? [];

      // Transformer les données pour un format plus facile à utiliser
      return items.map((item) {
        final itemMap = Map<String, dynamic>.from(item);
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

        return {
          ...itemMap,
          'quantity': quantity,
          'total_price': price * quantity,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération items panier préconfiguré: $e');
      }
      throw Exception(
          'Impossible de charger les items du panier préconfiguré: $e');
    }
  }

  // ==================== GESTION GLOBALE ====================

  /// Calculer le total de tous les paniers
  static Future<double> calculateMainCartTotal() async {
    try {
      final cartItems = await getMainCartItems();
      double total = 0.0;

      for (final item in cartItems) {
        total += (item['cart_total_price'] as num?)?.toDouble() ?? 0.0;
      }

      return total;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur calcul total panier: $e');
      }
      return 0.0;
    }
  }

  /// Supprimer un panier spécifique
  static Future<void> removeFromMainCart(String itemId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      // Extraire le type et l'ID du panier depuis l'itemId
      final parts = itemId.split('_');
      if (parts.length < 2) {
        throw Exception('Format d\'ID invalide');
      }

      final cartType = parts[0];
      final cartId = parts.sublist(1).join('_');

      if (kDebugMode) {
        print('🗑️ Suppression panier: $cartType - $cartId');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Supprimer selon le type de panier
      if (cartType == 'personal') {
        // Supprimer tous les items du panier personnel
        await _client
            .from('personal_cart_items')
            .delete()
            .eq('personal_cart_id', cartId);

        // Optionnel: supprimer le panier personnel lui-même
        // await _client
        //     .from('personal_carts')
        //     .delete()
        //     .eq('id', cartId);
      } else if (cartType == 'recipe') {
        // Supprimer tous les items du panier recette
        await _client
            .from('recipe_cart_items')
            .delete()
            .eq('recipe_cart_id', cartId);

        // Supprimer le panier recette
        await _client
            .from('recipe_user_carts')
            .delete()
            .eq('id', cartId)
            .eq('user_id', userId);
      } else if (cartType == 'preconfigured') {
        // Supprimer l'association utilisateur-panier préconfigué
        await _client
            .from('user_preconfigured_carts')
            .delete()
            .eq('id', cartId)
            .eq('user_id', userId);
      }

      if (kDebugMode) {
        print('✅ Panier supprimé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression panier: $e');
      }
      throw Exception('Impossible de supprimer le panier: $e');
    }
  }

  /// Vider complètement tous les paniers de l'utilisateur
  static Future<void> clearMainCart() async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (kDebugMode) {
        print('🧹 Vidage complet des paniers pour l\'utilisateur: $userId');
      }

      // 1. Vider le panier personnel
      try {
        final personalCart = await _client
            .from('personal_carts')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (personalCart != null) {
          await _client
              .from('personal_cart_items')
              .delete()
              .eq('personal_cart_id', personalCart['id']);

          if (kDebugMode) {
            print('✅ Panier personnel vidé');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur vidage panier personnel: $e');
        }
      }

      // 2. Supprimer tous les paniers recette
      try {
        final recipeCarts = await _client
            .from('recipe_user_carts')
            .select('id')
            .eq('user_id', userId);

        for (final recipeCart in recipeCarts) {
          // Supprimer les items du panier recette
          await _client
              .from('recipe_cart_items')
              .delete()
              .eq('recipe_cart_id', recipeCart['id']);

          // Supprimer le panier recette lui-même
          await _client
              .from('recipe_user_carts')
              .delete()
              .eq('id', recipeCart['id']);
        }

        if (kDebugMode) {
          print('✅ ${recipeCarts.length} paniers recette supprimés');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur suppression paniers recette: $e');
        }
      }

      // 3. Supprimer toutes les associations aux paniers préconfigurés
      try {
        final deletedCount = await _client
            .from('user_preconfigured_carts')
            .delete()
            .eq('user_id', userId);

        if (kDebugMode) {
          print('✅ Associations paniers préconfigurés supprimées');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur suppression paniers préconfigurés: $e');
        }
      }

      if (kDebugMode) {
        print('✅ Tous les paniers ont été vidés avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur vidage complet des paniers: $e');
      }
      throw Exception('Impossible de vider les paniers: $e');
    }
  }

  /// Mettre à jour la quantité d'un produit dans un panier
  static Future<void> updateProductQuantity({
    required String cartId,
    required String productId,
    required int quantity,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      // Déterminer le type de panier à partir de l'ID
      String? cartType;

      // Vérifier si c'est un panier personnel
      final personalCart = await _client
          .from('personal_cart_items')
          .select()
          .eq('personal_cart_id', cartId)
          .eq('product_id', productId);

      if (personalCart.isNotEmpty) {
        cartType = 'personal';
      } else {
        // Vérifier si c'est un panier recette
        final recipeCart = await _client
            .from('recipe_cart_items')
            .select()
            .eq('recipe_cart_id', cartId)
            .eq('product_id', productId);

        if (recipeCart.isNotEmpty) {
          cartType = 'recipe';
        }
      }

      if (cartType == null) {
        throw Exception('Type de panier non reconnu');
      }

      // Mettre à jour la quantité selon le type de panier
      if (cartType == 'personal') {
        await _client
            .from('personal_cart_items')
            .update({'quantity': quantity})
            .eq('personal_cart_id', cartId)
            .eq('product_id', productId);
      } else if (cartType == 'recipe') {
        await _client
            .from('recipe_cart_items')
            .update({'quantity': quantity})
            .eq('recipe_cart_id', cartId)
            .eq('product_id', productId);
      }

      if (kDebugMode) {
        print('✅ Quantité mise à jour');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour quantité: $e');
      }
      throw Exception('Impossible de mettre à jour la quantité: $e');
    }
  }

  /// Supprimer un produit d'un panier
  static Future<void> removeProductFromCart({
    required String cartId,
    required String productId,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      // Déterminer le type de panier à partir de l'ID
      String? cartType;

      // Vérifier si c'est un panier personnel
      final personalCart = await _client
          .from('personal_cart_items')
          .select()
          .eq('personal_cart_id', cartId)
          .eq('product_id', productId);

      if (personalCart.isNotEmpty) {
        cartType = 'personal';
      } else {
        // Vérifier si c'est un panier recette
        final recipeCart = await _client
            .from('recipe_cart_items')
            .select()
            .eq('recipe_cart_id', cartId)
            .eq('product_id', productId);

        if (recipeCart.isNotEmpty) {
          cartType = 'recipe';
        }
      }

      if (cartType == null) {
        throw Exception('Type de panier non reconnu');
      }

      // Supprimer le produit selon le type de panier
      if (cartType == 'personal') {
        await _client
            .from('personal_cart_items')
            .delete()
            .eq('personal_cart_id', cartId)
            .eq('product_id', productId);
      } else if (cartType == 'recipe') {
        await _client
            .from('recipe_cart_items')
            .delete()
            .eq('recipe_cart_id', cartId)
            .eq('product_id', productId);
      }

      if (kDebugMode) {
        print('✅ Produit supprimé du panier');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression produit: $e');
      }
      throw Exception('Impossible de supprimer le produit: $e');
    }
  }
}
