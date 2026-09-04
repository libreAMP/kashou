import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/back_chip.dart';
import '../widgets/settings_tiles.dart';

class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Personalization'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const BackChip(),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              SettingsSection(
                title: 'Theme',
                children: [
                  Consumer<ThemeProvider>(
                    builder: (context, theme, child) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Consumer<ThemeProvider>(
                builder: (context, theme, child) => SettingsSection(
                  title: 'Colors',
                  children: [
                    for (final m in const [
                      ['system', 'System', 'Colors from your system theme'],
                      ['accent', 'Accent', 'Pick your own seed color'],
                      ['art', 'Now playing', 'Dominant color of the album art'],
                    ])
                      RadioListTile<String>(
                        secondary: Icon(m[0] == 'system'
                            ? Icons.brightness_auto
                            : m[0] == 'accent'
                                ? Icons.palette_outlined
                                : Icons.disc_full_rounded),
                        title: Text(m[1]),
                        subtitle: Text(m[2]),
                        value: m[0],
                        groupValue: theme.themeSource,
                        onChanged: (v) => theme.setThemeSource(v!),
                      ),
                    if (theme.themeSource == 'accent')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accent Color',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
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
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SettingsSection(
                title: 'Font',
                children: [
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) => ListTile(
                      leading: const Icon(Icons.font_download_outlined),
                      title: const Text('Font Family'),
                      trailing: DropdownButton<String>(
                        value: settings.fontFamily,
                        items: [
                          for (final font in _popularFonts)
                            DropdownMenuItem(value: font, child: Text(font)),
                        ],
                        onChanged: (value) {
                          if (value != null) settings.setFontFamily(value);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Consumer<SettingsProvider>(
                      builder: (context, settings, child) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: EShape.radius(EShape.md),
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
                      ),
                    ),
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

  static const _popularFonts = [
    'System',
    'Google Sans Flex',
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

  void _showColorPicker(BuildContext context, ThemeProvider theme) {
    Color pickerColor = theme.accentColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              'Pick a color',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
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

