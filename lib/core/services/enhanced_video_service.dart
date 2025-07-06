import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'video_service.dart';

enum VideoQuality { auto, low, medium, high }

class EnhancedVideoService extends VideoService {
  static VideoQuality _currentQuality = VideoQuality.auto;
  static bool _isConnected = true;

  /// Get adaptive video quality based on network connection
  static Future<VideoQuality> getAdaptiveQuality() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      switch (connectivityResult) {
        case ConnectivityResult.wifi:
          return VideoQuality.high;
        case ConnectivityResult.mobile:
          return VideoQuality.medium;
        case ConnectivityResult.ethernet:
          return VideoQuality.high;
        default:
          return VideoQuality.low;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur détection qualité adaptative: $e');
      }
      return VideoQuality.medium;
    }
  }

  /// Get video URL based on quality
  static String getQualityVideoUrl(
      Map<String, dynamic> video, VideoQuality quality) {
    final videoUrls = video['video_urls'] as Map<String, dynamic>?;

    if (videoUrls == null) {
      return video['video_url'] ?? '';
    }

    switch (quality) {
      case VideoQuality.high:
        return videoUrls['high'] ??
            videoUrls['medium'] ??
            videoUrls['low'] ??
            video['video_url'] ??
            '';
      case VideoQuality.medium:
        return videoUrls['medium'] ??
            videoUrls['low'] ??
            video['video_url'] ??
            '';
      case VideoQuality.low:
        return videoUrls['low'] ?? video['video_url'] ?? '';
      case VideoQuality.auto:
        // Use adaptive quality
        return getQualityVideoUrl(video, _currentQuality);
    }
  }

  /// Initialize adaptive quality monitoring
  static void initializeAdaptiveQuality() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Typically the list contains one result, but we'll take the first one
      _updateQualityBasedOnConnection(
          results.isNotEmpty ? results.first : ConnectivityResult.none);
    });

    // Set initial quality
    getAdaptiveQuality().then((quality) {
      _currentQuality = quality;
    });
  }

  static void _updateQualityBasedOnConnection(ConnectivityResult result) {
    VideoQuality newQuality;

    switch (result) {
      case ConnectivityResult.wifi:
        newQuality = VideoQuality.high;
        _isConnected = true;
        break;
      case ConnectivityResult.mobile:
        newQuality = VideoQuality.medium;
        _isConnected = true;
        break;
      case ConnectivityResult.ethernet:
        newQuality = VideoQuality.high;
        _isConnected = true;
        break;
      default:
        newQuality = VideoQuality.low;
        _isConnected = false;
        break;
    }

    if (_currentQuality != newQuality) {
      _currentQuality = newQuality;
      if (kDebugMode) {
        print('📶 Qualité vidéo adaptée: ${_qualityToString(newQuality)}');
      }
    }
  }

  static String _qualityToString(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return 'Haute (1080p)';
      case VideoQuality.medium:
        return 'Moyenne (720p)';
      case VideoQuality.low:
        return 'Basse (480p)';
      case VideoQuality.auto:
        return 'Automatique';
    }
  }

  /// Get current video quality
  static VideoQuality get currentQuality => _currentQuality;

  /// Check if connected
  static bool get isConnected => _isConnected;

  /// Set manual quality (overrides adaptive)
  static void setManualQuality(VideoQuality quality) {
    _currentQuality = quality;
    if (kDebugMode) {
      print('🎥 Qualité vidéo manuelle: ${_qualityToString(quality)}');
    }
  }

  /// Get videos with enhanced metadata
  static Future<List<Map<String, dynamic>>> getEnhancedVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final videos = await VideoService.getVideos(
        searchQuery: searchQuery,
        category: category,
        limit: limit,
        offset: offset,
      );

      // Enhance videos with quality URLs and metadata
      return videos.map((video) {
        return {
          ...video,
          'adaptive_quality': _currentQuality,
          'quality_url': getQualityVideoUrl(video, _currentQuality),
          'is_preloadable': _isConnected,
          'estimated_size': _estimateVideoSize(video),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération vidéos améliorées: $e');
      }
      return [];
    }
  }

  static Map<String, dynamic> _estimateVideoSize(Map<String, dynamic> video) {
    final duration = video['duration'] ?? 60; // seconds
    final quality = _currentQuality;

    double mbPerMinute;
    switch (quality) {
      case VideoQuality.high:
        mbPerMinute = 25.0; // ~25MB per minute for 1080p
        break;
      case VideoQuality.medium:
        mbPerMinute = 15.0; // ~15MB per minute for 720p
        break;
      case VideoQuality.low:
        mbPerMinute = 8.0; // ~8MB per minute for 480p
        break;
      case VideoQuality.auto:
        mbPerMinute = 15.0; // Default to medium
        break;
    }

    final estimatedMB = (duration / 60) * mbPerMinute;

    return {
      'estimated_mb': estimatedMB.round(),
      'quality': _qualityToString(quality),
      'duration_minutes': (duration / 60).toStringAsFixed(1),
    };
  }

  /// Preload video for smooth playback
  static Future<bool> preloadVideo(String videoId, String videoUrl) async {
    try {
      if (!_isConnected) {
        if (kDebugMode) {
          print('⚠️ Pas de connexion - préchargement annulé pour $videoId');
        }
        return false;
      }

      // TODO: Implement actual video preloading logic
      // This could involve downloading the first few seconds of the video
      // or using a video caching library

      if (kDebugMode) {
        print('📥 Préchargement vidéo: $videoId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur préchargement vidéo $videoId: $e');
      }
      return false;
    }
  }

  /// Get video format support
  static List<String> getSupportedFormats() {
    return ['mp4', 'webm', 'mkv', 'avi', 'mov'];
  }

  /// Check if video format is supported
  static bool isFormatSupported(String url) {
    final supportedFormats = getSupportedFormats();
    final extension = url.split('.').last.toLowerCase();
    return supportedFormats.contains(extension);
  }

  /// Get video statistics
  static Map<String, dynamic> getVideoStats() {
    return {
      'current_quality': _qualityToString(_currentQuality),
      'is_connected': _isConnected,
      'supported_formats': getSupportedFormats(),
      'adaptive_enabled': true,
    };
  }
}
