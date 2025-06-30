import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/recipe_service.dart';
import '../../../../core/constants/app_colors.dart';

class RecipeDrawer extends StatefulWidget {
  final String recipeId;
  final VoidCallback onClose;

  const RecipeDrawer({
    Key? key,
    required this.recipeId,
    required this.onClose,
  }) : super(key: key);

  @override
  State<RecipeDrawer> createState() => _RecipeDrawerState();
}

class _RecipeDrawerState extends State<RecipeDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavorite = false;

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
      final recipeData = await RecipeService.getRecipeById(widget.recipeId);
      final favorite = await RecipeService.isRecipeFavorite(widget.recipeId);

      if (mounted) {
        setState(() {
          _recipe = recipeData;
          _isFavorite = favorite;
          _isLoading = false;
        });

        // Ajouter à l'historique
        RecipeService.addRecipeToHistory(widget.recipeId);
        RecipeService.incrementRecipeViews(widget.recipeId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _toggleFavorite() async {
    final newFavoriteStatus =
        await RecipeService.toggleRecipeFavorite(widget.recipeId);
    if (mounted) {
      setState(() {
        _isFavorite = newFavoriteStatus;
      });

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'Recette ajoutée aux favoris'
                : 'Recette retirée des favoris',
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
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
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recette associée',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _toggleFavorite,
                              icon: Icon(
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.grey,
                              ),
                            ),
                            IconButton(
                              onPressed: _close,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Contenu
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
              'Impossible de charger la recette',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
          // Image et titre
          if (_recipe!['image'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _recipe!['image'],
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          Text(
            _recipe!['title'] ?? 'Sans titre',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (_recipe!['description'] != null &&
              _recipe!['description'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _recipe!['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Statistiques rapides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(Icons.access_time, _recipe!['formatted_time']),
              _buildQuickStat(Icons.people, '${_recipe!['servings']} pers.'),
              _buildQuickStat(Icons.star, '${_recipe!['rating']}/5'),
            ],
          ),

          const SizedBox(height: 20),

          // Ingrédients (version simplifiée)
          const Text(
            'Ingrédients principaux',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          ...(_recipe!['ingredients'] as List<Map<String, dynamic>>)
              .take(5)
              .map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ingredient['quantity']} ${ingredient['unit']} ${ingredient['name']}'
                              .trim(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          if ((_recipe!['ingredients'] as List).length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${(_recipe!['ingredients'] as List).length - 5} autres ingrédients',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bouton pour voir la recette complète
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Naviguer vers la page complète de la recette
                _showSnackBar(
                    'Navigation vers la recette complète bientôt disponible !');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Voir la recette complète'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
