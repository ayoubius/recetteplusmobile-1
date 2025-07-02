import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/core/services/video_service.dart';

class MockVideoService extends Mock implements VideoService {}

void main() {
  group('VideoService Tests', () {
    late VideoService videoService;
    
    setUp(() {
      videoService = VideoService();
    });
    
    test('should cache video data correctly', () async {
      // Test cache functionality
      const videoId = 'test_video_1';
      const mockData = {'title': 'Test Video', 'url': 'test_url'};
      
      // First call should fetch from network
      when(videoService.getVideoData(videoId))
          .thenAnswer((_) async => mockData);
      
      final result1 = await videoService.getVideoData(videoId);
      expect(result1, equals(mockData));
      
      // Second call should use cache
      final result2 = await videoService.getVideoData(videoId);
      expect(result2, equals(mockData));
      
      // Verify network was called only once
      verify(videoService.getVideoData(videoId)).called(1);
    });
    
    test('should handle network errors gracefully', () async {
      const videoId = 'test_video_error';
      
      when(videoService.getVideoData(videoId))
          .thenThrow(Exception('Network error'));
      
      expect(
        () => videoService.getVideoData(videoId),
        throwsA(isA<Exception>()),
      );
    });
    
    test('should retry failed requests', () async {
      const videoId = 'test_video_retry';
      const mockData = {'title': 'Test Video'};
      
      when(videoService.getVideoData(videoId))
          .thenThrow(Exception('Network error'))
          .thenAnswer((_) async => mockData);
      
      final result = await videoService.getVideoData(videoId);
      expect(result, equals(mockData));
      
      // Verify retry happened
      verify(videoService.getVideoData(videoId)).called(2);
    });
  });
}
