import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class CartLoadingWidget extends StatefulWidget {
  const CartLoadingWidget({super.key});

  @override
  State<CartLoadingWidget> createState() => _CartLoadingWidgetState();
}

class _CartLoadingWidgetState extends State<CartLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Summary skeleton
          _buildSkeletonCard(isDark, height: 200),

          const SizedBox(height: 20),

          // Cart items skeletons
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSkeletonCard(isDark, height: 150),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(bool isDark, {required double height}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getShadow(isDark),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header skeleton
                  Row(
                    children: [
                      _buildSkeletonBox(40, 40, isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSkeletonBox(120, 16, isDark),
                            const SizedBox(height: 8),
                            _buildSkeletonBox(80, 12, isDark),
                          ],
                        ),
                      ),
                      _buildSkeletonBox(60, 16, isDark),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Content skeleton
                  Expanded(
                    child: Column(
                      children: [
                        _buildSkeletonBox(double.infinity, 12, isDark),
                        const SizedBox(height: 8),
                        _buildSkeletonBox(double.infinity, 12, isDark),
                        const SizedBox(height: 8),
                        _buildSkeletonBox(200, 12, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonBox(double width, double height, bool isDark) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
