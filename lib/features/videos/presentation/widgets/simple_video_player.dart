import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/enhanced_simple_video_manager.dart';
import '../../../../core/constants/app_colors.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback? onRecipePressed;
  final VoidCallback? onLike;
  final VoidCallback? onShare;

  const SimpleVideoPlayer({
    super.key,
    required this.video,
    required this.isActive,
    this.onRecipePressed,
    this.onLike,
    this.onShare,
  });

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final EnhancedSimpleVideoManager _videoManager = EnhancedSimpleVideoManager();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLiked = false;
  bool _showPlayIcon = false;

  String? _videoId;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late AnimationController _playIconController;
  late AnimationController _likeAnimationController;
  late AnimationController _shareAnimationController;

  late Animation<double> _controlsOpacity;
  late Animation<double> _playIconScale;
  late Animation<double> _likeScale;
  late Animation<double> _shareScale;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _videoId = widget.video['id']?.toString();
    _initializeAnimations();

    // Écouter les changements d'état actif
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer les changements d'état actif
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeAndPlayVideo();
      } else {
        _pauseAndCleanup();
      }
    }
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _playIconController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _shareAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _controlsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controlsAnimationController, curve: Curves.easeOut),
    );

    _playIconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _playIconController, curve: Curves.elasticOut),
    );

    _likeScale = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
          parent: _likeAnimationController, curve: Curves.easeInOut),
    );

    _shareScale = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
          parent: _shareAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Nettoyer complètement la vidéo
    _pauseAndCleanup();

    _controlsAnimationController.dispose();
    _playIconController.dispose();
    _likeAnimationController.dispose();
    _shareAnimationController.dispose();

    super.dispose();
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

  Future<void> _initializeVideo() async {
    if (_videoId == null || widget.video['video_url'] == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'URL de vidéo manquante';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _controller = await _videoManager.initializeVideo(
        _videoId!,
        widget.video['video_url'],
      );

      if (_controller != null && mounted) {
        _controller!.addListener(_onVideoStateChanged);

        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erreur de chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeAndPlayVideo() async {
    if (!_isInitialized) {
      await _initializeVideo();
    }

    if (_videoId != null && _isInitialized) {
      final success = await _videoManager.playVideo(_videoId!);
      if (mounted && success) {
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  Future<void> _pauseAndCleanup() async {
    if (_videoId != null) {
      await _videoManager.pauseVideo(_videoId!);
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _onVideoStateChanged() {
    if (mounted && _controller != null) {
      final isPlaying = _controller!.value.isPlaying;
      if (_isPlaying != isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoId == null) return;

    HapticFeedback.lightImpact();

    if (_isPlaying) {
      _videoManager.pauseVideo(_videoId!);
      _showPlayIconAnimation();
    } else {
      _videoManager.playVideo(_videoId!);
      _showPlayIconAnimation();
    }
  }

  void _showPlayIconAnimation() {
    setState(() {
      _showPlayIcon = true;
    });

    _playIconController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _playIconController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showPlayIcon = false;
              });
            }
          });
        }
      });
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _controlsAnimationController.reverse();
    } else {
      _controlsAnimationController.forward();
    }
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _onLikePressed() {
    HapticFeedback.mediumImpact();
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });

    setState(() {
      _isLiked = !_isLiked;
    });

    widget.onLike?.call();
  }

  void _onSharePressed() {
    HapticFeedback.lightImpact();
    _shareAnimationController.forward().then((_) {
      _shareAnimationController.reverse();
    });

    widget.onShare?.call();
  }

  // Fonction pour obtenir la durée réelle de la vidéo
  String _getRealVideoDuration() {
    if (_controller != null && _controller!.value.isInitialized) {
      final duration = _controller!.value.duration;
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    // Fallback vers la durée de la base de données si la vidéo n'est pas encore initialisée
    if (widget.video['duration'] != null) {
      return _formatDuration(widget.video['duration']);
    }

    return '0:00';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Video player ou placeholder
          _buildVideoContent(),

          // Overlay tactile pour play/pause
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              onDoubleTap: _onLikePressed,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Icône de lecture/pause animée
          if (_showPlayIcon) _buildPlayIcon(),

          // Contrôles vidéo
          if (_showControls && _isInitialized) _buildVideoControls(),

          // Interface utilisateur (titre, actions)
          _buildVideoOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_isInitialized && _controller != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    return _buildThumbnailState();
  }

  Widget _buildLoadingState() {
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chargement de la vidéo...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Préparation du contenu',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
                    Colors.red.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red[400],
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur de lecture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Réessayer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

  Widget _buildThumbnailState() {
    return Stack(
      children: [
        // Image de fond avec gradient overlay et validation d'URL
        Positioned.fill(
          child: _isValidImageUrl(widget.video['thumbnail'])
              ? Stack(
                  children: [
                    Image.network(
                      widget.video['thumbnail'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2A2A2A),
                                Colors.black,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.video_library_rounded,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        );
                      },
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2A2A2A),
                        Colors.black,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.video_library_rounded,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
        ),

        // Bouton play central modernisé
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayIcon() {
    return Center(
      child: AnimatedBuilder(
        animation: _playIconScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _playIconScale.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black87,
                size: 50,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoControls() {
    return AnimatedBuilder(
      animation: _controlsOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsOpacity.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                // Header avec bouton fermer
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleControls,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
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
                        const Spacer(),
                        // Afficher la durée réelle de la vidéo
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.black.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _getRealVideoDuration(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Contrôles de lecture
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Barre de progression modernisée
                if (_controller != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        colors: VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),

          // Informations et actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Informations vidéo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titre avec style moderne
                      Text(
                        widget.video['title'] ?? 'Titre non disponible',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.3,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 8,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 12),

                      // Métadonnées
                      Row(
                        children: [
                          if (widget.video['category'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withOpacity(0.9),
                                    AppColors.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.video['category'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Afficher la durée réelle de la vidéo
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.black.withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getRealVideoDuration(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Description si disponible
                      if (widget.video['description'] != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.video['description'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Actions verticales modernisées
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton like
                    AnimatedBuilder(
                      animation: _likeScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _likeScale.value,
                          child: GestureDetector(
                            onTap: _onLikePressed,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: _isLiked
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.red,
                                          Colors.red.withOpacity(0.8),
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.2),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isLiked
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isLiked
                                        ? Colors.red.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Bouton recette si disponible
                    if (widget.onRecipePressed != null) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: widget.onRecipePressed,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';

    int seconds;
    if (duration is int) {
      seconds = duration;
    } else if (duration is String) {
      seconds = int.tryParse(duration) ?? 0;
    } else {
      return '0:00';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
