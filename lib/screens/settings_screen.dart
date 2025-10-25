import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../screens/personalization_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSection(
                context,
                title: 'Appearance',
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Personalization'),
                    subtitle: const Text('Theme, colors, and fonts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalizationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'Library',
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Music Folders'),
                    subtitle: const Text('Manage custom music locations'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showMusicFoldersDialog(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Rescan Library'),
                    subtitle: const Text('Scan for new music files'),
                    onTap: () {
                      // Trigger library rescan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rescanning library...')),
                      );
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'Audio',
                children: [
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.music_note),
                        title: const Text('Gapless Playback'),
                        subtitle: const Text(
                          'Seamless transition between tracks',
                        ),
                        value: settings.enableGapless,
                        onChanged: settings.setEnableGapless,
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.animation),
                        title: const Text('Crossfade'),
                        subtitle: const Text('Fade between tracks'),
                        value: settings.enableCrossfade,
                        onChanged: settings.setEnableCrossfade,
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      if (!settings.enableCrossfade) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        leading: const SizedBox(width: 40),
                        title: const Text('Crossfade Duration'),
                        subtitle: Slider(
                          value: settings.crossfadeDuration,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${settings.crossfadeDuration.toInt()}s',
                          onChanged: settings.setCrossfadeDuration,
                        ),
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.volume_up),
                        title: const Text('Replay Gain'),
                        subtitle: const Text('Normalize volume across tracks'),
                        value: settings.enableReplayGain,
                        onChanged: settings.setEnableReplayGain,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Buffer Size'),
                    subtitle: const Text('Audio processing buffer'),
                    trailing: Consumer<SettingsProvider>(
                      builder: (context, settings, child) {
                        return DropdownButton<int>(
                          value: settings.bufferSize,
                          items: const [
                            DropdownMenuItem(value: 1024, child: Text('1024')),
                            DropdownMenuItem(value: 2048, child: Text('2048')),
                            DropdownMenuItem(value: 4096, child: Text('4096')),
                          ],
                          onChanged: (value) {
                            if (value != null) settings.setBufferSize(value);
                          },
                        );
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.high_quality),
                    title: const Text('Resampler Quality'),
                    subtitle: const Text('Audio resampling quality'),
                    trailing: Consumer<SettingsProvider>(
                      builder: (context, settings, child) {
                        return DropdownButton<String>(
                          value: settings.resamplerQuality,
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'Very High',
                              child: Text('Very High'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              settings.setResamplerQuality(value);
                          },
                        );
                      },
                    ),
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.blur_on),
                        title: const Text('Dithering'),
                        subtitle: const Text('Reduce quantization noise'),
                        value: settings.enableDither,
                        onChanged: settings.setEnableDither,
                      );
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'Online Features',
                children: [
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.cloud_outlined),
                        title: const Text('YouTube Integration'),
                        subtitle: const Text('Enable online music streaming'),
                        value: settings.enableYouTubeIntegration,
                        onChanged: settings.setEnableYouTubeIntegration,
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.cast),
                        title: const Text('Casting'),
                        subtitle: const Text('Chromecast support'),
                        value: settings.enableCasting,
                        onChanged: settings.setEnableCasting,
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.directions_car),
                        title: const Text('Android Auto'),
                        subtitle: const Text('Car dashboard integration'),
                        value: settings.enableAndroidAuto,
                        onChanged: settings.setEnableAndroidAuto,
                      );
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'About',
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: const Text('1.0.0'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Open Source'),
                    subtitle: const Text('GPL v3 License'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open GitHub repo
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: const Text('Support Development'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Show support options
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  void _showMusicFoldersDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final customPaths = prefs.getStringList('custom_music_paths') ?? [];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Music Folders'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customPaths.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No custom folders added'),
                )
              else
                ...customPaths.map((path) => ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(path),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          customPaths.remove(path);
                          await prefs.setStringList('custom_music_paths', customPaths);
                          Navigator.pop(context);
                          _showMusicFoldersDialog(context);
                        },
                      ),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              
              if (selectedDirectory != null) {
                customPaths.add(selectedDirectory);
                await prefs.setStringList('custom_music_paths', customPaths);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showMusicFoldersDialog(context);
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
