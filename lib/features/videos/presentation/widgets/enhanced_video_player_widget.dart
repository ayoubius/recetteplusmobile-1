import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_state_manager.dart';

class EnhancedVideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback? onRecipePressed;
  final VoidCallback? onVideoError;
  final bool autoPlay;
  final bool showControls;
  final bool enableGestures;

  const EnhancedVideoPlayerWidget({
    Key? key,
    required this.video,
    required this.isActive,
    this.onRecipePressed,
    this.onVideoError,
    this.autoPlay = true,
    this.showControls = true,
    this.enableGestures = true,
  }) : super(key: key);

  @override
  State<EnhancedVideoPlayerWidget> createState() =>
      _EnhancedVideoPlayerWidgetState();
}

class _EnhancedVideoPlayerWidgetState extends State<EnhancedVideoPlayerWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final VideoStateManager _stateManager = VideoStateManager();
  late String _videoId;

  // Animation pour les contrôles
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _errorAnimationController;
  late Animation<double> _errorAnimation;

  // Timer pour masquer les contrôles
  Timer? _hideControlsTimer;
  Timer? _retryTimer;

  // État local
  bool _showControls = false;
  bool _isInitializing = false;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _videoId = widget.video['id']?.toString() ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';

    _setupAnimations();
    _setupStateManager();

    if (widget.isActive && widget.autoPlay) {
      _initializeVideo();
    }
  }

  void _setupAnimations() {
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

    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _errorAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _setupStateManager() {
    _stateManager.addListener(_onStateManagerChanged);
  }

  @override
  void didUpdateWidget(EnhancedVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer l'initialisation basée sur isActive
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive && !_isInitializing && !_hasError) {
        _initializeVideo();
      } else if (!widget.isActive) {
        _pauseVideo();
      }
    }
  }

  void _onStateManagerChanged() {
    if (!mounted) return;

    final videoInfo = _stateManager.getVideoInfo(_videoId);
    if (videoInfo != null) {
      setState(() {
        _hasError = videoInfo.state == VideoState.error;
        _errorMessage = videoInfo.errorMessage;
        _isInitializing = videoInfo.state == VideoState.loading;
      });

      // Gérer les erreurs
      if (_hasError && _retryCount < _maxRetries) {
        _scheduleRetry();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _hasError) return;

    final videoUrl = widget.video['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'URL de la vidéo manquante';
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final controller = await _stateManager.initializeVideo(
        videoId: _videoId,
        videoUrl: videoUrl,
        title: widget.video['title']?.toString(),
        quality: _parseQuality(widget.video['quality']),
      );

      if (controller != null && widget.isActive && widget.autoPlay) {
        await _stateManager.playVideo(_videoId);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur d\'initialisation: ${e.toString()}';
        _isInitializing = false;
      });

      widget.onVideoError?.call();
    }
  }

  VideoQuality _parseQuality(dynamic quality) {
    if (quality == null) return VideoQuality.auto;

    final qualityStr = quality.toString().toLowerCase();
    switch (qualityStr) {
      case 'low':
        return VideoQuality.low;
      case 'medium':
        return VideoQuality.medium;
      case 'high':
        return VideoQuality.high;
      default:
        return VideoQuality.auto;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: (_retryCount + 1) * 2), () {
      if (mounted && _hasError) {
        _retryCount++;
        _initializeVideo();
      }
    });
  }

  Future<void> _playVideo() async {
    if (widget.isActive) {
      await _stateManager.playVideo(_videoId);
    }
  }

  Future<void> _pauseVideo() async {
    await _stateManager.pauseVideo(_videoId);
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();

    final videoInfo = _stateManager.getVideoInfo(_videoId);
    if (videoInfo == null) {
      if (!_hasError) {
        _initializeVideo();
      }
      return;
    }

    if (videoInfo.state == VideoState.playing) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _showControlsTemporarily() {
    if (!widget.showControls) return;

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
    if (_hasError) {
      _retryInitialization();
      return;
    }

    _togglePlayPause();
    _showControlsTemporarily();
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    _showLikeAnimation();
  }

  void _showLikeAnimation() {
    // Animation de like
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('❤️ Vidéo likée !'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _isInitializing = false;
      _errorMessage = null;
      _retryCount = 0;
    });

    _retryTimer?.cancel();
    _initializeVideo();
  }

  void _seekTo(Duration position) {
    _stateManager.seekTo(_videoId, position);
  }

  void _seekRelative(Duration offset) {
    final controller = _stateManager.getController(_videoId);
    if (controller == null) return;

    final currentPosition = controller.value.position;
    final duration = controller.value.duration;
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
    _retryTimer?.cancel();
    _controlsAnimationController.dispose();
    _errorAnimationController.dispose();
    _stateManager.removeListener(_onStateManagerChanged);
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
          if (_showControls && !_hasError) _buildPlaybackControls(),
          if (_isInitializing && !_hasError) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_isInitializing) {
      return _buildLoadingWidget();
    }

    final controller = _stateManager.getController(_videoId);
    if (controller == null) {
      return _buildLoadingWidget();
    }

    return GestureDetector(
      onTap: widget.enableGestures ? _onTap : null,
      onDoubleTap: widget.enableGestures ? _onDoubleTap : null,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AnimatedBuilder(
      animation: _errorAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_errorAnimation.value * 0.2),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                  ElevatedButton.icon(
                    onPressed: _retryInitialization,
                    icon: const Icon(Icons.refresh),
                    label: Text('Réessayer (${_retryCount + 1}/$_maxRetries)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tapez pour réessayer',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
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

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de la vidéo...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.video['title'] ?? 'Vidéo',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
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
                            widget.video['description'].toString().isNotEmpty)
                          Text(
                            widget.video['description'].toString(),
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
                                  widget.video['category'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (widget.video['duration'] != null) ...[
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
                                  _formatDuration(Duration(
                                      seconds: widget.video['duration'])),
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
    final controller = _stateManager.getController(_videoId);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final videoInfo = _stateManager.getVideoInfo(_videoId);
    final isPlaying = videoInfo?.state == VideoState.playing;

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
                      isPlaying ? Icons.pause : Icons.play_arrow,
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
