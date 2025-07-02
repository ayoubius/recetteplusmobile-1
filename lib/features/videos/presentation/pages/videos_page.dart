import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../../core/services/video_service.dart';
import '../../../../core/services/simple_video_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/simple_video_player.dart';
import '../widgets/recipe_drawer.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage>
    with WidgetsBindingObserver, RouteAware {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final SimpleVideoManager _videoManager = SimpleVideoManager();

  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  bool _showSearchModal = false;
  bool _showRecipeDrawer = false;
  bool _hasMoreVideos = true;
  String? _currentRecipeId;

  int _currentIndex = 0;
  int _currentPage = 0;
  final int _videosPerPage = 10;
  String _selectedCategory = 'Tous';

  Timer? _searchDebounceTimer;

  final List<String> _categories = [
    'Tous',
    'Entrées',
    'Plats principaux',
    'Desserts',
    'Boissons',
    'Snacks',
    'Végétarien',
    'Vegan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _videoManager.disposeAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Mettre en pause toutes les vidéos quand l'app passe en arrière-plan
        _videoManager.pauseAll();
        break;
      case AppLifecycleState.resumed:
        // Ne pas reprendre automatiquement, laisser l'utilisateur décider
        break;
      default:
        break;
    }
  }

  // Méthode appelée quand on quitte la page des vidéos
  void _onPageExit() {
    _videoManager.pauseAll();
    if (kDebugMode) {
      print('🚪 Sortie de la page vidéos - Pause automatique');
    }
  }

  // Méthode appelée quand on revient sur la page des vidéos
  void _onPageEnter() {
    if (kDebugMode) {
      print('🚪 Entrée sur la page vidéos');
    }
    // Ne pas reprendre automatiquement la lecture
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMoreVideos = true;
    });

    try {
      final videos = await VideoService.getVideos(
        category: _selectedCategory == 'Tous' ? null : _selectedCategory,
        limit: _videosPerPage,
      );

      if (mounted) {
        setState(() {
          _videos = videos;
          _filteredVideos = videos;
          _isLoading = false;
          _hasMoreVideos = videos.length >= _videosPerPage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMoreVideos = false;
        });
        _showErrorSnackBar('Erreur de chargement: $e');
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos || !mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final excludeIds = _videos.map((video) => video['id'].toString()).toList();

      final moreVideos = await VideoService.getInfiniteVideos(
        offset: nextPage * _videosPerPage,
        batchSize: _videosPerPage,
        excludeIds: excludeIds,
      );

      if (mounted) {
        setState(() {
          if (moreVideos.isNotEmpty) {
            _videos.addAll(moreVideos);
            _filteredVideos = _filterVideosByCategory(_videos, _selectedCategory);
            _currentPage = nextPage;
            _hasMoreVideos = moreVideos.length >= _videosPerPage;
          } else {
            _hasMoreVideos = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showErrorSnackBar('Erreur de chargement: $e');
      }
    }
  }

  List<Map<String, dynamic>> _filterVideosByCategory(
      List<Map<String, dynamic>> videos, String category) {
    if (category == 'Tous') {
      return videos;
    }
    return videos.where((video) => video['category'] == category).toList();
  }

  void _filterByCategory(String category) {
    // Mettre en pause avant de changer de catégorie
    _videoManager.pauseAll();
    
    setState(() {
      _selectedCategory = category;
      _filteredVideos = _filterVideosByCategory(_videos, category);
      _currentIndex = 0;
    });

    if (_filteredVideos.isNotEmpty) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _performSearch(String query) async {
    _searchDebounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() {
        _isSearching = true;
      });

      try {
        final results = await VideoService.searchVideos(searchQuery: query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          _showErrorSnackBar('Erreur de recherche: $e');
        }
      }
    });
  }

  void _openRecipeDrawer(String recipeId) {
    HapticFeedback.mediumImpact();
    
    // Mettre en pause la vidéo avant d'ouvrir le drawer
    _videoManager.pauseAll();
    
    setState(() {
      _currentRecipeId = recipeId;
      _showRecipeDrawer = true;
    });
  }

  void _closeRecipeDrawer() {
    setState(() {
      _showRecipeDrawer = false;
      _currentRecipeId = null;
    });
    // Ne pas reprendre automatiquement la lecture
  }

  void _onVideoLike() {
    HapticFeedback.lightImpact();
    // Le like est géré dans SimpleVideoPlayer
  }

  void _onVideoShare() {
    HapticFeedback.lightImpact();
    // TODO: Implémenter le partage
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Mettre en pause quand on quitte la page
        _onPageExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildMainContent(),
            if (_showSearchModal) _buildSearchOverlay(),
            if (_showRecipeDrawer && _currentRecipeId != null)
              Positioned.fill(
                child: RecipeDrawer(
                  recipeId: _currentRecipeId!,
                  onClose: _closeRecipeDrawer,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_filteredVideos.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // Liste des vidéos
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Charger plus de vidéos si nécessaire
            if (index >= _filteredVideos.length - 3 && !_isLoadingMore && _hasMoreVideos) {
              _loadMoreVideos();
            }
          },
          itemCount: _filteredVideos.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _filteredVideos.length) {
              return _buildLoadingMoreIndicator();
            }

            final video = _filteredVideos[index];
            return SimpleVideoPlayer(
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

        // Interface utilisateur overlay
        _buildTopInterface(),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Chargement des vidéos...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune vidéo disponible',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Essayez de changer de catégorie',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInterface() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bouton de recherche
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  // Mettre en pause avant d'ouvrir la recherche
                  _videoManager.pauseAll();
                  setState(() {
                    _showSearchModal = true;
                  });
                },
                icon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            // Sélecteur de catégorie
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.black.withOpacity(0.9),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _filterByCategory(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header de recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showSearchModal = false;
                        _searchController.clear();
                        _searchResults.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher des vidéos...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                )
                              : null,
                        ),
                        onChanged: _performSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu de recherche
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildSearchCategories()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCategories() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories populaires',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _categories.length - 1,
              itemBuilder: (context, index) {
                final category = _categories[index + 1];
                return GestureDetector(
                  onTap: () {
                    _filterByCategory(category);
                    setState(() {
                      _showSearchModal = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _isSearching
                ? 'Recherche en cours...'
                : '${_searchResults.length} résultat(s)',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isSearching)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun résultat trouvé',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final video = _searchResults[index];
                return _buildSearchResultItem(video);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSearchModal = false;
          _searchController.clear();
          _searchResults.clear();
          _filteredVideos = [video];
          _currentIndex = 0;
        });

        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 60,
                color: Colors.grey[700],
                child: video['thumbnail'] != null
                    ? Image.network(
                        video['thumbnail'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white54,
                            size: 32,
                          );
                        },
                      )
                    : const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white54,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? 'Vidéo sans titre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (video['duration'] != null) ...[
                        Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${video['duration']}s',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                      if (video['category'] != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.category, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          video['category'],
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Indicateur recette
            if (video['recipe_id'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
