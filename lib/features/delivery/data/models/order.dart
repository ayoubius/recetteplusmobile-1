class Order {
  final String id;
  final String userId;
  final double? totalAmount;
  final double? deliveryFee;
  final String status;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final String? qrCode;
  final DateTime? createdAt;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final dynamic items;

  Order({
    required this.id,
    required this.userId,
    this.totalAmount,
    this.deliveryFee,
    required this.status,
    this.deliveryAddress,
    this.deliveryNotes,
    this.qrCode,
    this.createdAt,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      status: json['status'] ?? 'pending',
      deliveryAddress: json['delivery_address'],
      deliveryNotes: json['delivery_notes'],
      qrCode: json['qr_code'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null 
          ? DateTime.tryParse(json['estimated_delivery_time']) 
          : null,
      actualDeliveryTime: json['actual_delivery_time'] != null 
          ? DateTime.tryParse(json['actual_delivery_time']) 
          : null,
      items: json['items'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'status': status,
      'delivery_address': deliveryAddress,
      'delivery_notes': deliveryNotes,
      'qr_code': qrCode,
      'created_at': createdAt?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'items': items,
    };
  }

  Order copyWith({
    String? id,
    String? userId,
    double? totalAmount,
    double? deliveryFee,
    String? status,
    String? deliveryAddress,
    String? deliveryNotes,
    String? qrCode,
    DateTime? createdAt,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    dynamic items,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      items: items ?? this.items,
    );
  }

  // Getters utiles
  bool get isInTransit => status == 'out_for_delivery';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isPreparing => status == 'preparing';
  bool get isReadyForPickup => status == 'ready_for_pickup';

  String get statusDisplay {
    switch (status) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'preparing': return 'En préparation';
      case 'ready_for_pickup': return 'Prête pour livraison';
      case 'out_for_delivery': return 'En cours de livraison';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      default: return 'Inconnu';
    }
  }
}