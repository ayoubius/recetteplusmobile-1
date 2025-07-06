import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/connectivity_service.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  final bool blockAppWhenOffline;
  final Widget? offlineWidget;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.blockAppWhenOffline = false,
    this.offlineWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (blockAppWhenOffline && connectivityService.isDisconnected) {
          return offlineWidget ?? _buildOfflineScreen(context, isDark);
        }

        return Stack(
          children: [
            child,
            if (connectivityService.isDisconnected)
              _buildOfflineBanner(context, isDark),
          ],
        );
      },
    );
  }

  Widget _buildOfflineScreen(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off,
                  size: 60,
                  color: AppColors.error.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Pas de connexion internet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Vérifiez votre connexion internet et réessayez',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextSecondary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Provider.of<ConnectivityService>(context, listen: false)
                      .checkNow();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.error,
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pas de connexion internet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<ConnectivityService>(context, listen: false)
                      .checkNow();
                },
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
