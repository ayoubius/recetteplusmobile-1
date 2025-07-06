import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';

class EnhancedVideoPlayer extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final bool autoPlay;
  final Function(bool)? onPlayStateChanged;
  final Function()? onDoubleTap;
  final Function()? onLike;
  final bool isLiked;
  final int likesCount;

  const EnhancedVideoPlayer({
    super.key,
    required this.videoId,
    required this.videoUrl,
    this.autoPlay = false,
    this.onPlayStateChanged,
    this.onDoubleTap,
    this.onLike,
    this.isLiked = false,
    this.likesCount = 0,
  });

  @override
  State<EnhancedVideoPlayer> createState() => _EnhancedVideoPlayerState();
}

class _EnhancedVideoPlayerState extends State<EnhancedVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isBuffering = false;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;

  // Animation controllers
  late AnimationController _playPauseAnimationController;
  late AnimationController _likeAnimationController;
  late AnimationController _doubleTapAnimationController;

  // Animations
  late Animation<double> _playPauseAnimation;
  late Animation<double> _likeAnimation;
  late Animation<double> _doubleTapAnimation;
  late Animation<Offset> _likeSlideAnimation;

  // Progress tracking
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _bufferProgress = 0.0;

  // Gesture detection
  bool _isDoubleTapInProgress = false;
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeVideo();
  }

  void _setupAnimations() {
    _playPauseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _playPauseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playPauseAnimationController,
      curve: Curves.easeInOut,
    ));

    _likeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));

    _doubleTapAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.easeOut,
    ));

    _likeSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _initializeVideo() async {
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });

        // Set up listeners
        _controller!.addListener(_videoListener);

        // Configure video
        await _controller!.setLooping(true);
        await _controller!.setVolume(1.0);

        // Auto play if requested
        if (widget.autoPlay) {
          await _play();
        }

        // Start progress tracking
        _startProgressTracking();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;

    setState(() {
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering;
      _currentPosition = value.position;

      // Calculate buffer progress
      if (value.buffered.isNotEmpty) {
        final buffered = value.buffered.last.end;
        _bufferProgress =
            buffered.inMilliseconds / _totalDuration.inMilliseconds;
      }
    });

    // Notify parent of play state changes
    widget.onPlayStateChanged?.call(_isPlaying);
  }

  void _startProgressTracking() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_controller != null && _controller!.value.isInitialized) {
        setState(() {
          _currentPosition = _controller!.value.position;
        });
      }
    });
  }

  Future<void> _play() async {
    if (_controller != null && _isInitialized) {
      await _controller!.play();
      _playPauseAnimationController.forward();
      _resetHideControlsTimer();
    }
  }

  Future<void> _pause() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pause();
      _playPauseAnimationController.reverse();
      _showControlsTemporarily();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _handleTap() {
    _tapCount++;

    if (_tapCount == 1) {
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (_tapCount == 1) {
          // Single tap - toggle controls
          _toggleControls();
        }
        _tapCount = 0;
      });
    } else if (_tapCount == 2) {
      // Double tap - like
      _tapTimer?.cancel();
      _handleDoubleTap();
      _tapCount = 0;
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();

    // Trigger like animation
    _doubleTapAnimationController.forward().then((_) {
      _doubleTapAnimationController.reset();
    });

    // Trigger like effect
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reset();
    });

    // Call parent callback
    widget.onDoubleTap?.call();
    widget.onLike?.call();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _resetHideControlsTimer();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _resetHideControlsTimer();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _seekTo(Duration position) {
    if (_controller != null && _isInitialized) {
      _controller!.seekTo(position);
      _showControlsTemporarily();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressTimer?.cancel();
    _tapTimer?.cancel();
    _playPauseAnimationController.dispose();
    _likeAnimationController.dispose();
    _doubleTapAnimationController.dispose();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Tap detector
          Positioned.fill(
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Buffering indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

          // Play/Pause overlay
          if (_showControls && !_isPlaying)
            Center(
              child: AnimatedBuilder(
                animation: _playPauseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * _playPauseAnimation.value),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _togglePlayPause,
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Double tap like animation
          Center(
            child: AnimatedBuilder(
              animation: _doubleTapAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _doubleTapAnimation.value,
                  child: Opacity(
                    opacity: 1.0 - _doubleTapAnimation.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating hearts animation
          AnimatedBuilder(
            animation: _likeAnimation,
            builder: (context, child) {
              return Positioned(
                right: 50,
                top: MediaQuery.of(context).size.height * 0.3,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    _likeSlideAnimation.value.dy * 200,
                  ),
                  child: Opacity(
                    opacity: 1.0 - _likeAnimation.value,
                    child: Transform.scale(
                      scale: 0.5 + (_likeAnimation.value * 0.5),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Progress bar
          if (_showControls)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor: AppColors.primary,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _currentPosition.inMilliseconds.toDouble(),
                        max: _totalDuration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          _seekTo(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    ),

                    // Time indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_currentPosition),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Buffer progress indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _bufferProgress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.3),
              ),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
