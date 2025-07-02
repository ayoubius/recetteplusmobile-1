import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_service.dart';
import '../widgets/simple_video_player.dart';
import '../widgets/recipe_drawer.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _videos = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _currentIndex = 0;
  int _currentPage = 0;
  static const int _pageSize = 10;
  final bool _showRecipeDrawer = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Pause toutes les vidéos quand l'app passe en arrière-plan
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      // Les vidéos se mettront automatiquement en pause via isVisible=false
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final results = await Future.wait([
        VideoService.getVideos(limit: _pageSize, offset: 0),
        VideoService.getVideoCategories(),
      ]);

      if (mounted) {
        setState(() {
          _videos = results[0] as List<Map<String, dynamic>>;
          _categories = results[1] as List<String>;
          _isLoading = false;
          _currentPage = 0;
        });
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

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newVideos = await VideoService.getVideos(
        limit: _pageSize,
        offset: nextPage * _pageSize,
        category: _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted && newVideos.isNotEmpty) {
        setState(() {
          _videos.addAll(newVideos);
          _currentPage = nextPage;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de plus de vidéos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final videos = await VideoService.getVideos(
        limit: _pageSize,
        offset: 0,
        category: _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _videos = videos;
          _currentPage = 0;
          _currentIndex = 0;
          _isLoading = false;
        });

        if (_videos.isNotEmpty) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onCategorySelected(String? category) {
    if (category != _selectedCategory) {
      setState(() {
        _selectedCategory = category;
      });
      _performSearch();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
    });
    _loadInitialData();
  }

  void _openRecipeDrawer(String recipeId) {
    HapticFeedback.mediumImpact();
    
    // Mettre en pause la vidéo avant d'ouvrir le drawer
    //_videoManager.pauseAll();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecipeDrawer(
        recipeId: recipeId,
        onClose: () => Navigator.of(context).pop(),
        onCartUpdated: () {
          // Callback pour mise à jour du panier
        },
      ),
    );
  }

  void _onVideoLike() {
    // TODO: Implement like functionality
  }

  void _onVideoShare() {
    // TODO: Implement share functionality
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec recherche
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Column(
                children: [
                  // Barre de recherche
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher des vidéos...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[400]),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filtres par catégorie
                  if (_categories.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildCategoryChip('Toutes', null);
                          }
                          final category = _categories[index - 1];
                          return _buildCategoryChip(category, category);
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => _onCategorySelected(value),
        backgroundColor: Colors.grey[800],
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.black,
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_hasError) {
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
              'Erreur lors du chargement des vidéos',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Aucune vidéo trouvée pour "$_searchQuery"'
                  : 'Aucune vidéo disponible',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedCategory != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Voir toutes les vidéos'),
              ),
            ],
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo is ScrollEndNotification &&
            scrollInfo.metrics.extentAfter < 200) {
          _loadMoreVideos();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Charger plus de vidéos si on approche de la fin
          if (index >= _videos.length - 2) {
            _loadMoreVideos();
          }
        },
        itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final video = _videos[index];
          final isVisible = index == _currentIndex;

          return SimpleVideoPlayer(
            key: ValueKey(video['id']),
            video: video,
            isActive: index == _currentIndex && !_showRecipeDrawer,
            onRecipePressed: video['recipe_id'] != null
                ? () => _openRecipeDrawer(video['recipe_id'])
                : null,
            onLike: _onVideoLike,
            onShare: _onVideoShare,
          );
        },
      ),
    );
  }
}
