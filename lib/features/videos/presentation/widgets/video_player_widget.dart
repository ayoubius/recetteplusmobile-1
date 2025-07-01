import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/video_state_manager.dart';
import '../../../../core/constants/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;

  const VideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.onTap,
    this.onPlay,
    this.onPause,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  final VideoStateManager _stateManager = VideoStateManager();
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isInitializing = false;
  
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

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

    _controlsAnimationController.forward();
    
    _initializeVideo();
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      _controller = _stateManager.getController(widget.videoId, widget.videoUrl);
      
      if (_controller != null) {
        await _controller!.initialize();
        await _controller!.setLooping(true);
        
        _controller!.addListener(() {
          if (mounted) {
            setState(() {});
          }
        });

        if (widget.autoPlay) {
          await _stateManager.play(widget.videoId);
          widget.onPlay?.call();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation de la vidéo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isPlaying) {
      await _stateManager.pause(widget.videoId);
      widget.onPause?.call();
    } else {
      await _stateManager.pauseAllExcept(widget.videoId);
      await _stateManager.play(widget.videoId);
      widget.onPlay?.call();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _controlsAnimationController.forward();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  Widget _buildThumbnail() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        image: widget.thumbnailUrl != null
            ? DecorationImage(
                image: NetworkImage(widget.thumbnailUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erreur de lecture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _initializeVideo(),
              child: const Text(
                'Réessayer',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!widget.showControls || _controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Contrôles du haut
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Action pour plus d'options
                        },
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bouton play/pause central
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                
                // Contrôles du bas
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Barre de progression
                      VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Temps et contrôles
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_controller!.value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  // Action pour le volume
                                },
                                icon: const Icon(
                                  Icons.volume_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  // Action pour le plein écran
                                },
                                icon: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatDuration(_controller!.value.duration),
                            style: const TextStyle(
                              color: Colors.white,
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
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        if (widget.showControls) {
          _toggleControls();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Contenu vidéo
            if (_isInitializing)
              _buildLoadingIndicator()
            else if (_controller == null || !_controller!.value.isInitialized)
              widget.thumbnailUrl != null
                  ? _buildThumbnail()
                  : _buildLoadingIndicator()
            else if (_controller!.value.hasError)
              _buildErrorWidget()
            else
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            
            // Indicateur de buffering
            if (_controller != null && 
                _controller!.value.isInitialized && 
                _controller!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            
            // Contrôles
            if (_showControls) _buildControls(),
          ],
        ),
      ),
    );
  }
}
