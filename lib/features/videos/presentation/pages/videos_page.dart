import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/services/video_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/recipe_drawer.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({Key? key}) : super(key: key);

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _shouldPauseAllVideos = ValueNotifier(false);

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

    // Ajouter un listener pour le scroll infini
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shouldPauseAllVideos.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreVideos) {
      _loadMoreVideos();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _shouldPauseAllVideos.value = true;
        break;
      case AppLifecycleState.resumed:
        _shouldPauseAllVideos.value = false;
        break;
      default:
        break;
    }
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMoreVideos = true;
      });

      final videos = await VideoService.getVideos(
        category: _selectedCategory == 'Tous' ? null : _selectedCategory,
        limit: _videosPerPage,
      );

      setState(() {
        _videos = videos;
        _filteredVideos = videos;
        _isLoading = false;
        _hasMoreVideos = videos.length >= _videosPerPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMoreVideos = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final offset = nextPage * _videosPerPage;

      // Récupérer les IDs des vidéos déjà chargées pour les exclure
      final excludeIds =
          _videos.map((video) => video['id'].toString()).toList();

      final moreVideos = await VideoService.getInfiniteVideos(
        offset: offset,
        batchSize: _videosPerPage,
        excludeIds: excludeIds,
      );

      if (moreVideos.isNotEmpty) {
        setState(() {
          _videos.addAll(moreVideos);
          _filteredVideos = _filterVideosByCategory(_videos, _selectedCategory);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMoreVideos = moreVideos.length >= _videosPerPage;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasMoreVideos = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterVideosByCategory(
      List<Map<String, dynamic>> videos, String category) {
    if (category == 'Tous') {
      return videos;
    } else {
      return videos.where((video) => video['category'] == category).toList();
    }
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredVideos = _filterVideosByCategory(_videos, category);
      _currentIndex = 0;
    });

    // Aller à la première vidéo de la catégorie
    if (_filteredVideos.isNotEmpty) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await VideoService.searchVideos(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de recherche: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openRecipeDrawer(String recipeId) {
    HapticFeedback.mediumImpact();
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

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';

    try {
      int totalSeconds;
      if (duration is String) {
        totalSeconds = int.tryParse(duration) ?? 0;
      } else if (duration is int) {
        totalSeconds = duration;
      } else {
        return '0:00';
      }

      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '0:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Contenu principal
          _buildMainContent(),

          // Overlay de recherche
          if (_showSearchModal) _buildSearchOverlay(),

          // Drawer de recette
          if (_showRecipeDrawer && _currentRecipeId != null)
            Positioned.fill(
              child: RecipeDrawer(
                recipeId: _currentRecipeId!,
                onClose: _closeRecipeDrawer,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_filteredVideos.isEmpty) {
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
              'Aucune vidéo disponible',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVideos,
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // PageView des vidéos avec scroll infini
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Charger plus de vidéos quand on approche de la fin
            if (index >= _filteredVideos.length - 3 &&
                !_isLoadingMore &&
                _hasMoreVideos) {
              _loadMoreVideos();
            }
          },
          itemCount: _filteredVideos.length + (_hasMoreVideos ? 1 : 0),
          itemBuilder: (context, index) {
            // Afficher un indicateur de chargement à la fin
            if (index == _filteredVideos.length) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            final video = _filteredVideos[index];
            return VideoPlayerWidget(
              video: video,
              isActive:
                  (index - _currentIndex).abs() <= 1 && !_showRecipeDrawer,
              pauseNotifier: _shouldPauseAllVideos,
              onRecipePressed: video['recipe_id'] != null
                  ? () => _openRecipeDrawer(video['recipe_id'])
                  : null,
            );
          },
        ),

        // Interface overlay
        _buildOverlayInterface(),
      ],
    );
  }

  Widget _buildOverlayInterface() {
    return SafeArea(
      child: Column(
        children: [
          // Header avec recherche et catégories
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bouton recherche
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showSearchModal = true;
                    });
                  },
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const Spacer(),

                // Sélecteur de catégorie
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      dropdownColor: Colors.black.withOpacity(0.8),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white),
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

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher des vidéos...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults.clear();
                                  });
                                },
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _performSearch(value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Catégories de recherche
            if (_searchController.text.isEmpty) _buildSearchCategories(),

            // Résultats de recherche
            if (_searchController.text.isNotEmpty) _buildSearchResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCategories() {
    return Expanded(
      child: Padding(
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
                itemCount: _categories.length - 1, // Exclure "Tous"
                itemBuilder: (context, index) {
                  final category = _categories[index + 1];
                  return _buildCategoryCard(category);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
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
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _isSearching
                  ? 'Recherche en cours...'
                  : '${_searchResults.length} résultat(s) trouvé(s)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          else if (_searchResults.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat trouvé',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  return _buildSearchResultItem(_searchResults[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () {
        // Fermer la recherche et aller à cette vidéo
        setState(() {
          _showSearchModal = false;
          _searchController.clear();
          _searchResults.clear();
          _filteredVideos = [video]; // Afficher seulement cette vidéo
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
                          return Icon(
                            Icons.play_circle_outline,
                            color: Colors.grey[400],
                            size: 32,
                          );
                        },
                      )
                    : Icon(
                        Icons.play_circle_outline,
                        color: Colors.grey[400],
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
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(video['duration']),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (video['category'] != null) ...[
                        Icon(
                          Icons.category,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video['category'],
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Indicateur de recette
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
