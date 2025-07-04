import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class DeliveryMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? deliveryAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final bool showControls;

  const DeliveryMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.deliveryAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.showControls = false,
  });

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Carte simulée
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[100]!,
                  Colors.green[100]!,
                ],
              ),
            ),
            child: CustomPaint(
              painter: _MapPainter(
                deliveryLatitude: widget.latitude,
                deliveryLongitude: widget.longitude,
                destinationLatitude: widget.destinationLatitude,
                destinationLongitude: widget.destinationLongitude,
              ),
            ),
          ),
          
          // Overlay d'informations
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.latitude != null && widget.longitude != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Position du livreur',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.deliveryAddress != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.deliveryAddress!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Contrôles de la carte (si activés)
          if (widget.showControls) ...[
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: "zoom_in",
                    onPressed: () {
                      if (kDebugMode) {
                        print('🔍 Zoom avant');
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.add, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "zoom_out",
                    onPressed: () {
                      if (kDebugMode) {
                        print('🔍 Zoom arrière');
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.remove, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "center_map",
                    onPressed: () {
                      if (kDebugMode) {
                        print('🎯 Centrer la carte');
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
          
          // Indicateur de chargement si pas de position
          if (widget.latitude == null || widget.longitude == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_searching,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Localisation en cours...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  _MapPainter({
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Dessiner des "routes" simulées
    paint.color = Colors.white.withOpacity(0.8);
    paint.strokeWidth = 3;
    paint.style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.1,
      size.width * 0.9, size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.7, size.height * 0.6,
      size.width * 0.8, size.height * 0.9,
    );
    
    canvas.drawPath(path, paint);
    
    // Dessiner la position du livreur (point bleu)
    if (deliveryLatitude != null && deliveryLongitude != null) {
      paint.color = Colors.blue;
      paint.style = PaintingStyle.fill;
      
      // Position simulée basée sur les coordonnées
      final x = size.width * 0.4;
      final y = size.height * 0.6;
      
      canvas.drawCircle(Offset(x, y), 8, paint);
      
      // Halo autour du point
      paint.color = Colors.blue.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), 16, paint);
    }
    
    // Dessiner la destination (point rouge)
    if (destinationLatitude != null && destinationLongitude != null) {
      paint.color = Colors.red;
      paint.style = PaintingStyle.fill;
      
      // Position simulée de la destination
      final x = size.width * 0.7;
      final y = size.height * 0.3;
      
      canvas.drawCircle(Offset(x, y), 8, paint);
      
      // Halo autour du point
      paint.color = Colors.red.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), 16, paint);
    }
    
    // Dessiner une ligne entre le livreur et la destination
    if (deliveryLatitude != null && destinationLatitude != null) {
      paint.color = Colors.purple.withOpacity(0.6);
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      
      final dashPaint = Paint()
        ..color = Colors.purple.withOpacity(0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      
      final start = Offset(size.width * 0.4, size.height * 0.6);
      final end = Offset(size.width * 0.7, size.height * 0.3);
      
      _drawDashedLine(canvas, start, end, dashPaint, dashWidth, dashSpace);
    }
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashWidth, double dashSpace) {
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();
    
    for (int i = 0; i < dashCount; i++) {
      final startRatio = (i * (dashWidth + dashSpace)) / distance;
      final endRatio = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;
      
      final dashStart = Offset.lerp(start, end, startRatio)!;
      final dashEnd = Offset.lerp(start, end, endRatio)!;
      
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}