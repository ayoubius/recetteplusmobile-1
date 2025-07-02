import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/services/video_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/simple_video_player.dart';

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
  bool _hasMoreVideos = true;
  String? _errorMessage;
  
  int _currentVideoIndex = 0;
  int _currentPage = 0;
  static const int _videosPerPage = 10;
  
  Timer? _searchDebouncer;
  Timer? _pauseTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
    _setupSearchListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchDebouncer?.cancel();
    _pauseTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Pause automatique quand l'app passe en arrière-plan
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      _pauseCurrentVideo();
    }
  }

  void _pauseCurrentVideo() {
    // La pause sera gérée par le SimpleVideoPlayer via isActive
    setState(() {});
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        _searchDebouncer?.cancel();
        _searchDebouncer = Timer(const Duration(milliseconds: 500), () {
          _performSearch(query);
        });
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      // Charger les catégories
      final categories = await VideoService.getVideoCategories();
      
      // Charger les vidéos
      await _loadVideos(refresh: true);
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors du chargement initial: $e');
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMoreVideos = true;
      _videos.clear();
    }

    if (!_hasMoreVideos) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final videos = await VideoService.getVideos(
        limit: _videosPerPage,
        offset: _currentPage * _videosPerPage,
        category: _selectedCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _videos = videos;
          } else {
            _videos.addAll(videos);
          }
          
          _hasMoreVideos = videos.length == _videosPerPage;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors du chargement des vidéos: $e');
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
    await _loadVideos(refresh: true);
  }

  Future<void> _selectCategory(String? category) async {
    setState(() {
      _selectedCategory = category;
    });
    await _loadVideos(refresh: true);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
    });

    // Précharger plus de vidéos si nécessaire
    if (index >= _videos.length - 3 && !_isLoadingMore && _hasMoreVideos) {
      _loadVideos();
    }
  }

  Future<void> _refreshVideos() async {
    HapticFeedback.lightImpact();
    await _loadVideos(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec recherche et filtres
            _buildHeader(),
            
            // Contenu principal
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Barre de recherche
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher des vidéos...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[400],
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[400],
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filtres par catégorie
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('Toutes', null),
                const SizedBox(width: 8),
                ..._categories.map((category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(category, category),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    
    return GestureDetector(
      onTap: () => _selectCategory(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
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
              'Erreur de chargement',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInitialData,
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
              'Aucune vidéo trouvée',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos critères de recherche',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshVideos,
      color: AppColors.primary,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
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
          final isActive = index == _currentVideoIndex;

          return SimpleVideoPlayer(
            key: ValueKey(video['id']),
            video: video,
            isActive: isActive,
            onLike: () {
              // Le like est géré dans SimpleVideoPlayer
            },
            onShare: () {
              _shareVideo(video);
            },
          );
        },
      ),
    );
  }

  void _shareVideo(Map<String, dynamic> video) {
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partage de "${video['title']}" bientôt disponible !'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
