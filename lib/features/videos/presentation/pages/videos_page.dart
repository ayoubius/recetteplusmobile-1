import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../../core/services/video_service.dart';
import '../../../../core/services/enhanced_simple_video_manager.dart';
import '../../../../core/services/video_lifecycle_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/simple_video_player.dart';
import '../widgets/recipe_drawer.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage>
    with
        WidgetsBindingObserver,
        RouteAware,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final EnhancedSimpleVideoManager _videoManager = EnhancedSimpleVideoManager();
  final VideoLifecycleManager _lifecycleManager = VideoLifecycleManager();

  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _originalVideos =
      []; // Sauvegarder les vidéos originales

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  bool _showFiltersModal = false;
  bool _showSearchModal = false;
  bool _showRecipeDrawer = false;
  bool _hasMoreVideos = true;
  bool _isInSearchMode = false; // Nouveau flag pour le mode recherche
  String? _currentRecipeId;

  int _currentIndex = 0;
  int _currentPage = 0;
  final int _videosPerPage = 10;
  String _selectedCategory = 'Tous';

  Timer? _searchDebounceTimer;

  // Animation controllers
  late AnimationController _filterButtonController;
  late AnimationController _searchButtonController;
  late AnimationController _modalController;

  late Animation<double> _filterButtonScale;
  late Animation<double> _searchButtonScale;
  late Animation<double> _modalSlide;
  late Animation<double> _modalFade;

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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupVideoManagement();
    _loadVideos();
  }

  void _initializeAnimations() {
    _filterButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _searchButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _filterButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _filterButtonController, curve: Curves.easeInOut),
    );
    _searchButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _searchButtonController, curve: Curves.easeInOut),
    );

    _modalSlide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _modalController, curve: Curves.easeOutCubic),
    );
    _modalFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _modalController, curve: Curves.easeOut),
    );
  }

  void _setupVideoManagement() {
    // Définir la page actuelle pour le gestionnaire de vidéos
    _videoManager.setCurrentPage('videos');

    // Ajouter des callbacks pour les événements de cycle de vie
    _lifecycleManager.addOnAppPausedCallback(_onAppPaused);
    _lifecycleManager.addOnPageChangedCallback(_onPageChanged);

    // Ajouter des callbacks pour les événements vidéo
    _videoManager.addOnPauseCallback(_onVideoPaused);
    _videoManager.addOnPlayCallback(_onVideoPlayed);
    _videoManager.addOnVideoInitializedCallback(_onVideoInitialized);

    if (kDebugMode) {
      print('🎬 Gestion vidéo configurée pour VideosPage');
    }
  }

  void _onVideoInitialized(String videoId) {
    // Démarrer la lecture automatique de la première vidéo si on n'est pas en mode recherche
    if (!_isInSearchMode && _filteredVideos.isNotEmpty && _currentIndex == 0) {
      final firstVideo = _filteredVideos[0];
      if (firstVideo['id']?.toString() == videoId) {
        _videoManager.startAutoPlayIfEnabled(videoId);
      }
    }
  }

  void _onAppPaused() {
    if (kDebugMode) {
      print('📱 App mise en pause - Arrêt des vidéos dans VideosPage');
    }
  }

  void _onPageChanged() {
    if (kDebugMode) {
      print('🔄 Changement de page détecté dans VideosPage');
    }
  }

  void _onVideoPaused() {
    if (kDebugMode) {
      print('⏸️ Vidéo mise en pause dans VideosPage');
    }
  }

  void _onVideoPlayed() {
    if (kDebugMode) {
      print('▶️ Vidéo en lecture dans VideosPage');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();

    // Nettoyer les callbacks
    _lifecycleManager.removeOnAppPausedCallback(_onAppPaused);
    _lifecycleManager.removeOnPageChangedCallback(_onPageChanged);
    _videoManager.removeOnPauseCallback(_onVideoPaused);
    _videoManager.removeOnPlayCallback(_onVideoPlayed);
    _videoManager.removeOnVideoInitializedCallback(_onVideoInitialized);

    // Nettoyer les animations
    _filterButtonController.dispose();
    _searchButtonController.dispose();
    _modalController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Le VideoLifecycleManager gère déjà les changements d'état de l'app
    // Pas besoin de dupliquer la logique ici
  }

  void _onPageExit() {
    _videoManager.pauseAll();
    if (kDebugMode) {
      print('🚪 Sortie de la page vidéos - Pause automatique');
    }
  }

  void _onPageEnter() {
    _videoManager.setCurrentPage('videos');
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
      _isInSearchMode = false;
    });

    try {
      final videos = await VideoService.getVideos(
        category: _selectedCategory == 'Tous' ? null : _selectedCategory,
        limit: _videosPerPage,
      );

      if (mounted) {
        setState(() {
          _videos = videos;
          _originalVideos =
              List.from(videos); // Sauvegarder les vidéos originales
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
    if (_isLoadingMore || !_hasMoreVideos || !mounted || _isInSearchMode)
      return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final excludeIds =
          _videos.map((video) => video['id'].toString()).toList();

      final moreVideos = await VideoService.getInfiniteVideos(
        offset: nextPage * _videosPerPage,
        batchSize: _videosPerPage,
        excludeIds: excludeIds,
      );

      if (mounted) {
        setState(() {
          if (moreVideos.isNotEmpty) {
            _videos.addAll(moreVideos);
            _originalVideos
                .addAll(moreVideos); // Mettre à jour les vidéos originales
            _filteredVideos =
                _filterVideosByCategory(_videos, _selectedCategory);
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
      _isInSearchMode = false;
      _filteredVideos = _filterVideosByCategory(_originalVideos, category);
      _currentIndex = 0;
      _showFiltersModal = false;
    });

    _modalController.reverse();

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

  void _selectSearchResult(Map<String, dynamic> video) {
    _videoManager.pauseAll();

    // Fermer le modal de recherche
    _modalController.reverse().then((_) {
      setState(() {
        _showSearchModal = false;
        _searchController.clear();
        _searchResults.clear();

        // Passer en mode recherche avec la vidéo sélectionnée
        _isInSearchMode = true;
        _filteredVideos = [video];
        _currentIndex = 0;
      });

      // Naviguer vers la vidéo sélectionnée
      _pageController
          .animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      )
          .then((_) {
        // Démarrer la lecture après la navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && video['id'] != null) {
            final videoId = video['id'].toString();
            _videoManager.playVideo(videoId);
            if (kDebugMode) {
              print('▶️ Lecture de la vidéo sélectionnée: $videoId');
            }
          }
        });
      });
    });
  }

  void _exitSearchMode() {
    setState(() {
      _isInSearchMode = false;
      _filteredVideos =
          _filterVideosByCategory(_originalVideos, _selectedCategory);
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

    // Reprendre la lecture après fermeture du drawer
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _videoManager.forceResumePlayback();
      }
    });
  }

  void _onVideoLike() {
    HapticFeedback.lightImpact();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC3545),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Fonction utilitaire pour valider les URLs d'images
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: () async {
        // Si on est en mode recherche, revenir au mode normal
        if (_isInSearchMode) {
          _exitSearchMode();
          return false;
        }
        _onPageExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Contenu principal - vidéos en plein écran
            _buildMainContent(),

            // Boutons flottants modernisés
            _buildFloatingButtons(),

            // Indicateur de mode recherche
            if (_isInSearchMode) _buildSearchModeIndicator(),

            // Modals avec animations
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

  Widget _buildSearchModeIndicator() {
    return SafeArea(
      child: Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.9),
                AppColors.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mode recherche - Résultat sélectionné',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _exitSearchMode,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
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
            scrollInfo.metrics.extentAfter < 200 &&
            !_isInSearchMode) {
          _loadMoreVideos();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() {
            _currentIndex =
                index % (_filteredVideos.isEmpty ? 1 : _filteredVideos.length);
          });

          if (_filteredVideos.isNotEmpty &&
              index >= _filteredVideos.length - 3 &&
              !_isLoadingMore &&
              _hasMoreVideos &&
              !_isInSearchMode) {
            _loadMoreVideos();
          }
        },
        itemCount: _filteredVideos.isEmpty ? 1 : 1000000, // Scroll infini
        itemBuilder: (context, index) {
          if (_filteredVideos.isEmpty) {
            return _buildEmptyState();
          }
          final video = _filteredVideos[index % _filteredVideos.length];
          return SimpleVideoPlayer(
            video: video,
            isActive: index % _filteredVideos.length == _currentIndex &&
                !_showRecipeDrawer,
            onRecipePressed: video['recipe_id'] != null
                ? () => _openRecipeDrawer(video['recipe_id'])
                : null,
            onLike: _onVideoLike,
          );
        },
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return SafeArea(
      child: Positioned(
        top: 24,
        left: 20,
        right: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bouton de recherche modernisé
            AnimatedBuilder(
              animation: _searchButtonScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _searchButtonScale.value,
                  child: GestureDetector(
                    onTapDown: (_) => _searchButtonController.forward(),
                    onTapUp: (_) => _searchButtonController.reverse(),
                    onTapCancel: () => _searchButtonController.reverse(),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _videoManager.pauseAll();
                      setState(() {
                        _showSearchModal = true;
                      });
                      _modalController.forward();
                    },
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bouton de filtres modernisé
            AnimatedBuilder(
              animation: _filterButtonScale,
              builder: (context, child) {
                return Transform.scale(
                    scale: _filterButtonScale.value,
                    child: GestureDetector(
                      onTapDown: (_) => _filterButtonController.forward(),
                      onTapUp: (_) => _filterButtonController.reverse(),
                      onTapCancel: () => _filterButtonController.reverse(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _videoManager.pauseAll();
                        setState(() {
                          _showFiltersModal = true;
                        });
                        _modalController.forward();
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient:
                              (_selectedCategory != 'Tous' || _isInSearchMode)
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withOpacity(0.8),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.25),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                (_selectedCategory != 'Tous' || _isInSearchMode)
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedCategory != 'Tous' ||
                                      _isInSearchMode)
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isInSearchMode
                                  ? Icons.search_rounded
                                  : Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isInSearchMode ? 'Recherche' : _selectedCategory,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersModal() {
    return AnimatedBuilder(
      animation: _modalController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.85 * _modalFade.value),
          child: Transform.translate(
            offset: Offset(
                0, MediaQuery.of(context).size.height * _modalSlide.value),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header modernisé
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _modalController.reverse().then((_) {
                                setState(() {
                                  _showFiltersModal = false;
                                });
                              });
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Catégories',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Liste des catégories avec design moderne
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = category == _selectedCategory &&
                                !_isInSearchMode;

                            return GestureDetector(
                              onTap: () => _filterByCategory(category),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primary.withOpacity(0.8),
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withOpacity(0.1),
                                            Colors.white.withOpacity(0.05),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchModal() {
    return AnimatedBuilder(
      animation: _modalController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.95 * _modalFade.value),
          child: Transform.translate(
            offset: Offset(
                0, MediaQuery.of(context).size.height * _modalSlide.value),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A),
                    Colors.black.withOpacity(0.98),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header de recherche modernisé
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _modalController.reverse().then((_) {
                                setState(() {
                                  _showSearchModal = false;
                                  _searchController.clear();
                                  _searchResults.clear();
                                });
                              });
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher des vidéos...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchResults.clear();
                                            });
                                          },
                                          child: Container(
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            child: Icon(
                                              Icons.clear_rounded,
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              size: 20,
                                            ),
                                          ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories populaires',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length - 1,
              itemBuilder: (context, index) {
                final category = _categories[index + 1];
                return GestureDetector(
                    onTap: () {
                      _filterByCategory(category);
                      _modalController.reverse().then((_) {
                        setState(() {
                          _showSearchModal = false;
                        });
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ));
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _isSearching
                ? 'Recherche en cours...'
                : '${_searchResults.length} résultat(s)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_isSearching)
          const Expanded(
            child: Center(
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
                    'Recherche en cours...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.white38),
                  SizedBox(height: 20),
                  Text(
                    'Aucun résultat trouvé',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Essayez d\'autres mots-clés',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectSearchResult(video),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Thumbnail modernisé avec validation d'URL
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: _isValidImageUrl(video['thumbnail'])
                        ? Image.network(
                            video['thumbnail'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.white54,
                                size: 32,
                              );
                            },
                          )
                        : const Icon(
                            Icons.play_circle_outline_rounded,
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
                          letterSpacing: 0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (video['duration'] != null) ...[
                            Icon(Icons.access_time_rounded,
                                size: 14, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              '${video['duration']}s',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (video['category'] != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                video['category'],
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Indicateur recette modernisé
                if (video['recipe_id'] != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            const Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Chargement des vidéos...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Préparation de votre contenu',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            const Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Aucune vidéo disponible',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isInSearchMode
                  ? 'Aucun résultat pour cette recherche'
                  : 'Essayez de changer de catégorie ou de revenir plus tard',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isInSearchMode ? _exitSearchMode : _loadVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _isInSearchMode
                          ? Icons.arrow_back_rounded
                          : Icons.refresh_rounded,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isInSearchMode ? 'Retour' : 'Actualiser',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            const Color(0xFF1A1A1A),
          ],
        ),
      ),
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
              'Chargement...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
