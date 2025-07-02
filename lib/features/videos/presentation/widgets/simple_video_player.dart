import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _likeCount = 0;
  bool _showRecipeDrawer = false;

  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
        });
        
        if (widget.isActive) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de la vidéo: $e');
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
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
    
    // Afficher les contrôles temporairement
    setState(() {
      _showControls = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showControls = false;
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
        
        // Animation de like
        _likeAnimationController.forward().then((_) {
          _likeAnimationController.reverse();
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du toggle like: $e');
    } finally {
      setState(() {
        _isLiking = false;
      });
    }
  }

  void _openRecipeDrawer() {
    final recipeId = widget.video['recipe_id']?.toString();
    if (recipeId == null) return;

    HapticFeedback.mediumImpact();
    _pauseVideo();
    
    setState(() {
      _showRecipeDrawer = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecipeDrawer(
        recipeId: recipeId,
        onClose: () {
          Navigator.of(context).pop();
          setState(() {
            _showRecipeDrawer = false;
          });
        },
        onCartUpdated: () {
          // Callback pour mise à jour du panier
        },
      ),
    );
  }

  void _onProgressChanged(double value) {
    if (_controller != null && _isInitialized) {
      final duration = _controller!.value.duration;
      final position = duration * value;
      _controller!.seekTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Vidéo
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildLoadingPlaceholder(),

          // Zone tactile pour play/pause (70% de l'écran)
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // Contrôles centrés
          if (_showControls || !_isPlaying)
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

          // Barre de progression
          if (_isInitialized && _controller != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: _buildProgressBar(),
            ),

          // Actions à droite
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // Bouton like
                _buildActionButton(
                  icon: AnimatedBuilder(
                    animation: _likeAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _likeAnimation.value,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white,
                          size: 28,
                        ),
                      );
                    },
                  ),
                  label: _formatCount(_likeCount),
                  onTap: _toggleLike,
                ),

                const SizedBox(height: 20),

                // Bouton recette
                if (widget.video['recipe_id'] != null)
                  _buildActionButton(
                    icon: const Icon(
                      Icons.restaurant_menu,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    label: 'Recette',
                    onTap: _openRecipeDrawer,
                  ),

                const SizedBox(height: 20),

                // Bouton partage
                _buildActionButton(
                  icon: const Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: 'Partager',
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),

          // Informations vidéo
          Positioned(
            left: 16,
            bottom: 120,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video['title'] ?? 'Vidéo sans titre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (widget.video['description'] != null)
                  Text(
                    widget.video['description'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.video['category'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.video['category'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.video['duration'] != null)
                      Text(
                        '${widget.video['duration']}s',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
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
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller!,
      builder: (context, value, child) {
        final progress = value.duration.inMilliseconds > 0
            ? value.position.inMilliseconds / value.duration.inMilliseconds
            : 0.0;

        return GestureDetector(
          onTapDown: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final progress = localPosition.dx / box.size.width;
            _onProgressChanged(progress.clamp(0.0, 1.0));
          },
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
