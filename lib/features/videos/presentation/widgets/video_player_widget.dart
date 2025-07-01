import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/video_state_manager.dart';
import '../../../../core/constants/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final ValueNotifier<bool> pauseNotifier;
  final VoidCallback? onRecipePressed;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.isActive,
    required this.pauseNotifier,
    this.onRecipePressed,
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
    
    widget.pauseNotifier.addListener(_onPauseNotifierChanged);
    
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    widget.pauseNotifier.removeListener(_onPauseNotifierChanged);
    _controlsAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeVideo();
      } else {
        pause();
      }
    }
  }

  void _onPauseNotifierChanged() {
    if (widget.pauseNotifier.value) {
      pause();
    } else if (widget.isActive) {
      play();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || widget.video['video_url'] == null) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      final videoId = widget.video['id'].toString();
      final videoUrl = widget.video['video_url'].toString();
      
      _controller = _stateManager.getController(videoId, videoUrl);
      
      if (_controller != null) {
        await _stateManager.initializeController(videoId);
        await _controller!.setLooping(true);
        
        _controller!.addListener(() {
          if (mounted) {
            setState(() {});
          }
        });

        if (widget.isActive && !widget.pauseNotifier.value) {
          await play();
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

  Future<void> play() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final videoId = widget.video['id'].toString();
      await _stateManager.pauseAllExcept(videoId);
      await _stateManager.play(videoId);
    } catch (e) {
      debugPrint('❌ Erreur lors de la lecture: $e');
    }
  }

  Future<void> pause() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final videoId = widget.video['id'].toString();
      await _stateManager.pause(videoId);
    } catch (e) {
      debugPrint('❌ Erreur lors de la pause: $e');
    }
  }

  void preloadVideo() {
    if (!_isInitializing) {
      _initializeVideo();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isPlaying) {
      await pause();
    } else {
      await play();
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
        image: widget.video['thumbnail'] != null
            ? DecorationImage(
                image: NetworkImage(widget.video['thumbnail']),
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
    if (_controller == null || !_controller!.value.isInitialized) {
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
                      if (widget.onRecipePressed != null)
                        IconButton(
                          onPressed: widget.onRecipePressed,
                          icon: const Icon(
                            Icons.restaurant_menu,
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
                      
                      // Temps et informations
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
                              Icon(
                                Icons.favorite_border,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.video['likes'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.video['views'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
        _toggleControls();
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
              widget.video['thumbnail'] != null
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
