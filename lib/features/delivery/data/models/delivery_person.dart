class DeliveryPerson {
  final String id;
  final String userId;
  final String currentStatus;
  final double rating;
  final int totalDeliveries;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryPerson({
    required this.id,
    required this.userId,
    required this.currentStatus,
    required this.rating,
    required this.totalDeliveries,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryPerson.fromJson(Map<String, dynamic> json) {
    return DeliveryPerson(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      currentStatus: json['current_status'] ?? 'offline',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: json['total_deliveries'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'current_status': currentStatus,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DeliveryPerson copyWith({
    String? id,
    String? userId,
    String? currentStatus,
    double? rating,
    int? totalDeliveries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryPerson(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentStatus: currentStatus ?? this.currentStatus,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Getters utiles
  bool get isAvailable => currentStatus == 'available';
  bool get isDelivering => currentStatus == 'delivering';
  bool get isOffline => currentStatus == 'offline';
  bool get isOnBreak => currentStatus == 'on_break';

  String get statusDisplay {
    switch (currentStatus) {
      case 'available': return 'Disponible';
      case 'delivering': return 'En livraison';
      case 'offline': return 'Hors ligne';
      case 'on_break': return 'En pause';
      default: return 'Inconnu';
    }
  }
}