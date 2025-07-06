import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/enhanced_simple_video_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.videoUrl,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  final EnhancedSimpleVideoManager _videoManager = EnhancedSimpleVideoManager();
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    // Don't dispose here, let the manager handle it
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = await _videoManager.initializeVideo(
        widget.videoId,
        widget.videoUrl,
      );

      if (_controller != null && mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.autoPlay) {
          await _videoManager.playVideo(widget.videoId);
        }
      }
    } catch (e) {
      // Handle initialization error
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
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
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
