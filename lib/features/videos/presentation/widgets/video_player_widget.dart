import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/video_state_manager.dart';
import '../../../../core/constants/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback? onTap;
  final bool autoPlay;
  final bool showControls;
  final bool isActive;
  final ValueNotifier<bool>? pauseNotifier;
  final VoidCallback? onRecipePressed;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.onTap,
    this.autoPlay = false,
    this.showControls = true,
    this.isActive = false,
    this.pauseNotifier,
    this.onRecipePressed,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  final VideoStateManager _stateManager = VideoStateManager();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLoading = false;
  String? _error;

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

    _initializeVideo();
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (widget.video['video_url'] == null) {
      setState(() {
        _error = 'URL de vidéo manquante';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videoId = widget.video['id']?.toString() ?? '';
      final videoUrl = widget.video['video_url']?.toString() ?? '';

      _controller = await _stateManager.initializeController(videoId, videoUrl);

      _controller!.addListener(_onVideoStateChanged);

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      if (widget.autoPlay) {
        await play();
      }

      _controlsAnimationController.forward();
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _onVideoStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = _controller?.value.isPlaying ?? false;
      });
    }
  }

  Future<void> play() async {
    if (_controller != null && _isInitialized) {
      await _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> pause() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> preloadVideo() async {
    if (!_isInitialized) {
      await _initializeVideo();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Lecteur vidéo ou placeholder
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_isLoading)
              _buildLoadingState()
            else if (_error != null)
              _buildErrorState()
            else
              _buildThumbnailState(),

            // Overlay tactile
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (widget.onTap != null) {
                    widget.onTap!();
                  } else {
                    _toggleControls();
                  }
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

            // Contrôles vidéo
            if (widget.showControls && _isInitialized)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _controlsAnimation.value,
                    child: _buildControls(),
                  );
                },
              ),

            // Informations vidéo
            _buildVideoInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement de la vidéo...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black54,
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
            Text(
              _error ?? 'Erreur de chargement',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeVideo,
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
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 48,
                  ),
                );
              },
            ),
          )
        else
          Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(
                Icons.video_library,
                color: Colors.white,
                size: 48,
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
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),

        // Bouton play
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (!_showControls) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            // Contrôles principaux
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barre de progression
            if (_controller != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video['title'] ?? 'Titre non disponible',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.video['duration'] != null)
                  Text(
                    _formatDuration(_parseDuration(widget.video['duration'])),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _parseDuration(dynamic duration) {
    if (duration == null) return 0;
    if (duration is int) return duration;
    if (duration is String) return int.tryParse(duration) ?? 0;
    return 0;
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
