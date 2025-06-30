import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';

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
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = false;
  bool _isPlaying = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    widget.pauseNotifier?.addListener(_onPauseNotifierChanged);
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer la lecture/pause basée sur isActive
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _play();
      } else {
        _pause();
      }
    }
  }

  void _onPauseNotifierChanged() {
    if (widget.pauseNotifier?.value == true) {
      _pause();
    } else if (widget.isActive) {
      _play();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final videoUrl = widget.video['video_url'];
      if (videoUrl == null || videoUrl.isEmpty) {
        setState(() {
          _hasError = true;
        });
        return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Configuration du player
        _controller!.setLooping(true);

        // Démarrer la lecture si cette vidéo est active
        if (widget.isActive) {
          _play();
        }

        // Écouter les changements d'état
        _controller!.addListener(_onVideoStateChanged);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final isPlaying = _controller?.value.isPlaying ?? false;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  void _play() {
    if (_controller != null && _isInitialized && !_hasError) {
      _controller!.play();
    }
  }

  void _pause() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();

    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _onTap() {
    _togglePlayPause();

    // Afficher les contrôles temporairement
    setState(() {
      _showControls = true;
    });

    // Masquer les contrôles après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    // TODO: Implémenter like/unlike
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
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
          // Lecteur vidéo
          _buildVideoPlayer(),

          // Overlay avec informations et contrôles
          _buildOverlay(),

          // Contrôles de lecture (temporaires)
          if (_showControls) _buildPlaybackControls(),
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
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

  Widget _buildOverlay() {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),

              // Informations de la vidéo et actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Informations de la vidéo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Titre
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

                        // Description
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

                        // Métadonnées
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

                  // Actions verticales
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bouton like
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        label: '${widget.video['likes'] ?? 0}',
                        onPressed: _onDoubleTap,
                      ),

                      const SizedBox(height: 16),

                      // Bouton commentaire
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: '${widget.video['comments'] ?? 0}',
                        onPressed: () {
                          // TODO: Ouvrir les commentaires
                        },
                      ),

                      const SizedBox(height: 16),

                      // Bouton partage
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Partager',
                        onPressed: () {
                          // TODO: Partager la vidéo
                        },
                      ),

                      const SizedBox(height: 16),

                      // Bouton recette (si disponible)
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

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton reculer
              IconButton(
                onPressed: () {
                  final position = _controller!.value.position;
                  final newPosition = position - const Duration(seconds: 10);
                  _controller!.seekTo(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(width: 32),

              // Bouton play/pause
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(width: 32),

              // Bouton avancer
              IconButton(
                onPressed: () {
                  final position = _controller!.value.position;
                  final duration = _controller!.value.duration;
                  final newPosition = position + const Duration(seconds: 10);
                  _controller!.seekTo(
                    newPosition > duration ? duration : newPosition,
                  );
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
  }
}
