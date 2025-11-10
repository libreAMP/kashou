import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';

class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalization')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThemeSection(context),
          const SizedBox(height: 24),
          _buildColorSection(context),
          const SizedBox(height: 24),
          _buildFontSection(context),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, theme, child) {
                return SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Auto'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                  ],
                  selected: {theme.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    theme.setThemeMode(selection.first);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Minimal Bottom Bar'),
                  subtitle: const Text('Hide labels until tab is tapped'),
                  value: settings.minimalBottomBar,
                  onChanged: settings.setMinimalBottomBar,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colors',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, theme, child) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Material You'),
                  subtitle: const Text('Use wallpaper colors'),
                  value: theme.useMaterialYou,
                  onChanged: theme.setUseMaterialYou,
                );
              },
            ),
            Consumer<ThemeProvider>(
              builder: (context, theme, child) {
                if (theme.useMaterialYou) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Accent Color',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          [
                            Colors.red,
                            Colors.pink,
                            Colors.purple,
                            Colors.deepPurple,
                            Colors.indigo,
                            Colors.blue,
                            Colors.cyan,
                            Colors.teal,
                            Colors.green,
                            Colors.orange,
                          ].map((color) {
                            return InkWell(
                              onTap: () => theme.setAccentColor(color),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: theme.accentColor == color
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: theme.accentColor == color
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showColorPicker(context, theme),
                      icon: const Icon(Icons.colorize),
                      label: const Text('Custom Color'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSection(BuildContext context) {
    final popularFonts = [
      'System',
      'DM Sans',
      'Manrope',
      'Inter',
      'Work Sans',
      'Roboto',
      'Poppins',
      'Montserrat',
      'Lato',
      'Nunito',
      'Open Sans',
      'Raleway',
      'Quicksand',
      'Ubuntu',
      'Source Sans Pro',
      'Playfair Display',
      'Merriweather',
      'Oswald',
      'Bebas Neue',
      'Pacifico',
      'Lobster',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Font',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return DropdownButtonFormField<String>(
                  value: settings.fontFamily,
                  decoration: const InputDecoration(
                    labelText: 'Font Family',
                    border: OutlineInputBorder(),
                  ),
                  items: popularFonts.map((font) {
                    return DropdownMenuItem(value: font, child: Text(font));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settings.setFontFamily(value);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The quick brown fox jumps over the lazy dog',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '0123456789',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider theme) {
    Color pickerColor = theme.accentColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                theme.setAccentColor(pickerColor);
                Navigator.pop(context);
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }
}
