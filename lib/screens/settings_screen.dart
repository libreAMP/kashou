import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../screens/personalization_screen.dart';
import '../theme/app_theme.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/m3e_select.dart';
import '../widgets/settings_tiles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const double _maxContentWidth = 1100;

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(context);
    final scrollView = CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Settings'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const BackChip(),
        ),
        if (isDesktop)
          SliverToBoxAdapter(child: _buildDesktopBody(sections))
        else
          SliverList(
            delegate: SliverChildListDelegate([
              ...sections,
              const SizedBox(height: 32),
            ]),
          ),
      ],
    );

    if (!isDesktop) return Scaffold(body: scrollView);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: scrollView,
        ),
      ),
    );
  }

  Widget _buildDesktopBody(List<Widget> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(children: sections.sublist(0, 3)),
                        ),
                        Expanded(
                          child: Column(children: sections.sublist(3)),
                        ),
                      ],
                    )
                  : Column(children: sections),
        );
      },
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return [
      SettingsSection(
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
      SettingsSection(
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rescanning library...')),
              );
            },
          ),
        ],
      ),
      Consumer<SettingsProvider>(
        builder: (context, settings, child) => SettingsSection(
          title: 'Audio',
          children: [
            SettingsSwitchTile(
              icon: Icons.music_note,
              title: 'Gapless Playback',
              subtitle: 'No gaps between tracks',
              value: settings.enableGapless,
              onChanged: settings.setEnableGapless,
            ),
            SettingsSwitchTile(
              icon: Icons.animation,
              title: 'Crossfade',
              subtitle: 'Fade between tracks',
              value: settings.enableCrossfade,
              onChanged: settings.setEnableCrossfade,
            ),
            if (settings.enableCrossfade)
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text('Crossfade Duration'),
                subtitle: SliderTheme(
                  data: m3eSliderTheme(context),
                  child: Slider(
                    value: settings.crossfadeDuration,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${settings.crossfadeDuration.toInt()}s',
                    onChanged: settings.setCrossfadeDuration,
                  ),
                ),
              ),
            SettingsSwitchTile(
              icon: Icons.volume_up,
              title: 'Replay Gain',
              subtitle: 'Normalize volume across tracks',
              value: settings.enableReplayGain,
              onChanged: settings.setEnableReplayGain,
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Buffer Size'),
              subtitle: const Text('Applies on next launch'),
              trailing: M3ESelect<int>(
                value: settings.bufferSize,
                labelOf: (value) => '$value',
                items: const [1024, 2048, 4096],
                onChanged: settings.setBufferSize,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: const Text('Resampler Quality'),
              subtitle: const Text('Float output on high, next launch'),
              trailing: M3ESelect<String>(
                value: settings.resamplerQuality,
                labelOf: (value) => value,
                items: const ['Low', 'Medium', 'High', 'Very High'],
                onChanged: settings.setResamplerQuality,
              ),
            ),
            SettingsSwitchTile(
              icon: Icons.blur_on,
              title: 'Dithering',
              subtitle: 'Dither on the 16 bit path, next launch',
              value: settings.enableDither,
              onChanged: settings.setEnableDither,
            ),
          ],
        ),
      ),
      Consumer<SettingsProvider>(
        builder: (context, settings, child) => SettingsSection(
          title: 'Online Features',
          children: [
            SettingsSwitchTile(
              icon: Icons.cloud_outlined,
              title: 'YouTube Integration',
              subtitle: 'Enable online music streaming',
              value: settings.enableYouTubeIntegration,
              onChanged: settings.setEnableYouTubeIntegration,
            ),
            SettingsSwitchTile(
              icon: Icons.history_rounded,
              title: 'Search history',
              subtitle: 'Remember what you search on Stream',
              value: settings.enableSearchHistory,
              onChanged: settings.setEnableSearchHistory,
            ),
            SettingsSwitchTile(
              icon: Icons.cast,
              title: 'Casting',
              subtitle: 'Chromecast support',
              value: settings.enableCasting,
              onChanged: settings.setEnableCasting,
            ),
            SettingsSwitchTile(
              icon: Icons.directions_car,
              title: 'Android Auto',
              subtitle: 'Car dashboard integration',
              value: settings.enableAndroidAuto,
              onChanged: settings.setEnableAndroidAuto,
            ),
          ],
        ),
      ),
      SettingsSection(
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
            onTap: () => launchUrl(
              Uri.parse('https://github.com/libreAMP/kashou'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Support Development'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/libreAMP/kashou'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    ];
  }

  void _showMusicFoldersDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final customPaths = prefs.getStringList('custom_music_paths') ?? [];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Music Folders',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        content: SizedBox(
          width: isDesktop ? 480 : double.maxFinite,
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
                        tooltip: 'Remove folder',
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          customPaths.remove(path);
                          await prefs.setStringList(
                              'custom_music_paths', customPaths);
                          navigator.pop();
                          // the builder's context is unmounted after pop, so
                          // reopen from the screen's own context instead
                          if (context.mounted) {
                            _showMusicFoldersDialog(context);
                          }
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
              String? selectedDirectory = await FilePicker.getDirectoryPath();

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
}
