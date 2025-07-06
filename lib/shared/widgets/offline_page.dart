import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/constants/app_colors.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();

    // Animation de pulsation pour l'icône
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Animation de glissement pour le contenu
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Consumer<ConnectivityService>(
          builder: (context, connectivityService, _) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppColors.backgroundDark,
                          AppColors.backgroundDark.withOpacity(0.8),
                        ]
                      : [
                          AppColors.background,
                          AppColors.background.withOpacity(0.9),
                        ],
                ),
              ),
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icône animée
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error.withOpacity(0.1),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 60,
                            color: AppColors.error,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Titre principal
                      Text(
                        'Pas de connexion',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Message principal
                      Text(
                        'Vous devez être connecté à internet pour utiliser Recette+',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.getTextSecondary(isDark),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Statut de connexion
                      _buildConnectionStatus(connectivityService, isDark),

                      const SizedBox(height: 40),

                      // Instructions
                      _buildInstructions(isDark),

                      const SizedBox(height: 40),

                      // Bouton de retry
                      _buildRetryButton(connectivityService),

                      const SizedBox(height: 24),

                      // Informations supplémentaires
                      _buildAdditionalInfo(connectivityService, isDark),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(ConnectivityService service, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (service.status) {
      case ConnectivityStatus.checking:
        statusColor = AppColors.warning;
        statusIcon = Icons.wifi_find;
        statusText = 'Vérification de la connexion...';
        break;
      case ConnectivityStatus.disconnected:
        statusColor = AppColors.error;
        statusIcon = Icons.signal_wifi_off;
        statusText = 'Aucune connexion détectée';
        break;
      case ConnectivityStatus.connected:
        statusColor = AppColors.success;
        statusIcon = Icons.wifi;
        statusText = 'Connexion rétablie !';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(isDark),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vérifiez votre connexion :',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            '• Activez le Wi-Fi ou les données mobiles',
            isDark,
          ),
          _buildInstructionItem(
            '• Vérifiez la force du signal',
            isDark,
          ),
          _buildInstructionItem(
            '• Redémarrez votre routeur si nécessaire',
            isDark,
          ),
          _buildInstructionItem(
            '• Contactez votre fournisseur d\'accès',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getTextSecondary(isDark),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildRetryButton(ConnectivityService service) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRetrying ? null : () => _handleRetry(service),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isRetrying
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Vérification...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Réessayer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdditionalInfo(ConnectivityService service, bool isDark) {
    return Column(
      children: [
        if (service.lastError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.lastError!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (service.lastCheckTime != null) ...[
          Text(
            'Dernière vérification : ${_formatTime(service.lastCheckTime!)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextTertiary(isDark),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Il y a ${difference.inSeconds} secondes';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} minutes';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleRetry(ConnectivityService service) async {
    setState(() {
      _isRetrying = true;
    });

    try {
      await service.checkWithRetry(retries: 3);

      // Attendre un peu pour laisser le temps à l'UI de se mettre à jour
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }
}
