import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class VideoBottomInfo extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback? onUserTap;

  const VideoBottomInfo({
    super.key,
    required this.video,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // User info
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onUserTap?.call();
          },
          child: Row(
            children: [
              Text(
                '@${video['username'] ?? 'utilisateur'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (video['is_verified'] == true)
                const Icon(
                  Icons.verified,
                  color: AppColors.primary,
                  size: 16,
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Video title
        Text(
          video['title'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
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

        const SizedBox(height: 8),

        // Description
        if (video['description'] != null &&
            video['description'].toString().isNotEmpty)
          Text(
            video['description'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black54,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 12),

        // Tags and metadata
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Category tag
            if (video['category'] != null)
              _buildTag(video['category'], AppColors.primary),

            // Recipe indicator
            if (video['recipe_id'] != null)
              _buildTag('Recette', AppColors.secondary),

            // Duration
            if (video['duration'] != null)
              _buildTag(_formatDuration(video['duration']),
                  Colors.white.withOpacity(0.8)),

            // Views count
            if (video['views'] != null)
              _buildTag('${_formatCount(video['views'])} vues',
                  Colors.white.withOpacity(0.8)),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
