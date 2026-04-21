import 'package:air_quality_app/models/wifi_config.dart';
import 'package:flutter/material.dart';

class WifiConfigDialog extends StatefulWidget {
  const WifiConfigDialog({super.key});

  @override
  State<WifiConfigDialog> createState() => _WifiConfigDialogState();
}

class _WifiConfigDialogState extends State<WifiConfigDialog> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final config = WifiConfig(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.pop(context, config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WiFi konfigurace'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'Název WiFi sítě (SSID)',
                prefixIcon: Icon(Icons.wifi),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Zadejte název WiFi sítě';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Heslo',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Zadejte heslo';
                }
                if (value.length < 8) {
                  return 'Heslo musí mít alespoň 8 znaků';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušit'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Pokračovat'),
        ),
      ],
    );
  }
}
