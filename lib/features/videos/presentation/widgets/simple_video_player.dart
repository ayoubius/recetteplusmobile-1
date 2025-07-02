import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../../core/services/simple_video_manager.dart';
import '../../../../core/services/video_service.dart';
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
    with AutomaticKeepAliveClientMixin {
  final SimpleVideoManager _videoManager = SimpleVideoManager();
  late String _videoId;
  
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showProgressBar = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _likesCount = 0;
  String? _errorMessage;
  
  Timer? _hideProgressTimer;
  Timer? _progressUpdateTimer;
  double _currentProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _videoId = widget.video['id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    _likesCount = widget.video['likes'] ?? 0;
    
    _checkIfLiked();
    
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeVideo();
      } else {
        _pauseVideo();
        _stopProgressUpdates();
      }
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final isLiked = await VideoService.isVideoLiked(_videoId);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      // Ignore error for like status
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    setState(() {
      _isLiking = true;
    });

    try {
      HapticFeedback.mediumImpact();
      
      if (_isLiked) {
        // Unlike
        final success = await VideoService.unlikeVideo(_videoId);
        if (success && mounted) {
          setState(() {
            _isLiked = false;
            _likesCount = (_likesCount - 1).clamp(0, double.infinity).toInt();
          });
          _showFeedback('Like retiré', Icons.heart_broken, Colors.grey);
        }
      } else {
        // Like
        final success = await VideoService.likeVideo(_videoId);
        if (success && mounted) {
          setState(() {
            _isLiked = true;
            _likesCount += 1;
          });
          _showLikeAnimation();
          _showFeedback('Vidéo likée !', Icons.favorite, Colors.red);
        }
      }
    } catch (e) {
      _showFeedback('Erreur: ${e.toString()}', Icons.error, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  void _showFeedback(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );
  }

  Future<void> _initializeVideo() async {
    if (_isInitialized || _isLoading) return;
    
    final videoUrl = widget.video['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
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
      final controller = await _videoManager.initializeVideo(_videoId, videoUrl);
      
      if (controller != null && mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _totalDuration = controller.value.duration;
        });

        controller.addListener(_onVideoPositionChanged);

        if (widget.isActive) {
          _playVideo();
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Impossible d\'initialiser la vidéo';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onVideoPositionChanged() {
    final controller = _videoManager.getController(_videoId);
    if (controller != null && mounted) {
      final position = controller.value.position;
      final duration = controller.value.duration;
      
      setState(() {
        _currentPosition = position;
        _totalDuration = duration;
        if (duration.inMilliseconds > 0) {
          _currentProgress = position.inMilliseconds / duration.inMilliseconds;
        }
      });
    }
  }

  Future<void> _playVideo() async {
    if (_isInitialized) {
      await _videoManager.playVideo(_videoId);
      _startProgressUpdates();
      setState(() {});
    }
  }

  Future<void> _pauseVideo() async {
    if (_isInitialized) {
      await _videoManager.pauseVideo(_videoId);
      _stopProgressUpdates();
      setState(() {});
    }
  }

  void _startProgressUpdates() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_videoManager.isPlaying(_videoId)) {
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
    
    if (_videoManager.isPlaying(_videoId)) {
      _pauseVideo();
    } else {
      _playVideo();
    }
    
    _showProgressBarTemporarily();
  }

  void _showProgressBarTemporarily() {
    setState(() {
      _showProgressBar = true;
    });

    _hideProgressTimer?.cancel();
    _hideProgressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showProgressBar = false;
        });
      }
    });
  }

  void _onProgressBarTap(double value) {
    final controller = _videoManager.getController(_videoId);
    if (controller != null && _totalDuration.inMilliseconds > 0) {
      final newPosition = Duration(
        milliseconds: (value * _totalDuration.inMilliseconds).round(),
      );
      controller.seekTo(newPosition);
      _showProgressBarTemporarily();
    }
  }

  void _onDoubleTap() {
    _toggleLike();
  }

  void _showLikeAnimation() {
    // Animation de coeurs qui montent
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: MediaQuery.of(context).size.width / 2 - 25,
        top: MediaQuery.of(context).size.height / 2 - 25,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            onEnd: () => overlayEntry.remove(),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * value),
                child: Opacity(
                  opacity: 1.0 - value,
                  child: Transform.scale(
                    scale: 1.0 + (value * 0.5),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 50,
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideProgressTimer?.cancel();
    _progressUpdateTimer?.cancel();
    
    final controller = _videoManager.getController(_videoId);
    controller?.removeListener(_onVideoPositionChanged);
    
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
          if (_hasError)
            _buildErrorState()
          else if (_isLoading)
            _buildLoadingState()
          else if (_isInitialized)
            _buildVideoPlayer()
          else
            _buildThumbnailState(),
          
          _buildTouchArea(),
          
          if (_showProgressBar || !_videoManager.isPlaying(_videoId))
            _buildProgressBar(),
          
          _buildUserInterface(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _videoManager.getController(_videoId);
    if (controller == null) return _buildLoadingState();

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializeVideo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailState() {
    return Stack(
      children: [
        if (widget.video['thumbnail'] != null)
          Positioned.fill(
            child: Image.network(
              widget.video['thumbnail'],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 64,
                  ),
                );
              },
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        Center(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTouchArea() {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: GestureDetector(
              onTap: _isInitialized ? _togglePlayPause : null,
              onDoubleTap: _onDoubleTap,
              child: Container(
                color: Colors.transparent,
                child: _buildPlayPauseIndicator(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseIndicator() {
    if (!_isInitialized) return const SizedBox.shrink();

    final isPlaying = _videoManager.isPlaying(_videoId);
    
    return AnimatedOpacity(
      opacity: _showProgressBar ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (!_isInitialized) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTapDown: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                final progress = (localPosition.dx - 16) / (box.size.width - 32);
                final clampedProgress = progress.clamp(0.0, 1.0);
                _onProgressBarTap(clampedProgress);
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(vertical: 15),
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_currentProgress * (MediaQuery.of(context).size.width - 32)) - 6,
                      top: 9,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
      ),
    );
  }

  Widget _buildUserInterface() {
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
                            shadows: [
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
                        const SizedBox(height: 8),
                        if (widget.video['description'] != null)
                          Text(
                            widget.video['description'].toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              shadows: [
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
                            if (widget.video['duration'] != null)
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
                                    seconds: int.tryParse(widget.video['duration'].toString()) ?? 0,
                                  )),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _likesCount.toString(),
                        onPressed: _toggleLike,
                        isHighlighted: _isLiked,
                        isLoading: _isLiking,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Partager',
                        onPressed: widget.onShare ?? () {},
                      ),
                      if (widget.onRecipePressed != null) ...[
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: Icons.restaurant_menu,
                          label: 'Recette',
                          onPressed: widget.onRecipePressed!,
                          isHighlighted: true,
                        ),
                      ],
                      const SizedBox(height: 80),
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
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? (icon == Icons.favorite ? Colors.red : AppColors.primary)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black54,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
