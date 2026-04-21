import 'package:flutter/material.dart';
import '../models/esp_status.dart';

class EspStatusCard extends StatelessWidget {
  final EspStatus status;

  const EspStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.router, color: Colors.teal),
                const SizedBox(width: 12),
                Text(
                  'ESP Zařízení',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatusRow(
              'Firmware',
              status.firmwareVersion,
              Icons.memory,
            ),
            _buildStatusRow(
              'Uptime',
              status.formattedUptime,
              Icons.timer,
            ),
            _buildStatusRow(
              'WiFi',
              '${status.wifiSSID} (${status.wifiSignalQuality})',
              Icons.wifi,
            ),
            _buildStatusRow(
              'Signál',
              '${status.wifiRSSI} dBm',
              Icons.signal_cellular_alt,
            ),
            _buildStatusRow(
              'Volná paměť',
              status.formattedFreeHeap,
              Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
