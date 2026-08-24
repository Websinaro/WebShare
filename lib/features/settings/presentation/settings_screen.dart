import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoAccept = false;
  bool _requireConfirmation = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            const _SettingsSectionLabel('General'),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Download location'),
              subtitle: const Text('Internal storage / WebShare'),
              onTap: () {},
            ),
            const _SettingsSectionLabel('Appearance'),
            RadioGroup<ThemeMode>(
              groupValue: _themeMode,
              onChanged: (v) => setState(() => _themeMode = v!),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('System default'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
            const _SettingsSectionLabel('Transfers'),
            SwitchListTile(
              title: const Text('Auto-accept from known devices'),
              subtitle: const Text('Skip the confirmation step for devices you\'ve paired with before'),
              value: _autoAccept,
              onChanged: (v) => setState(() => _autoAccept = v),
            ),
            SwitchListTile(
              title: const Text('Require confirmation before receiving'),
              value: _requireConfirmation,
              onChanged: (v) => setState(() => _requireConfirmation = v),
            ),
            const _SettingsSectionLabel('Security'),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Session token expiry'),
              subtitle: const Text('5 minutes'),
              onTap: () {},
            ),
            const _SettingsSectionLabel('About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('WebShare'),
              subtitle: Text('Version 1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String label;
  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
