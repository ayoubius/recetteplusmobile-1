import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import 'dart:async';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback? onRecipePressed;
  final ValueNotifier<bool>? pauseNotifier;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    required this.isActive,
    this.pauseNotifier,
    this.onRecipePressed,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = false;
  bool _isPlaying = false;
  bool _isPreloaded = false;
  bool _isBuffering = false;

  // Animation pour les contrôles
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  // Timer pour masquer les contrôles
  Timer? _hideControlsTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    widget.pauseNotifier?.addListener(_onPauseNotifierChanged);
    
    // Initialiser la vidéo si elle est active
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer l'initialisation basée sur isActive
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive && !_isInitialized && !_hasError) {
        _initializeVideo();
      } else if (!widget.isActive) {
        _pause();
      }
    }
  }

  void _onPauseNotifierChanged() {
    if (widget.pauseNotifier?.value == true) {
      _pause();
    } else if (widget.isActive && _isInitialized) {
      _play();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitialized || _hasError) return;

    try {
      final videoUrl = widget.video['video_url'];
      if (videoUrl == null || videoUrl.isEmpty) {
        setState(() {
          _hasError = true;
        });
        return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // Écouter les changements d'état avant l'initialisation
      _controller!.addListener(_onVideoStateChanged);

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPreloaded = true;
        });

        // Configuration du player
        _controller!.setLooping(true);
        _controller!.setVolume(1.0);

        // Démarrer la lecture si cette vidéo est active
        if (widget.isActive) {
          _play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  // Méthode publique pour précharger la vidéo
  void preloadVideo() {
    if (!_isPreloaded && !_hasError) {
      _initializeVideo();
    }
  }

  void _onVideoStateChanged() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;
    final isPlaying = value.isPlaying;
    final isBuffering = value.isBuffering;

    if (_isPlaying != isPlaying || _isBuffering != isBuffering) {
      setState(() {
        _isPlaying = isPlaying;
        _isBuffering = isBuffering;
      });
    }

    // Gérer les erreurs de lecture
    if (value.hasError) {
      setState(() {
        _hasError = true;
      });
    }
  }

  // Méthodes publiques pour contrôler la lecture
  void play() {
    if (_controller != null && _isInitialized && !_hasError) {
      _controller!.play();
    } else if (!_isInitialized && !_hasError) {
      // Initialiser et jouer
      _initializeVideo().then((_) {
        if (_controller != null && _isInitialized) {
          _controller!.play();
        }
      });
    }
  }

  void pause() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
    }
  }

  void _play() => play();
  void _pause() => pause();

  void _togglePlayPause() {
    HapticFeedback.lightImpact();

    if (_controller == null || !_isInitialized) {
      if (!_hasError) {
        _initializeVideo();
      }
      return;
    }

    if (_controller!.value.isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    
    _controlsAnimationController.forward();
    
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controlsAnimationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  void _onTap() {
    _togglePlayPause();
    _showControlsTemporarily();
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    // Animation de like (sans fonctionnalité backend pour l'instant)
    _showLikeAnimation();
  }

  void _showLikeAnimation() {
    // TODO: Implémenter l'animation de like
  }

  void _seekTo(Duration position) {
    if (_controller != null && _isInitialized) {
      _controller!.seekTo(position);
    }
  }

  void _seekRelative(Duration offset) {
    if (_controller == null || !_isInitialized) return;
    
    final currentPosition = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = currentPosition + offset;
    
    if (newPosition < Duration.zero) {
      _seekTo(Duration.zero);
    } else if (newPosition > duration) {
      _seekTo(duration);
    } else {
      _seekTo(newPosition);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    widget.pauseNotifier?.removeListener(_onPauseNotifierChanged);
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
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
          _buildVideoPlayer(),
          _buildOverlay(),
          if (_showControls) _buildPlaybackControls(),
          if (_isBuffering) _buildBufferingIndicator(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
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
              'Erreur de lecture',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                  _isPreloaded = false;
                });
                _initializeVideo();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.video['title'] ?? 'Vidéo sans titre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (widget.video['description'] != null &&
                            widget.video['description'].isNotEmpty)
                          Text(
                            widget.video['description'],
                            style: TextStyle(
                              color: Colors.grey[300],
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
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.video['category'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (_controller != null && _isInitialized) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDuration(_controller!.value.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        label: '${widget.video['likes'] ?? 0}',
                        onPressed: _onDoubleTap,
                      ),
                      const SizedBox(height: 16),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Partager',
                        onPressed: () {
                          // TODO: Partager la vidéo
                        },
                      ),
                      const SizedBox(height: 16),
                      if (widget.onRecipePressed != null)
                        _buildActionButton(
                          icon: Icons.restaurant_menu,
                          label: 'Recette',
                          onPressed: widget.onRecipePressed!,
                          isHighlighted: true,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primary
                  : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    if (_controller == null || !_isInitialized) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _seekRelative(const Duration(seconds: -10));
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: () {
                      _seekRelative(const Duration(seconds: 10));
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
