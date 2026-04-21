import 'package:flutter/material.dart';
import '../models/connection_status.dart';

class ConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  final int? responseTimeMs;
  final VoidCallback? onTap;

  const ConnectionBadge({
    super.key,
    required this.status,
    this.responseTimeMs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: status.badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: status.badgeColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status.icon,
              color: status.badgeColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.displayName,
                  style: TextStyle(
                    color: status.badgeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (responseTimeMs != null &&
                    status != ConnectionStatus.disconnected)
                  Text(
                    '${responseTimeMs}ms',
                    style: TextStyle(
                      color: status.badgeColor.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
