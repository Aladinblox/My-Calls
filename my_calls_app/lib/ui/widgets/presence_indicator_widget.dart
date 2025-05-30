import 'package:flutter/material.dart';

class PresenceIndicatorWidget extends StatelessWidget {
  final String status; // 'online', 'idle', 'offline'
  final double size;

  const PresenceIndicatorWidget({
    super.key,
    required this.status,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData? iconData; // Make icon optional

    switch (status.toLowerCase()) {
      case 'online':
      case 'active': // Treat 'active' as 'online' for display
        color = Colors.green.shade600;
        iconData = Icons.arrow_upward; // Rotated to point right-up for "active"
        break;
      case 'idle':
        color = Colors.amber.shade700;
        iconData = Icons.access_time; // Or Icons.pause_circle_filled_outlined
        break;
      case 'offline':
      default:
        color = Colors.grey.shade500;
        iconData = Icons.arrow_downward; // Rotated to point right-down for "away/offline"
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).cardColor, width: size / 6), // Small border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 1.0,
            offset: const Offset(0,0.5)
          )
        ]
      ),
      child: iconData != null 
          ? Transform.rotate(
              angle: (status == 'online' || status == 'active') ? -0.785398 : (status == 'offline' ? 0.785398 : 0), // -45 or 45 degrees
              child: Icon(iconData, color: Colors.white.withOpacity(0.8), size: size * 0.65),
            )
          : null, // No icon if not specified (e.g. for a simple dot)
    );
  }
}
