import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../services/custom_equalizer.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import 'eq_band.dart';
import 'morph_shape.dart';
import 'settings_tiles.dart';

const _presetIcons = {
  'normal': Icons.tune_rounded,
  'classical': Icons.piano_rounded,
  'dance': Icons.nightlife_rounded,
  'flat': Icons.horizontal_rule_rounded,
  'folk': Icons.park_rounded,
  'heavy metal': Icons.bolt_rounded,
  'hip hop': Icons.mic_rounded,
  'jazz': Icons.music_note_rounded,
  'pop': Icons.star_rounded,
  'rock': Icons.album_rounded,
};

const _defaultPresets = [
  'Normal',
  'Classical',
  'Dance',
  'Flat',
  'Folk',
  'Heavy Metal',
  'Hip Hop',
  'Jazz',
  'Pop',
  'Rock',
];

// native preset names drag junk bytes along
String _cleanPreset(String s) =>
    s.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

class EqualizerWidget extends StatelessWidget {
  const EqualizerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(rLg)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPresets(context),
                  const SizedBox(height: 24),
                  _buildEqualizer(context),
                  _buildVolumeControl(context),
                  _buildAudioEffects(context),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final on = audio.equalizerEnabled;
        final fg = on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
        final preset = audio.activePreset;
        return AnimatedContainer(
          duration: EMotion.medium,
          curve: EMotion.standard,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(rLg),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => audio.setEqualizerEnabled(!on),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      MorphShape(
                        from: MaterialShapes.square,
                        to: MaterialShapes.sunny,
                        morphed: on,
                        spin: on,
                        size: 48,
                        color: on
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 28,
                          color:
                              on ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equalizer',
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: on
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurface,
                              ),
                            ),
                            Text(
                              !on
                                  ? 'Off'
                                  : preset == null
                                      ? 'On'
                                      : 'On · ${_cleanPreset(preset)}',
                              style: text.bodySmall?.copyWith(color: fg),
                            ),
                          ],
                        ),
                      ),
                      Switch(value: on, onChanged: audio.setEqualizerEnabled),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 88,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: EqCurve(
                      bands: audio.equalizerBands, color: fg, enabled: on),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEqualizer(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: CustomEqualizer.getCenterBandFreqs(),
      builder: (context, snapshot) {
        final deviceFreqs = snapshot.data ?? [];
        final frequencies = deviceFreqs.length >= 10
            ? deviceFreqs.take(10).toList()
            : [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
        final labels = frequencies
            .map((f) => f >= 1000 ? '${(f / 1000).toStringAsFixed(0)}k' : '$f')
            .toList();

        return Consumer<AudioProvider>(
          builder: (context, audio, child) {
            final scheme = Theme.of(context).colorScheme;
            final small = Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _sectionTitle(context, 'Bands'),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: audio.equalizerEnabled
                            ? audio.resetEqualizer
                            : null,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 36, 8, 14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(rLg),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Divider(color: scheme.outlineVariant),
                              Row(
                                children: [
                                  for (var i = 0; i < 10; i++)
                                    Expanded(
                                      child: EqBand(
                                        label: labels[i],
                                        value: i < audio.equalizerBands.length
                                            ? audio.equalizerBands[i]
                                            : 0.0,
                                        onChanged: audio.equalizerEnabled
                                            ? (v) =>
                                                audio.setEqualizerBand(i, v)
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final l in labels)
                              Expanded(
                                  child: Center(child: Text(l, style: small))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVolumeControl(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final percent = (audio.masterVolume * 100).clamp(0, 100).round();
        return SettingsSection(
          title: 'Output',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: _buildSliderTile(
                context,
                icon: Icons.volume_up_rounded,
                label: 'Master volume',
                value: audio.masterVolume,
                divisions: 20,
                valueLabel: '$percent%',
                onChanged: audio.setMasterVolume,
                resetAction:
                    percent == 100 ? null : () => audio.setMasterVolume(1.0),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresets(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        return FutureBuilder<List<String>>(
          future: CustomEqualizer.getPresetNames(),
          builder: (context, snapshot) {
            final hardware = snapshot.data ?? const [];
            final presets = hardware.isNotEmpty ? hardware : _defaultPresets;
            final scheme = Theme.of(context).colorScheme;
            final on = audio.equalizerEnabled;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _sectionTitle(context, 'Presets'),
                ),
                if (!on)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                    child: Text(
                      'Turn the equalizer on to use presets',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final label = _cleanPreset(presets[i]);
                      final selected = audio.activePreset?.toLowerCase().trim() ==
                          presets[i].toLowerCase().trim();
                      final fg = selected
                          ? scheme.onPrimary
                          : on
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: on
                            ? () => audio.applyEqualizerPreset(presets[i])
                            : null,
                        child: SizedBox(
                          width: 88,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MorphShape(
                                from: MaterialShapes.square,
                                to: MaterialShapes.cookie9Sided,
                                morphed: selected,
                                size: 56,
                                color: selected
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                child: Icon(
                                  _presetIcons[label.toLowerCase()] ??
                                      Icons.graphic_eq_rounded,
                                  color: fg,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAudioEffects(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        Widget tile(Widget t) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: t,
            );
        return SettingsSection(
          title: 'Audio effects',
          children: [
            tile(_buildSliderTile(
              context,
              icon: Icons.graphic_eq_rounded,
              label: 'Bass boost',
              value: audio.bassBoost,
              divisions: 10,
              onChanged: audio.setBassBoost,
              resetAction: () => audio.setBassBoost(0.0),
            )),
            tile(_buildSliderTile(
              context,
              icon: Icons.music_note_rounded,
              label: 'Treble boost',
              value: audio.trebleBoost,
              divisions: 10,
              onChanged: audio.setTrebleBoost,
              resetAction: () => audio.setTrebleBoost(0.0),
            )),
            tile(_buildSliderTile(
              context,
              icon: Icons.waves_rounded,
              label: 'Reverb',
              value: audio.reverbLevel,
              divisions: 10,
              onChanged: audio.setReverbLevel,
              resetAction: () => audio.setReverbLevel(0.0),
            )),
            tile(_buildSliderTile(
              context,
              icon: Icons.speed_rounded,
              label: 'Tempo',
              value: audio.tempoControl,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: audio.setTempoControl,
              resetAction: () => audio.setTempoControl(1.0),
              valueLabel: '${(audio.tempoControl * 100).toInt()}%',
            )),
          ],
        );
      },
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
    String? valueLabel,
    VoidCallback? resetAction,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clampedValue = value.clamp(min, max).toDouble();
    final effectiveValueLabel = valueLabel ?? clampedValue.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                effectiveValueLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              if (resetAction != null)
                IconButton(
                  onPressed: enabled ? resetAction : null,
                  iconSize: 18,
                  icon: Icon(Icons.refresh_rounded,
                      color: scheme.onSurfaceVariant),
                  tooltip: 'Reset',
                ),
            ],
          ),
          SliderTheme(
            data: m3eSliderTheme(context),
            child: Slider(
              value: clampedValue,
              min: min,
              max: max,
              divisions: divisions,
              label: effectiveValueLabel,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
