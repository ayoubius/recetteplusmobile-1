import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class VideoSideActions extends StatelessWidget {
  final Map<String, dynamic> video;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onComment;

  const VideoSideActions({
    super.key,
    required this.video,
    required this.isLiked,
    required this.likesCount,
    required this.onLike,
    required this.onShare,
    required this.onComment,
  });

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User Avatar
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: Navigate to user profile
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: video['user_avatar'] != null
                  ? Image.network(
                      video['user_avatar'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primary,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 25,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.primary,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Like Button
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(likesCount),
          onTap: onLike,
          color: isLiked ? Colors.red : Colors.white,
          isActive: isLiked,
        ),

        const SizedBox(height: 24),

        // Comment Button
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(video['comments_count'] ?? 0),
          onTap: onComment,
          color: Colors.white,
        ),

        const SizedBox(height: 24),

        // Share Button
        _buildActionButton(
          icon: Icons.share,
          label: 'Partager',
          onTap: onShare,
          color: Colors.white,
        ),

        const SizedBox(height: 24),

        // Recipe Button (if video has recipe)
        if (video['recipe_id'] != null)
          _buildActionButton(
            icon: Icons.restaurant_menu,
            label: 'Recette',
            onTap: () {
              HapticFeedback.mediumImpact();
              // TODO: Show recipe drawer
            },
            color: AppColors.secondary,
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black54,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
