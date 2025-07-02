import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../../core/services/simple_video_manager.dart';
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

        // Écouter les changements de position
        controller.addListener(_onVideoPositionChanged);

        // Démarrer la lecture si la vidéo est active
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
    HapticFeedback.mediumImpact();
    widget.onLike?.call();
    _showLikeAnimation();
  }

  void _showLikeAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Vidéo likée !'),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );
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
    
    // Retirer le listener du contrôleur
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
          // Lecteur vidéo ou états
          if (_hasError)
            _buildErrorState()
          else if (_isLoading)
            _buildLoadingState()
          else if (_isInitialized)
            _buildVideoPlayer()
          else
            _buildThumbnailState(),
          
          // Zone tactile pour play/pause (exclut les boutons d'action)
          _buildTouchArea(),
          
          // Barre de progression
          if (_showProgressBar || !_videoManager.isPlaying(_videoId))
            _buildProgressBar(),
          
          // Interface utilisateur (boutons d'action)
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
        // Image de fond
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

        // Overlay sombre
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

        // Bouton play central
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
          // Zone gauche (70% de l'écran) - pour play/pause
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
          // Zone droite (30% de l'écran) - réservée aux boutons d'action
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 30,
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
            // Barre de progression interactive
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
                    // Barre de fond
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Barre de progression
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
                    // Indicateur de position
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
            // Temps
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
                  // Informations vidéo
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
                        // Tags
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
                        // Espace pour la barre de progression
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Actions (zone protégée des taps)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        label: '${widget.video['likes'] ?? 0}',
                        onPressed: widget.onLike ?? () {},
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
                      const SizedBox(height: 80), // Espace pour la barre de progression
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
      onTap: () {
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
                  ? AppColors.primary
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
            child: Icon(
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
