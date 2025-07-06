import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/video_recipe_drawer.dart';

class VideoInfoOverlay extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final bool isPlaying;

  const VideoInfoOverlay({
    super.key,
    required this.video,
    required this.onPlayPause,
    required this.onLike,
    required this.isPlaying,
  });

  void _showRecipeDrawer(BuildContext context) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoRecipeDrawer(
        video: video,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRecipe = video['recipe_id'] != null;

    return Stack(
      children: [
        // Tap to play/pause
        Positioned.fill(
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              color: Colors.transparent,
              child: !isPlaying
                  ? const Center(
                      child: Icon(
                        Icons.play_arrow,
                        size: 80,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Right side actions
        Positioned(
          right: 16,
          bottom: 140, // Moved higher to accommodate recipe button
          child: Column(
            children: [
              // Like button
              _buildActionButton(
                icon: video['is_liked'] == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: _formatCount(video['likes'] ?? 0),
                onTap: onLike,
                color: video['is_liked'] == true ? Colors.red : Colors.white,
              ),

              const SizedBox(height: 24),

              // Recipe button (only if video has associated recipe)
              if (hasRecipe)
                _buildActionButton(
                  icon: Icons.restaurant_menu,
                  label: 'Recette',
                  onTap: () => _showRecipeDrawer(context),
                  color: AppColors.primary,
                ),
            ],
          ),
        ),

        // Bottom info (moved lower for better visibility)
        Positioned(
          left: 16,
          right: 80,
          bottom: 120, // Moved lower
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                video['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18, // Increased font size
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

              const SizedBox(height: 8),

              // Description
              if (video['description'] != null)
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

              // Tags and recipe indicator
              Row(
                children: [
                  // Category tag
                  if (video['category'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        video['category'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Recipe indicator
                  if (hasRecipe)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Recette',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
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
          ),
        ],
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
}
