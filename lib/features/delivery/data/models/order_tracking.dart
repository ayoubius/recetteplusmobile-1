class OrderTracking {
  final String id;
  final String orderId;
  final String? deliveryPersonId;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastUpdatedAt;
  final String? notes;

  OrderTracking({
    required this.id,
    required this.orderId,
    this.deliveryPersonId,
    this.currentLatitude,
    this.currentLongitude,
    this.lastUpdatedAt,
    this.notes,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    return OrderTracking(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      deliveryPersonId: json['delivery_person_id'],
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      lastUpdatedAt: json['last_updated_at'] != null 
          ? DateTime.tryParse(json['last_updated_at']) 
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'delivery_person_id': deliveryPersonId,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'last_updated_at': lastUpdatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  OrderTracking copyWith({
    String? id,
    String? orderId,
    String? deliveryPersonId,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastUpdatedAt,
    String? notes,
  }) {
    return OrderTracking(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      notes: notes ?? this.notes,
    );
  }

  // Getters utiles
  bool get hasLocation => currentLatitude != null && currentLongitude != null;
  bool get hasDeliveryPerson => deliveryPersonId != null;
}