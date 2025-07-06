import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:recette_plus/features/delivery/data/models/delivery_person.dart';
import 'package:recette_plus/features/delivery/data/models/order.dart';
import 'package:recette_plus/features/delivery/data/models/order_tracking.dart';
import 'package:recette_plus/features/delivery/data/models/order_status_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class DeliveryService {
  static StreamController<Map<String, dynamic>>? _trackingController;

  // Frais de livraison fixe pour Bamako
  static const double fixedDeliveryFee = 1000.0;

  /// Générer un UUID v4 simple sans dépendance externe
  static String _generateUuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));

    // Version 4 UUID format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant bits

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // ==================== CRÉATION DE COMMANDES ====================

  /// Créer une commande avec livraison
  static Future<Order?> createOrderWithDelivery({
    required String userId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    String? deliveryNotes,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        throw Exception('Supabase non initialisé');
      }

      // Obtenir l'utilisateur actuel depuis Supabase
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Utiliser l'ID de l'utilisateur connecté au lieu de 'current_user_id'
      final actualUserId = currentUser.id;

      // Générer un vrai UUID pour l'ID de commande
      final orderId = _generateUuid();
      final qrCode =
          'QR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Préparer les données de base pour la commande (seulement les colonnes qui existent)
      final orderData = {
        'id': orderId,
        'user_id': actualUserId, // Utiliser l'ID réel de l'utilisateur
        'total_amount': totalAmount + fixedDeliveryFee,
        'delivery_fee': fixedDeliveryFee,
        'status': 'pending',
        'delivery_address': deliveryAddress,
        'qr_code': qrCode,
        'created_at': DateTime.now().toIso8601String(),
        'items': items,
      };

      // Ajouter les notes de livraison si fournies
      if (deliveryNotes != null && deliveryNotes.isNotEmpty) {
        orderData['delivery_notes'] = deliveryNotes;
      }

      // Ajouter les coordonnées GPS et autres données si disponibles
      if (additionalData != null) {
        if (additionalData['delivery_latitude'] != null) {
          orderData['delivery_latitude'] = additionalData['delivery_latitude'];
        }
        if (additionalData['delivery_longitude'] != null) {
          orderData['delivery_longitude'] =
              additionalData['delivery_longitude'];
        }

        // ❌ SUPPRIMÉ: phone_number car la colonne n'existe pas dans la table orders
        // if (additionalData['phone_number'] != null) {
        //   orderData['phone_number'] = additionalData['phone_number'];
        // }

        // Ajouter les détails d'adresse enrichis si les colonnes existent
        if (additionalData['delivery_city'] != null) {
          orderData['delivery_city'] = additionalData['delivery_city'];
        }
        if (additionalData['delivery_district'] != null) {
          orderData['delivery_district'] = additionalData['delivery_district'];
        }
        if (additionalData['delivery_landmark'] != null) {
          orderData['delivery_landmark'] = additionalData['delivery_landmark'];
        }
      }

      // Insérer la commande dans la base de données
      await SupabaseService.client.from('orders').insert(orderData);

      // Créer l'objet Order pour le retour
      final order = Order(
        id: orderId,
        userId: actualUserId,
        totalAmount: totalAmount + fixedDeliveryFee,
        deliveryFee: fixedDeliveryFee,
        status: 'pending',
        deliveryAddress: deliveryAddress,
        deliveryNotes: deliveryNotes,
        qrCode: qrCode,
        createdAt: DateTime.now(),
        estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 45)),
        items: items,
      );

      if (kDebugMode) {
        print('✅ Commande créée avec succès: ${order.id}');
        print('👤 Utilisateur: $actualUserId');
        print('📍 Adresse de livraison: $deliveryAddress');
        print('💰 Montant total: ${order.totalAmount} FCFA');
        print('🚚 Frais de livraison: $fixedDeliveryFee FCFA');
        print('📦 Nombre d\'articles: ${items.length}');

        if (additionalData?['delivery_city'] != null) {
          print('🏙️ Ville: ${additionalData!['delivery_city']}');
        }
        if (additionalData?['delivery_district'] != null) {
          print('🏘️ Quartier: ${additionalData!['delivery_district']}');
        }
        if (additionalData?['phone_number'] != null) {
          print('📞 Téléphone: ${additionalData!['phone_number']}');
        }
      }

      return order;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur création commande: $e');
      }
      throw Exception('Impossible de créer la commande: $e');
    }
  }

  /// Obtenir les commandes d'un utilisateur
  static Future<List<Order>> getUserOrders(String userId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (kDebugMode) {
        print(
            '📦 ${response.length} commandes trouvées pour l\'utilisateur $userId');
      }

      return response.map((orderData) => Order.fromJson(orderData)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération commandes utilisateur: $e');
      }
      return [];
    }
  }

  // ==================== GESTION DES LIVREURS ====================

  /// Obtenir le profil du livreur actuel
  static Future<DeliveryPerson?> getCurrentDeliveryPersonProfile() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - aucun profil livreur');
        }
        return null;
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final response = await SupabaseService.client
          .from('delivery_persons')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return DeliveryPerson.fromJson(response);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération profil livreur: $e');
      }
      return null;
    }
  }

  /// Mettre à jour le statut d'un livreur
  static Future<bool> updateDeliveryPersonStatus({
    required String deliveryPersonId,
    required String status,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print(
              '⚠️ Supabase non initialisé - impossible de mettre à jour le statut');
        }
        return false;
      }

      await SupabaseService.client.from('delivery_persons').update({
        'current_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', deliveryPersonId);

      if (kDebugMode) {
        print('✅ Statut livreur mis à jour: $deliveryPersonId -> $status');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour statut livreur: $e');
      }
      return false;
    }
  }

  /// Obtenir tous les livreurs
  static Future<List<Map<String, dynamic>>> getAllDeliveryPersons() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final response =
          await SupabaseService.client.from('delivery_persons').select('''
            *,
            profiles!delivery_persons_user_id_fkey (
              display_name,
              phone_number
            )
          ''');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération livreurs: $e');
      }
      return [];
    }
  }

  // ==================== GESTION DES COMMANDES ====================

  /// Obtenir les commandes assignées à un livreur
  static Future<List<Map<String, dynamic>>> getAssignedOrders() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return [];

      // Récupérer d'abord le profil de livreur
      final deliveryPerson = await SupabaseService.client
          .from('delivery_persons')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (deliveryPerson == null) return [];

      // Correction: Utiliser une jointure explicite via delivery_tracking
      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            profiles!orders_user_id_fkey (
              display_name,
              phone_number
            ),
            delivery_tracking!delivery_tracking_order_id_fkey (*)
          ''')
          .eq('delivery_person_id', deliveryPerson['id'])
          .inFilter('status', ['ready_for_pickup', 'out_for_delivery'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération commandes assignées: $e');
      }
      return [];
    }
  }

  /// Obtenir l'historique des livraisons
  static Future<List<Map<String, dynamic>>> getDeliveryHistory() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return [];

      // Récupérer d'abord le profil de livreur
      final deliveryPerson = await SupabaseService.client
          .from('delivery_persons')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (deliveryPerson == null) return [];

      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            profiles!orders_user_id_fkey (
              display_name,
              phone_number
            )
          ''')
          .eq('delivery_person_id', deliveryPerson['id'])
          .eq('status', 'delivered')
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération historique livraisons: $e');
      }
      return [];
    }
  }

  /// Mettre à jour le statut d'une commande
  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print(
              '⚠️ Supabase non initialisé - impossible de mettre à jour le statut');
        }
        return false;
      }

      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Si la commande est livrée, ajouter la date de livraison
      if (status == 'delivered') {
        updateData['actual_delivery_time'] = DateTime.now().toIso8601String();
      }

      await SupabaseService.client
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      if (kDebugMode) {
        print('✅ Statut commande mis à jour: $orderId -> $status');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour statut commande: $e');
      }
      return false;
    }
  }

  // ==================== GESTION DU SUIVI ====================

  /// Obtenir le suivi d'une commande
  static Future<OrderTracking?> getOrderTracking(String orderId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - aucun suivi disponible');
        }
        return null;
      }

      final response = await SupabaseService.client
          .from('delivery_tracking')
          .select('*')
          .eq('order_id', orderId)
          .maybeSingle();

      if (response != null) {
        return OrderTracking.fromJson(response);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération suivi commande: $e');
      }
      return null;
    }
  }

  /// Mettre à jour la position de livraison
  static Future<bool> updateDeliveryLocation({
    required String trackingId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print(
              '⚠️ Supabase non initialisé - impossible de mettre à jour la position');
        }
        return false;
      }

      await SupabaseService.client.from('delivery_tracking').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
        'last_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', trackingId);

      if (kDebugMode) {
        print('📍 Position mise à jour: $trackingId -> $latitude, $longitude');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour position: $e');
      }
      return false;
    }
  }

  /// Obtenir l'historique des statuts d'une commande
  static Future<List<OrderStatusHistory>> getOrderStatusHistory(
      String orderId) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      // Vérifier si la table existe avant de faire la requête
      try {
        final response = await SupabaseService.client
            .from('order_status_history')
            .select('*')
            .eq('order_id', orderId)
            .order('created_at', ascending: true);

        return response
            .map((data) => OrderStatusHistory.fromJson(data))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Table order_status_history non disponible: $e');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération historique statuts: $e');
      }
      return [];
    }
  }

  // ==================== GESTION DES COMMANDES EN ATTENTE ====================

  /// Obtenir les commandes en attente de validation
  static Future<List<Map<String, dynamic>>> getPendingOrders() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            profiles!orders_user_id_fkey (
              display_name,
              phone_number
            )
          ''')
          .inFilter('status', ['confirmed', 'preparing', 'ready_for_pickup'])
          .isFilter('delivery_person_id', null)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération commandes en attente: $e');
      }
      return [];
    }
  }

  /// Assigner un livreur à une commande
  static Future<bool> assignDeliveryPerson({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print(
              '⚠️ Supabase non initialisé - impossible d\'assigner un livreur');
        }
        return false;
      }

      await SupabaseService.client.from('orders').update({
        'delivery_person_id': deliveryPersonId,
        'status': 'out_for_delivery',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Créer un enregistrement de suivi si la table existe
      try {
        await SupabaseService.client.from('delivery_tracking').insert({
          'order_id': orderId,
          'delivery_person_id': deliveryPersonId,
          'current_latitude': 12.6392, // Position par défaut Bamako
          'current_longitude': -8.0029,
          'last_updated_at': DateTime.now().toIso8601String(),
          'notes': 'Prise en charge par le livreur',
        });
      } catch (trackingError) {
        if (kDebugMode) {
          print('⚠️ Erreur création suivi (non critique): $trackingError');
        }
      }

      if (kDebugMode) {
        print('✅ Livreur assigné: $orderId -> $deliveryPersonId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur assignation livreur: $e');
      }
      return false;
    }
  }

  // ==================== GESTION DES COMMANDES UTILISATEUR ====================

  /// Obtenir les commandes d'un utilisateur avec suivi
  static Future<List<Map<String, dynamic>>> getUserOrdersWithTracking() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ Utilisateur non connecté');
        }
        return [];
      }

      // Simplifier la requête pour éviter les problèmes de relations
      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (kDebugMode) {
        print(
            '✅ ${response.length} commandes récupérées pour l\'utilisateur ${user.id}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération commandes utilisateur: $e');
      }
      return [];
    }
  }

  /// Obtenir les livraisons actives d'un utilisateur
  static Future<List<Map<String, dynamic>>> getUserActiveDeliveries() async {
    try {
      if (!SupabaseService.isInitialized) {
        if (kDebugMode) {
          print('⚠️ Supabase non initialisé - retour liste vide');
        }
        return [];
      }

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ Utilisateur non connecté');
        }
        return [];
      }

      // Simplifier la requête pour éviter les problèmes de relations
      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('user_id', user.id)
          .inFilter('status', [
        'pending',
        'confirmed',
        'preparing',
        'ready_for_pickup',
        'out_for_delivery'
      ]).order('created_at', ascending: false);

      if (kDebugMode) {
        print(
            '✅ ${response.length} livraisons actives récupérées pour l\'utilisateur ${user.id}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération livraisons actives: $e');
      }
      return [];
    }
  }

  // ==================== STREAMING ET TEMPS RÉEL ====================

  /// S'abonner aux mises à jour de suivi d'une commande
  static Stream<Map<String, dynamic>> subscribeToOrderTracking(String orderId) {
    _trackingController ??= StreamController<Map<String, dynamic>>.broadcast();

    if (SupabaseService.isInitialized) {
      try {
        // Utiliser les subscriptions en temps réel de Supabase
        SupabaseService.client
            .from('delivery_tracking')
            .stream(primaryKey: ['id'])
            .eq('order_id', orderId)
            .listen((data) {
              if (data.isNotEmpty && _trackingController?.isClosed == false) {
                final tracking = data.first;
                _trackingController?.add({
                  'order_id': orderId,
                  'latitude': tracking['current_latitude'],
                  'longitude': tracking['current_longitude'],
                  'timestamp': tracking['last_updated_at'],
                  'status': 'out_for_delivery',
                });

                if (kDebugMode) {
                  print('📡 Mise à jour position reçue pour commande $orderId');
                }
              }
            });
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur subscription temps réel: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('⚠️ Supabase non initialisé - pas de suivi temps réel');
      }
    }

    return _trackingController!.stream;
  }

  /// Se désabonner du suivi de commande
  static void unsubscribeFromOrderTracking() {
    _trackingController?.close();
    _trackingController = null;

    if (kDebugMode) {
      print('📡 Déconnexion du suivi temps réel');
    }
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  static String _getStatusNotes(String status) {
    switch (status) {
      case 'pending':
        return 'Commande en attente de confirmation';
      case 'confirmed':
        return 'Commande confirmée par le restaurant';
      case 'preparing':
        return 'Préparation en cours';
      case 'ready_for_pickup':
        return 'Commande prête pour la livraison';
      case 'out_for_delivery':
        return 'Prise en charge par le livreur';
      case 'delivered':
        return 'Commande livrée avec succès';
      case 'cancelled':
        return 'Commande annulée';
      default:
        return 'Mise à jour du statut';
    }
  }
}
