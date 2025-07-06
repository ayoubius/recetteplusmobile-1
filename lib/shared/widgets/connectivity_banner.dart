import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/constants/app_colors.dart';

class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  final bool showWhenConnected;
  final Duration animationDuration;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.showWhenConnected = false,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        return Column(
          children: [
            AnimatedContainer(
              duration: animationDuration,
              height: _shouldShowBanner(connectivityService) ? 40 : 0,
              child: _shouldShowBanner(connectivityService)
                  ? _buildBanner(context, connectivityService)
                  : const SizedBox.shrink(),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  bool _shouldShowBanner(ConnectivityService service) {
    if (service.isDisconnected) return true;
    if (service.isChecking) return true;
    if (showWhenConnected && service.isConnected) return true;
    return false;
  }

  Widget _buildBanner(BuildContext context, ConnectivityService service) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    switch (service.status) {
      case ConnectivityStatus.connected:
        backgroundColor = AppColors.success;
        textColor = Colors.white;
        icon = Icons.wifi;
        message = 'Connexion rétablie';
        break;
      case ConnectivityStatus.disconnected:
        backgroundColor = AppColors.error;
        textColor = Colors.white;
        icon = Icons.wifi_off;
        message = 'Pas de connexion internet';
        break;
      case ConnectivityStatus.checking:
        backgroundColor = AppColors.warning;
        textColor = Colors.white;
        icon = Icons.wifi_find;
        message = 'Vérification de la connexion...';
        break;
    }

    return Container(
      width: double.infinity,
      height: 40,
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (service.isDisconnected) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => service.checkNow(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: textColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Réessayer',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
