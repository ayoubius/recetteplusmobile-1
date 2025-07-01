import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_service.dart';
import 'dart:async';
import 'package:recette_plus/core/utils/image_utils.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final ValueNotifier<bool> pauseNotifier;
  final VoidCallback? onRecipePressed;
  final VoidCallback? onLikePressed;
  final VoidCallback? onUnlikePressed;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    required this.isActive,
    required this.pauseNotifier,
    this.onRecipePressed,
    this.onLikePressed,
    this.onUnlikePressed,
  }) : super(key: key);

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _showControls = true;
  Timer? _controlsTimer;

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

    widget.pauseNotifier.addListener(_pauseListener);
    
    // Initialiser la vidéo si elle est active
    if (widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video['video_url'] != widget.video['video_url']) {
      _disposeVideo();
      _initializeVideo();
    }
    if (oldWidget.isActive != widget.isActive) {
      _managePlayback();
    }
  }

  @override
  void dispose() {
    widget.pauseNotifier.removeListener(_pauseListener);
    _disposeVideo();
    _controlsAnimationController.dispose();
    super.dispose();
  }

  void _pauseListener() {
    if (widget.pauseNotifier.value) {
      _pauseVideo();
    } else {
      _managePlayback();
    }
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.video['video_url'];
    if (videoUrl == null) {
      print('URL vidéo manquante pour ${widget.video['title']}');
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.setLooping(true);
      _managePlayback();
      _controller.addListener(_videoListener);
    } catch (e) {
      print('Erreur lors de l\'initialisation de la vidéo: $e');
    }
  }

  void _disposeVideo() {
    _controller?.removeListener(_videoListener);
    if (_isInitialized) {
      _controller?.dispose();
    }
    _isInitialized = false;
  }

  void _videoListener() {
    if (!_controller!.value.isPlaying &&
        _controller!.value.isInitialized &&
        !_controller!.value.hasError &&
        !widget.pauseNotifier.value &&
        widget.isActive) {
      // La vidéo s'est terminée, revenir au début
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }

    if (_isBuffering != _controller!.value.isBuffering) {
      setState(() {
        _isBuffering = _controller!.value.isBuffering;
      });
    }
  }

  void _managePlayback() {
    if (widget.isActive && !widget.pauseNotifier.value) {
      play();
    } else {
      pause();
    }
  }

  void play() {
    if (_controller != null && _isInitialized && !_controller!.value.isPlaying) {
      _controller!.play();
      _startShowControlsTimer();
    }
  }

  void pause() {
    if (_controller != null && _isInitialized && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  void preloadVideo() {
    if (_controller != null && _isInitialized) {
      _controller!.setVolume(0.0);
      _controller!.play().then((_) {
        _controller!.pause();
        _controller!.setVolume(1.0);
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isInitialized && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startShowControlsTimer();
    } else {
      _cancelShowControlsTimer();
    }
  }

  void _startShowControlsTimer() {
    _cancelShowControlsTimer();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _showControls = false;
      });
    });
  }

  void _cancelShowControlsTimer() {
    _controlsTimer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControlsVisibility,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Video Player
          if (_isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.video['title'] ?? 'Chargement de la vidéo...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Buffering Indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),

          // Controls Overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black45,
                    Colors.black87,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Section
                    Row(
                      children: [
                        // Titre de la vidéo
                        Expanded(
                          child: Text(
                            widget.video['title'] ?? 'Vidéo sans titre',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Bouton Recette
                        if (widget.onRecipePressed != null)
                          IconButton(
                            icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                            onPressed: widget.onRecipePressed,
                            tooltip: 'Voir la recette',
                          ),
                      ],
                    ),

                    // Bottom Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Duration and Progress
                        Text(
                          _isInitialized
                              ? '${_formatDuration(_controller!.value.position.inSeconds)} / ${_formatDuration(_controller!.value.duration.inSeconds)}'
                              : 'Chargement...',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        // Like Button
                        /*IconButton(
                          icon: const Icon(Icons.thumb_up, color: Colors.white),
                          onPressed: () {
                            // TODO: Implement Like functionality
                          },
                        ),*/
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
