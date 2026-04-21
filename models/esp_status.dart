class EspStatus {
  final int uptimeSeconds;
  final String firmwareVersion;
  final String wifiSSID;
  final int wifiRSSI;
  final int freeHeapBytes;
  final DateTime timestamp;

  EspStatus({
    required this.uptimeSeconds,
    required this.firmwareVersion,
    required this.wifiSSID,
    required this.wifiRSSI,
    required this.freeHeapBytes,
    required this.timestamp,
  });

  factory EspStatus.fromJson(Map<String, dynamic> json) {
    return EspStatus(
      uptimeSeconds: json['uptime'] as int,
      firmwareVersion: json['firmware_version'] as String,
      wifiSSID: json['wifi_ssid'] as String,
      wifiRSSI: json['wifi_rssi'] as int,
      freeHeapBytes: json['free_heap'] as int,
      timestamp: DateTime.now(),
    );
  }

  String get formattedUptime {
    final hours = uptimeSeconds ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    final seconds = uptimeSeconds % 60;
    return '${hours}h ${minutes}m ${seconds}s';
  }

  String get wifiSignalQuality {
    if (wifiRSSI >= -50) return 'Výborný';
    if (wifiRSSI >= -60) return 'Dobrý';
    if (wifiRSSI >= -70) return 'Průměrný';
    return 'Slabý';
  }

  String get formattedFreeHeap {
    final kb = freeHeapBytes / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }
}

class DisplayCommand {
  final DisplayAction action;
  final String? text;
  final int? brightness;

  DisplayCommand({
    required this.action,
    this.text,
    this.brightness,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      if (text != null) 'text': text,
      if (brightness != null) 'brightness': brightness,
    };
  }
}

enum DisplayAction {
  on,
  off,
  setText,
  setBrightness,
  clear;
}
