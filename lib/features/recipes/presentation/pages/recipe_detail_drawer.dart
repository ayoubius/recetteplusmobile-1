import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/recipe_service.dart';

class RecipeDetailDrawer extends StatefulWidget {
  final String recipeId;
  final VoidCallback onClose;
  final VoidCallback? onCartUpdated;

  const RecipeDetailDrawer({
    super.key,
    required this.recipeId,
    required this.onClose,
    this.onCartUpdated,
  });

  @override
  State<RecipeDetailDrawer> createState() => _RecipeDetailDrawerState();
}

class _RecipeDetailDrawerState extends State<RecipeDetailDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavorite = false;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRecipe();
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

  Future<void> _loadRecipe() async {
    try {
      final recipe = await RecipeService.getRecipeById(widget.recipeId);
      if (recipe != null) {
        setState(() {
          _recipe = recipe;
          _isLoading = false;
        });

        // Vérifier si en favoris
        final isFav = await RecipeService.isFavorite(widget.recipeId);
        setState(() {
          _isFavorite = isFav;
        });

        // Ajouter à l'historique
        await RecipeService.addToHistory(widget.recipeId);
        
        // Incrémenter les vues
        await RecipeService.incrementViewCount(widget.recipeId);
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    
    if (_isFavorite) {
      final success = await RecipeService.removeFromFavorites(widget.recipeId);
      if (success) {
        setState(() {
          _isFavorite = false;
        });
        _showSnackBar('Recette retirée des favoris', AppColors.primary);
      }
    } else {
      final success = await RecipeService.addToFavorites(widget.recipeId);
      if (success) {
        setState(() {
          _isFavorite = true;
        });
        _showSnackBar('Recette ajoutée aux favoris', AppColors.primary);
      }
    }
  }

  Future<void> _addRecipeToCart() async {
    if (_recipe == null) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final success = await RecipeService.createCartFromRecipe(widget.recipeId);

      if (mounted) {
        if (success) {
          HapticFeedback.lightImpact();
          _showSnackBar(
            'Ingrédients de "${_recipe!['title']}" ajoutés au panier',
            AppColors.success,
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: Colors.white,
              onPressed: () {
                widget.onCartUpdated?.call();
                _close();
              },
            ),
          );

          // Notifier la mise à jour du panier
          widget.onCartUpdated?.call();
        } else {
          _showSnackBar('Erreur lors de l\'ajout au panier', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: $e', AppColors.error);
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

  void _addNotes() {
    HapticFeedback.lightImpact();
    _showSnackBar('Fonctionnalité de notes bientôt disponible !', AppColors.primary);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              decoration: BoxDecoration(
                color: AppColors.getCardBackground(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getShadow(isDark),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header avec bouton fermer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Détails de la recette',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        IconButton(
                          onPressed: _close,
                          icon: Icon(
                            Icons.close,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Expanded(
                    child: _buildContent(isDark),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isDark) {
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
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger la recette',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _loadRecipe();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
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
                      color: AppColors.getBackground(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      size: 64,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Titre et description
          Text(
            _recipe!['title'],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),

          if (_recipe!['description'] != null && _recipe!['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _recipe!['description'],
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Statistiques
          Row(
            children: [
              _buildStatChip(
                Icons.access_time,
                _recipe!['formatted_time'],
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people,
                '${_recipe!['servings']} pers.',
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.star,
                '${_recipe!['rating']}/5',
                isDark,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Difficulté et coût
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Difficulté: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    Text(
                      _recipe!['difficulty'],
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
                'Coût: ${_recipe!['total_cost'].toStringAsFixed(2)} FCFA',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
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
                  color: _isFavorite ? AppColors.error : AppColors.getTextSecondary(isDark),
                ),
              ),
              IconButton(
                onPressed: _shareRecipe,
                icon: Icon(
                  Icons.share,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              IconButton(
                onPressed: _addNotes,
                icon: Icon(
                  Icons.note_add,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Ingrédients
          Text(
            'Ingrédients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),

          const SizedBox(height: 12),

          ...(_recipe!['ingredients'] as List<Map<String, dynamic>>).map(
            (ingredient) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getBackground(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  // Image du produit
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ingredient['image'] != null
                        ? Image.network(
                            ingredient['image'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 40,
                                height: 40,
                                color: AppColors.getBorder(isDark),
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 20,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: AppColors.getBorder(isDark),
                            child: Icon(
                              Icons.shopping_basket,
                              size: 20,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Détails de l'ingrédient
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ingredient['quantity']} ${ingredient['unit']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Prix et statut
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${ingredient['price'].toStringAsFixed(2)} FCFA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ingredient['in_stock']
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ingredient['in_stock'] ? 'En stock' : 'Rupture',
                          style: TextStyle(
                            fontSize: 10,
                            color: ingredient['in_stock']
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          Text(
            'Instructions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),

          const SizedBox(height: 12),

          ...(_recipe!['instructions'] as List<String>).asMap().entries.map(
                (entry) => Container(
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
                            '${entry.key + 1}',
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
                            entry.value,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.getTextSecondary(isDark),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'facile':
        return AppColors.success;
      case 'moyen':
        return AppColors.warning;
      case 'difficile':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}