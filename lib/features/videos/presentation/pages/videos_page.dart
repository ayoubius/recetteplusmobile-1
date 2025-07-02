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
  bool _showFiltersModal = false;
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
        _videoManager.pauseAll();
        break;
      case AppLifecycleState.resumed:
        break;
      default:
        break;
    }
  }

  void _onPageExit() {
    _videoManager.pauseAll();
    if (kDebugMode) {
      print('🚪 Sortie de la page vidéos - Pause automatique');
    }
  }

  void _onPageEnter() {
    if (kDebugMode) {
      print('🚪 Entrée sur la page vidéos');
    }
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
    _videoManager.pauseAll();
    
    setState(() {
      _selectedCategory = category;
      _filteredVideos = _filterVideosByCategory(_videos, category);
      _currentIndex = 0;
      _showFiltersModal = false;
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
  }

  void _onVideoLike() {
    HapticFeedback.lightImpact();
  }

  void _onVideoShare() {
    HapticFeedback.lightImpact();
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
        _onPageExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Contenu principal - vidéos en plein écran
            _buildMainContent(),
            
            // Boutons flottants
            _buildFloatingButtons(),
            
            // Modals
            if (_showFiltersModal) _buildFiltersModal(),
            if (_showSearchModal) _buildSearchModal(),
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
    );
  }

  Widget _buildFloatingButtons() {
    return SafeArea(
      child: Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bouton de recherche
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () {
                    _videoManager.pauseAll();
                    setState(() {
                      _showSearchModal = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            
            // Bouton de filtres
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _selectedCategory != 'Tous' 
                      ? AppColors.primary.withOpacity(0.8)
                      : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () {
                    _videoManager.pauseAll();
                    setState(() {
                      _showFiltersModal = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          color: _selectedCategory != 'Tous' 
                              ? AppColors.primary 
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCategory,
                          style: TextStyle(
                            color: _selectedCategory != 'Tous' 
                                ? AppColors.primary 
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersModal() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showFiltersModal = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Catégories',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des catégories
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    
                    return Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: Colors.white.withOpacity(0.3))
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _filterByCategory(category),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: isSelected 
                                      ? FontWeight.bold 
                                      : FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchModal() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header de recherche
            Container(
              padding: const EdgeInsets.all(20),
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Rechercher des vidéos...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, 
                            vertical: 16
                          ),
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
                  ? _buildSearchSuggestions()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories populaires',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _categories.length - 1,
              itemBuilder: (context, index) {
                final category = _categories[index + 1];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _filterByCategory(category);
                        setState(() {
                          _showSearchModal = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _isSearching
                ? 'Recherche en cours...'
                : '${_searchResults.length} résultat(s)',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 16),
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
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                video['category'],
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
        ),
      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
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
}
