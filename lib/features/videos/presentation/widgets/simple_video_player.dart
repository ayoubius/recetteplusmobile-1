import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_service.dart';
import '../widgets/recipe_drawer.dart';

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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _likeCount = 0;
  bool _showProgressBar = false;
  double _currentProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  Timer? _hideControlsTimer;
  Timer? _progressUpdateTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut),
    );
    
    _initializeVideo();
    _loadLikeStatus();
  }

  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressUpdateTimer?.cancel();
    _controller?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.video['video_url'] as String?;
    if (videoUrl == null) return;

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });
        
        _controller!.addListener(_onVideoPositionChanged);
        
        if (widget.isActive) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de la vidéo: $e');
    }
  }

  void _onVideoPositionChanged() {
    if (_controller != null && mounted) {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      
      setState(() {
        _currentPosition = position;
        _totalDuration = duration;
        if (duration.inMilliseconds > 0) {
          _currentProgress = position.inMilliseconds / duration.inMilliseconds;
        }
      });
    }
  }

  Future<void> _loadLikeStatus() async {
    final videoId = widget.video['id']?.toString();
    if (videoId == null) return;

    try {
      final isLiked = await VideoService.isVideoLiked(videoId);
      final likeCount = widget.video['likes'] as int? ?? 0;
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likeCount = likeCount;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du statut de like: $e');
    }
  }

  void _playVideo() {
    if (_controller != null && _isInitialized && !_isPlaying) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
      _startProgressUpdates();
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
      _stopProgressUpdates();
    }
  }

  void _startProgressUpdates() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }
      _onVideoPositionChanged();
    });
  }

  void _stopProgressUpdates() {
    _progressUpdateTimer?.cancel();
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
    
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
      _showProgressBar = true;
    });
    
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
          _showProgressBar = false;
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    
    final videoId = widget.video['id']?.toString();
    if (videoId == null) return;

    setState(() {
      _isLiking = true;
    });

    try {
      HapticFeedback.mediumImpact();
      
      if (_isLiked) {
        await VideoService.unlikeVideo(videoId);
        setState(() {
          _isLiked = false;
          _likeCount = (_likeCount - 1).clamp(0, double.infinity).toInt();
        });
      } else {
        await VideoService.likeVideo(videoId);
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
        
        _likeAnimationController.forward().then((_) {
          _likeAnimationController.reverse();
        });
        _showLikeAnimation();
      }
    } catch (e) {
      debugPrint('Erreur lors du toggle like: $e');
    } finally {
      setState(() {
        _isLiking = false;
      });
    }
  }

  void _showLikeAnimation() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: MediaQuery.of(context).size.width / 2 - 30,
        top: MediaQuery.of(context).size.height / 2 - 30,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween(begin: 0.0, end: 1.0),
            onEnd: () => overlayEntry.remove(),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -80 * value),
                child: Opacity(
                  opacity: 1.0 - value,
                  child: Transform.scale(
                    scale: 1.0 + (value * 0.8),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
  }

  void _openRecipeDrawer() {
    final recipeId = widget.video['recipe_id']?.toString();
    if (recipeId == null) return;

    HapticFeedback.mediumImpact();
    _pauseVideo();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecipeDrawer(
        recipeId: recipeId,
        onClose: () => Navigator.of(context).pop(),
        onCartUpdated: () {},
      ),
    );
  }

  void _onProgressBarTap(double value) {
    if (_controller != null && _totalDuration.inMilliseconds > 0) {
      final newPosition = Duration(
        milliseconds: (value * _totalDuration.inMilliseconds).round(),
      );
      _controller!.seekTo(newPosition);
      _showControlsTemporarily();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
          // Vidéo en plein écran
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            _buildLoadingPlaceholder(),

          // Zone tactile pour play/pause
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              onDoubleTap: _toggleLike,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // Contrôles centrés
          if (_showControls || !_isPlaying)
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ),

          // Barre de progression
          if (_showProgressBar && _isInitialized)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: _buildProgressBar(),
            ),

          // Actions à droite avec design amélioré
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                _buildEnhancedActionButton(
                  icon: AnimatedBuilder(
                    animation: _likeAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _likeAnimation.value,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  label: _formatCount(_likeCount),
                  onTap: _toggleLike,
                  isHighlighted: _isLiked,
                  isLoading: _isLiking,
                ),

                const SizedBox(height: 24),

                if (widget.video['recipe_id'] != null)
                  _buildEnhancedActionButton(
                    icon: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 32,
                    ),
                    label: 'Recette',
                    onTap: _openRecipeDrawer,
                    isHighlighted: true,
                    backgroundColor: AppColors.primary,
                  ),

                const SizedBox(height: 24),

                _buildEnhancedActionButton(
                  icon: const Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: 'Partager',
                  onTap: widget.onShare,
                ),

                const SizedBox(height: 24),

                _buildEnhancedActionButton(
                  icon: const Icon(
                    Icons.comment,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: '${widget.video['comments'] ?? 0}',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Informations vidéo avec design amélioré
          Positioned(
            left: 16,
            bottom: 100,
            right: 100,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.video['title'] ?? 'Vidéo sans titre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (widget.video['description'] != null)
                    Text(
                      widget.video['description'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
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
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.video['duration'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white70,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.video['duration']}s',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[900],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final progress = (localPosition.dx - 32) / (box.size.width - 64);
              final clampedProgress = progress.clamp(0.0, 1.0);
              _onProgressBarTap(clampedProgress);
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: _currentProgress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (_currentProgress * (MediaQuery.of(context).size.width - 64)) - 8,
                    top: 14,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButton({
    required Widget icon,
    required String label,
    VoidCallback? onTap,
    bool isHighlighted = false,
    bool isLoading = false,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: backgroundColor != null
              ? LinearGradient(
                  colors: [
                    backgroundColor,
                    backgroundColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighlighted 
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (isHighlighted)
              BoxShadow(
                color: (backgroundColor ?? AppColors.primary).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
