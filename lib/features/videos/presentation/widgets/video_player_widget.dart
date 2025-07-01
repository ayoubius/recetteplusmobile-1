import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_state_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final ValueNotifier<bool> pauseNotifier;
  final VoidCallback? onRecipePressed;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    required this.isActive,
    required this.pauseNotifier,
    this.onRecipePressed,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String? _errorMessage;

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

    widget.pauseNotifier.addListener(_onPauseNotifierChanged);
    
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    widget.pauseNotifier.removeListener(_onPauseNotifierChanged);
    _controlsAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeVideo();
      } else {
        _pause();
      }
    }
  }

  void _onPauseNotifierChanged() {
    if (widget.pauseNotifier.value) {
      _pause();
    } else if (widget.isActive) {
      _play();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitialized || widget.video['video_url'] == null) return;

    try {
      setState(() {
        _isBuffering = true;
        _hasError = false;
      });

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video['video_url']),
      );

      if (_controller != null) {
        await _controller!.initialize();
        await _controller!.setLooping(true);
        
        _controller!.addListener(_onVideoStateChanged);

        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });

        if (widget.isActive && !widget.pauseNotifier.value) {
          _play();
        }
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isBuffering = false;
      });
      print('Erreur d\'initialisation vidéo: $e');
    }
  }

  void _onVideoStateChanged() {
    if (_controller == null || !mounted) return;

    final value = _controller!.value;
    setState(() {
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering;
      _hasError = value.hasError;
      _errorMessage = value.hasError ? value.errorDescription : null;
    });
  }

  Future<void> _play() async {
    if (_controller != null && _isInitialized && !_hasError) {
      await _controller!.play();
    }
  }

  Future<void> _pause() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pause();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
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
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controlsAnimationController.reverse();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  void preloadVideo() {
    if (!_isInitialized) {
      _initializeVideo();
    }
  }

  void play() {
    _play();
  }

  void pause() {
    _pause();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Lecteur vidéo
          if (_isInitialized && !_hasError)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

          // État de chargement
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),

          // État d'erreur
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Erreur de lecture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Impossible de lire la vidéo',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),

          // Zone tactile pour afficher les contrôles
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_isInitialized && !_hasError) {
                  _showControlsTemporarily();
                }
              },
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                if (_isInitialized && !_hasError) {
                  _togglePlayPause();
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // Contrôles vidéo
          if (_showControls && _isInitialized && !_hasError)
            AnimatedBuilder(
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
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Informations de la vidéo
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
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
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (widget.video['description'] != null)
                    Text(
                      widget.video['description'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: Colors.white,
                        size: 20,
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
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.video['views'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (widget.onRecipePressed != null)
                        GestureDetector(
                          onTap: widget.onRecipePressed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Recette',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
}
