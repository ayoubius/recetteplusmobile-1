import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/utils/currency_utils.dart';
import 'preconfigured_carts_page.dart';
import 'product_cart_detail_page.dart';
import 'product_detail_drawer.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final PageController _cartsPageController = PageController();
  String _selectedCategory = 'Tous';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _featuredCarts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _autoScrollTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = [
    'Tous',
    'Épices',
    'Huiles',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _cartsPageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_featuredCarts.isNotEmpty && _cartsPageController.hasClients) {
        final nextPage = (_cartsPageController.page?.round() ?? 0) + 1;
        final targetPage = nextPage >= _featuredCarts.length ? 0 : nextPage;

        _cartsPageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Charger les produits et les paniers préconfigurés en parallèle
      await Future.wait([
        _loadProducts(),
        _loadFeaturedCarts(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await SupabaseService.getProducts(
        category: _selectedCategory == 'Tous' ? null : _selectedCategory,
        searchQuery: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
      );

      setState(() {
        _products = products;
      });
    } catch (e) {
      throw Exception('Impossible de charger les produits: $e');
    }
  }

  Future<void> _loadFeaturedCarts() async {
    try {
      final carts = await CartService.getFeaturedPreconfiguredCarts();

      // 🔥 ENRICHISSEMENT IMMÉDIAT avec données réelles
      final cartsWithRealData = await Future.wait(carts.map((cart) async {
        try {
          // Récupérer les items réels depuis la base de données
          final items = await CartService.getPreconfiguredCartItems(cart['id']);

          // Calculer le prix total réel
          double totalPrice = 0;
          for (final item in items) {
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            totalPrice += price * quantity;
          }

          return {
            ...cart,
            'items_count': items.length,
            'total_price': totalPrice, // 🔥 PRIX RÉEL CALCULÉ
            'items': items, // 🔥 DONNÉES RÉELLES PRÉCHARGÉES
          };
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Erreur enrichissement panier ${cart['id']}: $e');
          }
          // Fallback avec données de base
          return {
            ...cart,
            'items_count': 0,
            'total_price': cart['total_price'] ?? 0.0,
            'items': [],
          };
        }
      }));

      setState(() {
        _featuredCarts = cartsWithRealData;
      });

      if (kDebugMode) {
        print(
            '✅ ${_featuredCarts.length} paniers préconfigurés enrichis chargés');
        for (final cart in _featuredCarts) {
          print(
              '   - ${cart['name']}: ${cart['items_count']} items, ${cart['total_price']} FCFA');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement paniers préconfigurés: $e');
      }
      throw Exception('Impossible de charger les paniers en vedette: $e');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      await CartService.addProductToPersonalCart(
        productId: product['id'],
        quantity: 1,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} ajouté au panier'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductCartDetailPage(
                        cart: {}), // TODO: Pass actual cart if needed
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterModal(),
    );
  }

  void _viewCartDetails(Map<String, dynamic> cart) async {
    HapticFeedback.mediumImpact();

    // 🔥 OUVERTURE IMMÉDIATE - Les données sont déjà préchargées !
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PreconfiguredCartDetailsDrawer(
        cart: cart, // 🔥 Données déjà enrichies avec items réels
        onAddToCart: () async {
          Navigator.pop(context);
          await _addPreconfiguredCartToUser(cart);
        },
      ),
    );
  }

  Future<void> _addPreconfiguredCartToUser(Map<String, dynamic> cart) async {
    try {
      await CartService.addPreconfiguredCartToUser(cart['id']);

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cart['name']} ajouté au panier'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _viewAllPreconfiguredCarts() {
    HapticFeedback.mediumImpact();

    // Navigation vers la page dédiée aux paniers préconfigurés
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PreconfiguredCartsPage(),
      ),
    );
  }

  void _viewProduct(Map<String, dynamic> product) {
    HapticFeedback.mediumImpact();

    // Ouvrir le drawer de détails du produit
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailDrawer(
        product: product,
        onClose: () => Navigator.pop(context),
        onCartUpdated: () {
          // Naviguer vers le panier après ajout depuis le drawer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductCartDetailPage(
                  cart: {}), // TODO: Pass actual cart if needed
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec recherche
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getShadow(isDark),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Produits',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ),
                      // Bouton filtre
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          onPressed: _showFilterModal,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.tune,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Barre de recherche
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.getBackground(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.getBorder(isDark),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {});
                        if (value.isEmpty) {
                          _loadProducts();
                        }
                      },
                      onSubmitted: (value) => _loadProducts(),
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(
                            color: AppColors.getTextSecondary(isDark)),
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.getTextSecondary(isDark)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: AppColors.getTextSecondary(isDark)),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadProducts();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Paniers préconfigurés en vedette avec défilement automatique
            if (_featuredCarts.isNotEmpty) ...[
              Container(
                height: 200, // Augmenté de 180 à 200
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.getBorder(isDark),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 12, 20, 8), // Réduit de 16 à 12 en haut
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paniers en vedette',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          TextButton(
                            onPressed: _viewAllPreconfiguredCarts,
                            child: const Text(
                              'Voir tout',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _cartsPageController,
                        itemCount: _featuredCarts.length,
                        itemBuilder: (context, index) {
                          final cart = _featuredCarts[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildFeaturedCartCard(cart, isDark),
                          );
                        },
                      ),
                    ),
                    // Indicateurs de page
                    Container(
                      height: 20,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _featuredCarts.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Grille des produits
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? _buildErrorState(isDark)
                      : _products.isEmpty
                          ? _buildEmptyState(isDark)
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: RefreshIndicator(
                                onRefresh: _loadData,
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(20),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        0.7, // Ajusté pour éviter l'overflow
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final product = _products[index];
                                    return _buildProductCard(product, isDark);
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCartCard(Map<String, dynamic> cart, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewCartDetails(cart),
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Image de fond
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: cart['image'] != null
                    ? Image.network(
                        cart['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.shopping_basket,
                              color: AppColors.primary,
                              size: 60,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(
                          Icons.shopping_basket,
                          color: AppColors.primary,
                          size: 60,
                        ),
                      ),
              ),
            ),

            // Overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Contenu
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge catégorie
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cart['category'] ?? 'Panier',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nom du panier
                  Text(
                    cart['name'] ?? 'Panier',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description - Limitée à 1 ligne pour éviter la déformation
                  Text(
                    cart['description'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    maxLines: 1, // Changé de 2 à 1 ligne
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Prix et nombre d'articles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyUtils.formatPrice(
                            cart['total_price']?.toDouble() ?? 0.0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cart['items_count'] ?? 0} articles',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorder(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Titre
            Text(
              'Filtrer les produits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 20),

            // Catégories
            Text(
              'Catégories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = category == _selectedCategory;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    Navigator.pop(context);
                    _loadProducts();
                  },
                  backgroundColor: AppColors.getBackground(isDark),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.getTextSecondary(isDark),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.getBorder(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.error.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Impossible de charger les produits. Veuillez vérifier votre connexion.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedCategory = 'Tous';
              });
              _loadProducts();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réinitialiser les filtres'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final isInStock = product['in_stock'] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewProduct(product),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du produit
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: product['image'] != null
                          ? Image.network(
                              product['image'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.primary.withOpacity(0.1),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: AppColors.primary,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Badge de disponibilité
                  if (!isInStock)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Rupture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Badge catégorie
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        product['category'] ?? 'Autre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Rating
                  if (product['rating'] != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product['rating'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Informations du produit
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom du produit
                    Flexible(
                      child: Text(
                        product['name'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Unité
                    if (product['unit'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product['unit'],
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // Prix et bouton d'ajout
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Prix
                        Expanded(
                          child: Text(
                            CurrencyUtils.formatPrice(
                                product['price']?.toDouble() ?? 0.0),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Bouton d'ajout au panier
                        GestureDetector(
                          onTap: isInStock ? () => _addToCart(product) : null,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isInStock
                                  ? AppColors.primary
                                  : AppColors.getTextSecondary(isDark),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isInStock
                                  ? [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour le drawer des détails de panier préconfigué
class PreconfiguredCartDetailsDrawer extends StatelessWidget {
  final Map<String, dynamic> cart;
  final Future<void> Function()? onAddToCart;

  const PreconfiguredCartDetailsDrawer({
    super.key,
    required this.cart,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = cart['items'] as List<dynamic>? ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getBorder(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header avec image
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getShadow(isDark),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: cart['image'] != null
                      ? Image.network(
                          cart['image'],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.shopping_basket,
                                color: AppColors.primary,
                                size: 80,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Icon(
                            Icons.shopping_basket,
                            color: AppColors.primary,
                            size: 80,
                          ),
                        ),
                ),

                // Overlay avec informations
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cart['category'] ?? 'Panier',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (cart['is_featured'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Vedette',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cart['name'] ?? 'Panier',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyUtils.formatPrice(
                            cart['total_price']?.toDouble() ?? 0.0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cart['description'] ?? 'Aucune description disponible',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.getTextSecondary(isDark),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Articles inclus
                  Text(
                    'Articles inclus (${items.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.getBackground(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Article',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              AppColors.getTextPrimary(isDark),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item['unit'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item['unit'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.getTextSecondary(
                                                isDark),
                                          ),
                                        ),
                                      ],
                                    ]),
                              ),
                              Text(
                                'x${item['quantity'] ?? 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Boutons d'action
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.getBorder(isDark)),
                    ),
                    child: Text(
                      'Fermer',
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAddToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ajouter au panier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
