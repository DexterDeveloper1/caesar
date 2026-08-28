import 'package:caesar/core/constants.dart';
import 'package:caesar/features/settings/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq),
            title: const Text('Sound effects'),
            subtitle: const Text('Play sounds during a game'),
            value: settings.soundEnabled,
            onChanged: controller.setSoundEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.music_note),
            title: const Text('Background music'),
            subtitle: const Text('Loop a soft track while you play'),
            value: settings.musicEnabled,
            onChanged: controller.setMusicEnabled,
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('Appearance'),
            subtitle: Text(_themeLabel(settings.themeMode)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 0),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Starting difficulty'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: [
                for (final entry in GameConfig.difficultyPresets.entries)
                  ButtonSegment(value: entry.value, label: Text(entry.key)),
              ],
              selected: {settings.startDifficulty},
              onSelectionChanged: (s) => controller.setStartDifficulty(s.first),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Follow system setting',
    ThemeMode.light => 'Always light',
    ThemeMode.dark => 'Always dark',
  };
}
