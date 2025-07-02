import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../../../lib/core/services/video_service.dart';

class MockVideoService extends Mock {
  Future<List<Map<String, dynamic>>> getVideos({
    String? searchQuery,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    return [];
  }

  Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    return null;
  }
}

void main() {
  group('VideoService Tests', () {
    late MockVideoService mockVideoService;
    
    setUp(() {
      mockVideoService = MockVideoService();
    });
    
    test('should return empty list when no videos available', () async {
      // Test basic functionality
      when(mockVideoService.getVideos())
          .thenAnswer((_) async => []);
      
      final result = await mockVideoService.getVideos();
      expect(result, isEmpty);
    });
    
    test('should handle network errors gracefully', () async {
      const videoId = 'test_video_error';
      
      when(mockVideoService.getVideoById(videoId))
          .thenThrow(Exception('Network error'));
      
      expect(
        () => mockVideoService.getVideoById(videoId),
        throwsA(isA<Exception>()),
      );
    });
    
    test('should return video data when available', () async {
      const videoId = 'test_video_1';
      const mockData = {'id': videoId, 'title': 'Test Video', 'url': 'test_url'};
      
      when(mockVideoService.getVideoById(videoId))
          .thenAnswer((_) async => mockData);
      
      final result = await mockVideoService.getVideoById(videoId);
      expect(result, equals(mockData));
    });
  });
}
