import 'package:air_quality_app/models/user_profile.dart';
import 'package:air_quality_app/screens/onboarding/welcome_screen.dart';
import 'package:air_quality_app/services/background/onboarding_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../config/app_config.dart';
import '../widgets/theme_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _chatbotEnabled;
  late bool _notificationsEnabled;
  late int _refreshIntervalSeconds;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _chatbotEnabled = settings.chatbotEnabled;
    _notificationsEnabled = settings.notificationsEnabled;
    _refreshIntervalSeconds = settings.refreshInterval.inSeconds;
  }

  void _saveSettings() async {
    final newSettings = context.read<AppState>().settings.copyWith(
          refreshInterval: Duration(seconds: _refreshIntervalSeconds),
          chatbotEnabled: _chatbotEnabled,
          notificationsEnabled: _notificationsEnabled,
        );
    context.read<AppState>().updateSettings(newSettings);
    await newSettings.saveToPrefs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nastavení uloženo')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('ULOŽIT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Aktualizace dat',
            children: [_buildRefreshIntervalSelector()],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Funkce',
            children: [
              SwitchListTile(
                title: const Text('Chatbot'),
                subtitle: const Text('Povolit chatbot doporučení'),
                value: _chatbotEnabled,
                onChanged: (value) => setState(() => _chatbotEnabled = value),
                secondary: const Icon(Icons.chat),
              ),
              SwitchListTile(
                title: const Text('Notifikace'),
                subtitle: const Text('Upozornění na špatnou kvalitu vzduchu'),
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
                secondary: const Icon(Icons.notifications),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tmavý režim', style: TextStyle(fontSize: 16)),
                        Text(
                          'Přepnout mezi světlým a tmavým režimem',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    ThemeToggleSwitch(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Informace',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Verze aplikace'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDangerZone(),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshIntervalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Interval aktualizace', style: TextStyle(fontSize: 16)),
            Text(
              '$_refreshIntervalSeconds s',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: _refreshIntervalSeconds.toDouble(),
          min: 30,
          max: 60,
          divisions: 11,
          label: '$_refreshIntervalSeconds s',
          onChanged: (value) =>
              setState(() => _refreshIntervalSeconds = value.toInt()),
        ),
        Text(
          'Čím kratší interval, tím častější aktualizace dat',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: theme.colorScheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Nebezpečná zóna',
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              leading:
                  Icon(Icons.delete_forever, color: theme.colorScheme.error),
              title: Text('Reset statistik',
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Vymaže všechny min/max hodnoty'),
              onTap: _showResetStatsDialog,
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: theme.colorScheme.error),
              title: Text('Reset nastavení',
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Vrátí výchozí hodnoty intervalu a funkcí'),
              onTap: _showResetSettingsDialog,
            ),
            ListTile(
              leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
              title: Text('Nová konfigurace',
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Smaže všechna data a vrátí na začátek'),
              onTap: _showResetConfigurationDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfigurationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nová konfigurace'),
        content: const Text(
          'Opravdu chcete smazat všechna nastavení a začít znovu?\n\n'
          'Aplikace se restartuje do uvítací obrazovky.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () async {
              await OnboardingStorage.clearSetup();
              AppConfig.instance.userName = '';
              AppConfig.instance.gender = Gender.male;
              AppSettings.instance.workflowM =
                  WorkflowMode.relax; // reset workflow
              context.read<AppState>().updateSettings(AppSettings.instance);
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Potvrdit'),
          ),
        ],
      ),
    );
  }

  void _showResetStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset statistik'),
        content: const Text(
          'Opravdu chcete vymazat všechny naměřené statistiky (min/max hodnoty)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().resetStatistics();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Statistiky resetovány')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resetovat'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset nastavení'),
        content: const Text('Opravdu chcete obnovit výchozí hodnoty?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().updateSettings(
                    context.read<AppState>().settings.copyWith(
                          refreshInterval: const Duration(seconds: 30),
                          chatbotEnabled: true,
                          notificationsEnabled: false,
                          workflowM: WorkflowMode.relax, // reset workflow
                        ),
                  );
              setState(() {
                _refreshIntervalSeconds = 30;
                _chatbotEnabled = true;
                _notificationsEnabled = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nastavení obnoveno')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resetovat'),
          ),
        ],
      ),
    );
  }
}
