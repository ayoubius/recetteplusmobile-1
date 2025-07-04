import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/order_status_history.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;

class OrderStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final List<OrderStatusHistory> statusHistory;
  final bool isDark;

  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.statusHistory,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      'pending',
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'out_for_delivery',
      'delivered',
    ];

    final currentIndex = statuses.indexOf(currentStatus);

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        final isLast = index == statuses.length - 1;

        // Trouver l'historique correspondant à ce statut
        final historyItem = statusHistory.firstWhere(
          (h) => h.status == status,
          orElse: () => OrderStatusHistory(
            id: '',
            orderId: '',
            status: status,
            createdAt: DateTime.now(),
          ),
        );

        return _buildTimelineItem(
          status: status,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
          historyItem: statusHistory.any((h) => h.status == status) ? historyItem : null,
        );
      }).toList(),
    );
  }

  Widget _buildTimelineItem({
    required String status,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    OrderStatusHistory? historyItem,
  }) {
    final statusInfo = _getStatusInfo(status);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicateur de statut
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted 
                    ? (isCurrent ? AppColors.primary : Colors.green)
                    : Colors.grey[300],
                border: Border.all(
                  color: isCompleted 
                      ? (isCurrent ? AppColors.primary : Colors.green)
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Icon(
                isCompleted 
                    ? (isCurrent ? statusInfo['icon'] : Icons.check)
                    : statusInfo['icon'],
                size: 12,
                color: isCompleted ? Colors.white : Colors.grey[600],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // Contenu du statut
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCompleted 
                        ? AppColors.getTextPrimary(isDark)
                        : AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusInfo['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                if (historyItem != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        app_date_utils.AppDateUtils.formatDateTime(historyItem.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (historyItem.notes != null && historyItem.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      historyItem.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'title': 'Commande reçue',
          'description': 'Votre commande a été reçue et est en attente de confirmation',
          'icon': Icons.receipt,
        };
      case 'confirmed':
        return {
          'title': 'Commande confirmée',
          'description': 'Votre commande a été confirmée et va être préparée',
          'icon': Icons.check_circle,
        };
      case 'preparing':
        return {
          'title': 'En préparation',
          'description': 'Votre commande est en cours de préparation',
          'icon': Icons.inventory,
        };
      case 'ready_for_pickup':
        return {
          'title': 'Prête pour livraison',
          'description': 'Votre commande est prête et attend un livreur',
          'icon': Icons.inventory_2,
        };
      case 'out_for_delivery':
        return {
          'title': 'En cours de livraison',
          'description': 'Votre commande est en route vers vous',
          'icon': Icons.delivery_dining,
        };
      case 'delivered':
        return {
          'title': 'Livrée',
          'description': 'Votre commande a été livrée avec succès',
          'icon': Icons.home,
        };
      default:
        return {
          'title': 'Statut inconnu',
          'description': 'Statut de commande non reconnu',
          'icon': Icons.help,
        };
    }
  }
}