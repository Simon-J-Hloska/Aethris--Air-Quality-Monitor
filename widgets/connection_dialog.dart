import 'package:air_quality_app/models/connection_status.dart';
import 'package:flutter/material.dart';

class ConnectionDetailsDialog extends StatelessWidget {
  final ConnectionMetrics metrics;

  const ConnectionDetailsDialog({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(metrics.status.icon, color: metrics.status.badgeColor),
          const SizedBox(width: 12),
          const Text('Stav připojení'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', metrics.status.displayName),
          _buildInfoRow('Response time', '${metrics.responseTimeMs} ms'),
          _buildInfoRow(
            'Poslední úspěch',
            _formatDateTime(metrics.lastSuccessfulPing),
          ),
          if (metrics.consecutiveFailures > 0)
            _buildInfoRow(
              'Selhání za sebou',
              '${metrics.consecutiveFailures}x',
              isWarning: true,
            ),
          if (metrics.errorMessage != null)
            _buildInfoRow(
              'Chyba',
              metrics.errorMessage!,
              isWarning: true,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zavřít'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: isWarning ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'před ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'před ${diff.inMinutes}m';
    } else {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
