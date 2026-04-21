import 'package:flutter/material.dart';

enum ConnectionStatus {
  disconnected, // Nepřipojeno - žádná odezva
  slow, // Připojeno, ale pomalé (timeout blízko limitu)
  connected; // Online a odpovídá rychle

  String get displayName {
    switch (this) {
      case ConnectionStatus.disconnected:
        return 'Nepřipojeno';
      case ConnectionStatus.slow:
        return 'Pomalé spojení';
      case ConnectionStatus.connected:
        return 'Online';
    }
  }

  Color get badgeColor {
    switch (this) {
      case ConnectionStatus.disconnected:
        return const Color(0xFFF44336); // Červená
      case ConnectionStatus.slow:
        return const Color(0xFFFF9800); // Oranžová
      case ConnectionStatus.connected:
        return const Color(0xFF4CAF50); // Zelená
    }
  }

  IconData get icon {
    switch (this) {
      case ConnectionStatus.disconnected:
        return Icons.cloud_off;
      case ConnectionStatus.slow:
        return Icons.cloud_queue;
      case ConnectionStatus.connected:
        return Icons.cloud_done;
    }
  }
}

class ConnectionMetrics {
  final ConnectionStatus status;
  final int responseTimeMs;
  final DateTime lastSuccessfulPing;
  final int consecutiveFailures;
  final String? errorMessage;

  ConnectionMetrics({
    required this.status,
    required this.responseTimeMs,
    required this.lastSuccessfulPing,
    this.consecutiveFailures = 0,
    this.errorMessage,
  });

  bool get isHealthy => status == ConnectionStatus.connected;
  bool get needsAttention => status != ConnectionStatus.connected;

  ConnectionMetrics copyWith({
    ConnectionStatus? status,
    int? responseTimeMs,
    DateTime? lastSuccessfulPing,
    int? consecutiveFailures,
    String? errorMessage,
  }) {
    return ConnectionMetrics(
      status: status ?? this.status,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      lastSuccessfulPing: lastSuccessfulPing ?? this.lastSuccessfulPing,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
