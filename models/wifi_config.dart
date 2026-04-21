class WifiConfig {
  final String ssid;
  final String password;

  WifiConfig({
    required this.ssid,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'wifi_config',
      'ssid': ssid,
      'password': password,
    };
  }
}

class EspResponse {
  final String type;
  final String? state;
  final String? ip;
  final String? error;

  EspResponse({
    required this.type,
    this.state,
    this.ip,
    this.error,
  });

  factory EspResponse.fromJson(Map<String, dynamic> json) {
    return EspResponse(
      type: json['type'] as String,
      state: json['state'] as String?,
      ip: json['ip'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isReady => type == 'ready' && ip != null;
  bool get isError => type == 'error' || error != null;
}
