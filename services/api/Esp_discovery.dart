import 'dart:async';
import 'dart:io';
import 'dart:convert';

class EspDiscoveryService {
  static const int DISCOVERY_PORT = 4210;
  static const Duration BUFFER_DURATION = Duration(seconds: 2);

  RawDatagramSocket? _socket;
  StreamController<String>? _ipStreamController;
  String? _lastIp;
  DateTime? _lastIpTime;

  Stream<String> get ipStream {
    _ipStreamController ??= StreamController<String>.broadcast();
    return _ipStreamController!.stream;
  }

  Future<void> start() async {
    // Check if we have a recent cached IP
    if (_lastIp != null && _lastIpTime != null) {
      final age = DateTime.now().difference(_lastIpTime!);
      if (age < BUFFER_DURATION) {
        print('[Discovery] Using cached IP: $_lastIp');
        // Ensure controller exists
        _ipStreamController ??= StreamController<String>.broadcast();
        // Delay to ensure caller is listening
        await Future.delayed(const Duration(milliseconds: 50));
        _ipStreamController!.add(_lastIp!);
        return;
      }
    }

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      DISCOVERY_PORT,
      reuseAddress: true,
      reusePort: true,
    );

    print('[Discovery] Listening on UDP port $DISCOVERY_PORT');

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg == null) return;

        final msg = utf8.decode(dg.data);
        print('[Discovery] Received: $msg');

        if (msg.startsWith("ESP32_SENSOR:CONNECTED:")) {
          final parts = msg.split(":");
          if (parts.length >= 3) {
            final ip = parts[2];
            _lastIp = ip;
            _lastIpTime = DateTime.now();
            _ipStreamController?.add(ip);
          }
        } else if (msg.startsWith("ESP32_SENSOR:AP_MODE:")) {
          _ipStreamController?.addError('AP_MODE');
        }
      }
    });
  }

  void stop() {
    print('[Discovery] Stopping');
    _socket?.close();
    _socket = null;
    // Don't close controller here if you want to reuse cached IP
  }

  void dispose() {
    stop();
    _ipStreamController?.close();
    _ipStreamController = null;
    _lastIp = null;
    _lastIpTime = null;
  }
}
