import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/recipe_service.dart';
import '../../../../core/services/cart_service.dart';

class RecipeDrawer extends StatefulWidget {
  final String recipeId;
  final VoidCallback onClose;
  final VoidCallback? onCartUpdated;

  const RecipeDrawer({
    super.key,
    required this.recipeId,
    required this.onClose,
    this.onCartUpdated,
  });

  @override
  State<RecipeDrawer> createState() => _RecipeDrawerState();
}

class _RecipeDrawerState extends State<RecipeDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _recipe;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavorite = false;
  bool _isAddingToCart = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRecipeData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  Future<void> _loadRecipeData() async {
    try {
      // Charger la recette
      final recipe = await RecipeService.getRecipeById(widget.recipeId);
      if (recipe != null) {
        setState(() {
          _recipe = recipe;
        });

        // Charger les produits liés (simulation)
        await _loadRecipeProducts();

        // Vérifier si en favoris
        final isFav = await RecipeService.isRecipeFavorite(widget.recipeId);
        setState(() {
          _isFavorite = isFav;
          _isLoading = false;
        });

        // Ajouter à l'historique et incrémenter les vues
        await RecipeService.addRecipeToHistory(widget.recipeId);
        await RecipeService.incrementRecipeViews(widget.recipeId);
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Recette introuvable';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecipeProducts() async {
    if (_recipe == null) return;

    try {
      final ingredients = _recipe!['ingredients'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> products = [];

      // Simulation de produits liés aux ingrédients
      for (int i = 0; i < ingredients.length && i < 5; i++) {
        final ingredient = ingredients[i];
        if (ingredient is Map<String, dynamic>) {
          // Créer un produit simulé basé sur l'ingrédient
          products.add({
            'id': 'product_${i + 1}',
            'name': ingredient['name'] ?? 'Produit ${i + 1}',
            'price': (10.0 + (i * 2.5)),
            'unit': ingredient['unit'] ?? 'kg',
            'recipe_quantity': ingredient['quantity'] ?? 1,
            'recipe_unit': ingredient['unit'] ?? 'pièce',
            'in_stock': i % 3 != 0, // Simulation de stock
            'image': null, // Pas d'image pour la simulation
          });
        }
      }

      setState(() {
        _products = products;
      });
    } catch (e) {
      // Ignore product loading errors
    }
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    
    final newFavoriteStatus = await RecipeService.toggleRecipeFavorite(widget.recipeId);
    if (mounted) {
      setState(() {
        _isFavorite = newFavoriteStatus;
      });

      _showSnackBar(
        _isFavorite
            ? 'Recette ajoutée aux favoris'
            : 'Recette retirée des favoris',
        AppColors.primary,
      );
    }
  }

  Future<void> _addRecipeToCart() async {
    if (_recipe == null) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Simulation d'ajout au panier
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        HapticFeedback.lightImpact();
        _showSnackBar(
          'Ingrédients de "${_recipe!['title']}" ajoutés au panier',
          Colors.green,
          action: SnackBarAction(
            label: 'Voir panier',
            textColor: Colors.white,
            onPressed: () {
              widget.onCartUpdated?.call();
              _close();
            },
          ),
        );

        widget.onCartUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur lors de l\'ajout au panier', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  void _shareRecipe() {
    HapticFeedback.lightImpact();
    _showSnackBar('Fonctionnalité de partage bientôt disponible !', AppColors.primary);
  }

  void _showSnackBar(String message, Color backgroundColor, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Détails de la recette',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _close,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_hasError || _recipe == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Impossible de charger la recette',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _loadRecipeData();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image de la recette
          if (_recipe!['image'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _recipe!['image'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Titre et description
          Text(
            _recipe!['title'] ?? 'Recette sans titre',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (_recipe!['description'] != null && _recipe!['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _recipe!['description'].toString(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Statistiques
          Row(
            children: [
              _buildStatChip(
                Icons.access_time,
                '${_recipe!['cook_time'] ?? _recipe!['formatted_time'] ?? '30'} min',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people,
                '${_recipe!['servings'] ?? 4} pers.',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.star,
                '${_recipe!['rating'] ?? 4.5}/5',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Difficulté et vues
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Difficulté: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _recipe!['difficulty'] ?? 'Moyen',
                      style: TextStyle(
                        fontSize: 16,
                        color: _getDifficultyColor(_recipe!['difficulty']),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_recipe!['view_count'] ?? 0} vues',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAddingToCart ? null : _addRecipeToCart,
                  icon: _isAddingToCart
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.shopping_cart),
                  label:
                      Text(_isAddingToCart ? 'Ajout...' : 'Ajouter au panier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.grey,
                ),
              ),
              IconButton(
                onPressed: _shareRecipe,
                icon: const Icon(Icons.share),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Produits liés
          if (_products.isNotEmpty) ...[
            const Text(
              'Produits nécessaires',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...(_products.map((product) => _buildProductCard(product))),
            const SizedBox(height: 24),
          ],

          // Ingrédients
          const Text(
            'Ingrédients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...(_recipe!['ingredients'] as List<dynamic>? ?? []).map(
            (ingredient) => _buildIngredientCard(ingredient),
          ),

          const SizedBox(height: 24),

          // Instructions
          const Text(
            'Instructions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...(_recipe!['instructions'] as List<dynamic>? ?? []).asMap().entries.map(
                (entry) => _buildInstructionStep(entry.key + 1, entry.value.toString()),
              ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image du produit
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product['image'] != null
                ? Image.network(
                    product['image'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 24,
                          color: Colors.grey[500],
                        ),
                      );
                    },
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.shopping_basket,
                      size: 24,
                      color: Colors.grey[500],
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          
          // Détails du produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Produit sans nom',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['recipe_quantity']} ${product['recipe_unit']} nécessaire(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${product['price']?.toStringAsFixed(2) ?? '0.00'} € / ${product['unit'] ?? 'unité'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (product['in_stock'] ?? false)
                            ? Colors.green[100]
                            : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (product['in_stock'] ?? false) ? 'En stock' : 'Rupture',
                        style: TextStyle(
                          fontSize: 10,
                          color: (product['in_stock'] ?? false)
                              ? Colors.green[700]
                              : Colors.red[700],
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
    );
  }

  Widget _buildIngredientCard(dynamic ingredient) {
    if (ingredient is! Map<String, dynamic>) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
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
            child: Text(
              '${ingredient['quantity'] ?? ''} ${ingredient['unit'] ?? ''} ${ingredient['name'] ?? 'Ingrédient'}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                instruction,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'facile':
        return Colors.green;
      case 'moyen':
        return Colors.orange;
      case 'difficile':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
