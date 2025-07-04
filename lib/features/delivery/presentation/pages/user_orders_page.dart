import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/delivery_service.dart';
import '../../../../core/utils/currency_utils.dart';

class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({super.key});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Charger toutes les commandes
      final allOrders = await DeliveryService.getUserOrdersWithTracking();

      // Charger les commandes actives
      final activeOrders = await DeliveryService.getUserActiveDeliveries();

      if (mounted) {
        setState(() {
          _orders = allOrders;
          _activeOrders = activeOrders;
          _isLoading = false;
        });

        // Feedback haptique léger
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Mes Commandes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  const Text('En cours'),
                  if (_activeOrders.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _activeOrders.length.toString(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 20),
                  SizedBox(width: 8),
                  Text('Historique'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return _buildLoadingState(isDark);
    }

    if (_error != null) {
      return _buildErrorState(isDark);
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Onglet commandes actives
        _buildOrdersList(_activeOrders, isDark, isActive: true),
        // Onglet historique
        _buildOrdersList(_orders, isDark, isActive: false),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de vos commandes...',
            style: TextStyle(
              color: AppColors.getTextSecondary(isDark),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    List<Map<String, dynamic>> orders,
    bool isDark, {
    required bool isActive,
  }) {
    if (orders.isEmpty) {
      return _buildEmptyState(isDark, isActive);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isActive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.shopping_bag_outlined : Icons.history,
              size: 80,
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 24),
            Text(
              isActive ? 'Aucune commande en cours' : 'Aucun historique',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isActive
                  ? 'Vos commandes en cours apparaîtront ici'
                  : 'Vos commandes passées apparaîtront ici',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigation vers la page de commande
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Passer une commande'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isDark) {
    final status = _safeGetString(order, 'status', 'unknown');
    final totalAmount = _safeGetDouble(order, 'total_amount', 0.0);
    final deliveryAddress =
        _safeGetString(order, 'delivery_address', 'Adresse non spécifiée');
    final createdAt =
        DateTime.tryParse(_safeGetString(order, 'created_at', '')) ??
            DateTime.now();
    final items = _safeGetList(order, 'items');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showOrderDetails(order, isDark);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statut et date
              Row(
                children: [
                  Expanded(child: _buildStatusChip(status, isDark)),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ID de commande
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Commande #${_safeGetString(order, 'id', 'N/A').substring(0, 8)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Adresse de livraison
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deliveryAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Nombre d'articles
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag,
                    size: 16,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} article${items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prix et bouton d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyUtils.formatPrice(totalAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        displayText = 'En attente';
        break;
      case 'confirmed':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        displayText = 'Confirmée';
        break;
      case 'preparing':
        backgroundColor = Colors.purple.withOpacity(0.1);
        textColor = Colors.purple;
        displayText = 'En préparation';
        break;
      case 'ready_for_pickup':
        backgroundColor = Colors.teal.withOpacity(0.1);
        textColor = Colors.teal;
        displayText = 'Prête';
        break;
      case 'out_for_delivery':
        backgroundColor = AppColors.primary.withOpacity(0.1);
        textColor = AppColors.primary;
        displayText = 'En livraison';
        break;
      case 'delivered':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        displayText = 'Livrée';
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        displayText = 'Annulée';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        displayText = 'Inconnu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showOrderDetails(Map<String, dynamic> order, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: _buildOrderDetailsContent(order, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailsContent(Map<String, dynamic> order, bool isDark) {
    final items = _safeGetList(order, 'items');
    final totalAmount = _safeGetDouble(order, 'total_amount', 0.0);
    final deliveryFee = _safeGetDouble(order, 'delivery_fee', 0.0);
    final subtotal = totalAmount - deliveryFee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          'Détails de la commande',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 24),

        // Informations générales
        _buildDetailSection(
          'Informations générales',
          [
            _buildDetailRow(
                'ID',
                '#${_safeGetString(order, 'id', 'N/A').substring(0, 8)}',
                isDark),
            _buildDetailRow('Statut',
                _getStatusText(_safeGetString(order, 'status', '')), isDark),
            _buildDetailRow(
                'Date',
                _formatDate(DateTime.tryParse(
                        _safeGetString(order, 'created_at', '')) ??
                    DateTime.now()),
                isDark),
            _buildDetailRow(
                'Adresse',
                _safeGetString(order, 'delivery_address', 'Non spécifiée'),
                isDark),
          ],
          isDark,
        ),

        const SizedBox(height: 24),

        // Articles commandés
        _buildDetailSection(
          'Articles commandés',
          items.map((item) => _buildItemRow(item, isDark)).toList(),
          isDark,
        ),

        const SizedBox(height: 24),

        // Récapitulatif des prix
        _buildDetailSection(
          'Récapitulatif',
          [
            _buildDetailRow(
                'Sous-total', CurrencyUtils.formatPrice(subtotal), isDark),
            _buildDetailRow('Frais de livraison',
                CurrencyUtils.formatPrice(deliveryFee), isDark),
            const Divider(),
            _buildDetailRow(
              'Total',
              CurrencyUtils.formatPrice(totalAmount),
              isDark,
              isTotal: true,
            ),
          ],
          isDark,
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getBackground(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getBorder(isDark),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? AppColors.primary
                  : AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, bool isDark) {
    final name = _safeGetString(item, 'name', 'Article inconnu');
    final quantity = _safeGetInt(item, 'quantity', 1);
    final price = _safeGetDouble(item, 'price', 0.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  'Quantité: $quantity',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            CurrencyUtils.formatPrice(price * quantity),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'preparing':
        return 'En préparation';
      case 'ready_for_pickup':
        return 'Prête pour livraison';
      case 'out_for_delivery':
        return 'En cours de livraison';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Statut inconnu';
    }
  }

  // Méthodes utilitaires pour éviter les erreurs de type
  String _safeGetString(
      Map<String, dynamic> map, String key, String defaultValue) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  double _safeGetDouble(
      Map<String, dynamic> map, String key, double defaultValue) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _safeGetInt(Map<String, dynamic> map, String key, int defaultValue) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List<Map<String, dynamic>> _safeGetList(
      Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return [];
    if (value is List) {
      return value.map((item) {
        if (item is Map<String, dynamic>) return item;
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }
}
