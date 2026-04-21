import 'package:flutter/material.dart';

class NotificationSettingsWidget extends StatefulWidget {
  final bool notificationsEnabled;
  final Function(bool) onChanged;

  const NotificationSettingsWidget({
    super.key,
    required this.notificationsEnabled,
    required this.onChanged,
  });

  @override
  State<NotificationSettingsWidget> createState() =>
      _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState
    extends State<NotificationSettingsWidget> {
  late bool _co2Alerts;
  late bool _humidityAlerts;
  late bool _sleepAlerts;

  @override
  void initState() {
    super.initState();
    _co2Alerts = widget.notificationsEnabled;
    _humidityAlerts = widget.notificationsEnabled;
    _sleepAlerts = widget.notificationsEnabled;
  }

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
                const Icon(Icons.notifications, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  'Notifikace',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              title: const Text('Povolit notifikace'),
              subtitle: const Text('Zapnout všechna upozornění'),
              value: widget.notificationsEnabled,
              onChanged: widget.onChanged,
            ),
            const Divider(),
            Text(
              'Typy upozornění',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Vysoké CO₂'),
              subtitle: const Text('Upozornit při kritické hodnotě'),
              value: _co2Alerts,
              onChanged: widget.notificationsEnabled
                  ? (value) => setState(() => _co2Alerts = value)
                  : null,
            ),
            SwitchListTile(
              title: const Text('Vlhkost mimo rozsah'),
              subtitle: const Text('Příliš vysoká nebo nízká vlhkost'),
              value: _humidityAlerts,
              onChanged: widget.notificationsEnabled
                  ? (value) => setState(() => _humidityAlerts = value)
                  : null,
            ),
            SwitchListTile(
              title: const Text('Kvalita spánku'),
              subtitle: const Text('Špatný vzduch během noci'),
              value: _sleepAlerts,
              onChanged: widget.notificationsEnabled
                  ? (value) => setState(() => _sleepAlerts = value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
