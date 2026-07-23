import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../services/custom_equalizer.dart';
import '../theme/radii.dart';

class EqualizerWidget extends StatelessWidget {
  const EqualizerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Consumer<AudioProvider>(
              builder: (context, audio, child) {
                final on = audio.equalizerEnabled;
                return Material(
                  color: on
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(rLg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(rLg),
                    onTap: () => audio.setEqualizerEnabled(!on),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded,
                              size: 28,
                              color: on
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Equalizer',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: on
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurface,
                                      ),
                                ),
                                Text(
                                  on ? 'On' : 'Off',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: on
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: on,
                            onChanged: audio.setEqualizerEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildEqualizer(context),
                  const SizedBox(height: 28),
                  _buildVolumeControl(context),
                  const SizedBox(height: 28),
                  _buildPresets(context),
                  const SizedBox(height: 28),
                  _buildAudioEffects(context),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
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
            : [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
                .take(10)
                .toList();
        final freqLabels = frequencies.map((freq) {
          if (freq >= 1000) {
            return '${(freq / 1000).toStringAsFixed(0)}k';
          }
          return freq.toString();
        }).toList();

        return Consumer<AudioProvider>(
          builder: (context, audio, child) {
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Bands'),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;
                      final sliderHeight = isCompact ? 140.0 : 180.0;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(10, (index) {
                          final value = index < audio.equalizerBands.length
                              ? audio.equalizerBands[index]
                              : 0.0;

                          return Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: sliderHeight,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(rMd),
                                  ),
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                                enabledThumbRadius: 7),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 14),
                                        inactiveTrackColor:
                                            scheme.surfaceContainerHighest,
                                      ),
                                      child: Slider(
                                        value: value,
                                        min: -12,
                                        max: 12,
                                        divisions: 24,
                                        label:
                                            '${value.toStringAsFixed(1)} dB',
                                        onChanged: audio.equalizerEnabled
                                            ? (bandValue) =>
                                                audio.setEqualizerBand(
                                                    index, bandValue)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  freqLabels[index],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+12 dB',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      FilledButton.tonal(
                        onPressed: audio.equalizerEnabled
                            ? audio.resetEqualizer
                            : null,
                        child: const Text('Reset'),
                      ),
                      Text(
                        '-12 dB',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Consumer<AudioProvider>(
        builder: (context, audio, child) {
          final percent = (audio.masterVolume * 100).clamp(0, 100).round();

          return _buildSliderTile(
            context,
            icon: Icons.volume_up_rounded,
            label: 'Master volume',
            value: audio.masterVolume,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            valueLabel: '$percent%',
            onChanged: audio.setMasterVolume,
            resetAction:
                percent == 100 ? null : () => audio.setMasterVolume(1.0),
          );
        },
      ),
    );
  }

  Widget _buildPresets(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        return FutureBuilder<List<String>>(
          future: CustomEqualizer.getPresetNames(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final presets = snapshot.data!;
            final scheme = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Presets'),
                  if (!audio.equalizerEnabled) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Enable the equalizer to apply presets',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      // native preset names drag junk bytes along
                      final label = preset
                          .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
                          .trim();
                      final selected = audio.activePreset == preset;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        showCheckmark: false,
                        backgroundColor: scheme.surfaceContainerHigh,
                        selectedColor: scheme.primaryContainer,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : audio.equalizerEnabled
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                        ),
                        onSelected: audio.equalizerEnabled
                            ? (_) => audio.applyEqualizerPreset(preset)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioEffects(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Audio effects'),
          const SizedBox(height: 12),
          Consumer<AudioProvider>(
            builder: (context, audio, child) {
              return Column(
                children: [
                  _buildSliderTile(
                    context,
                    icon: Icons.graphic_eq_rounded,
                    label: 'Bass boost',
                    value: audio.bassBoost,
                    onChanged: audio.setBassBoost,
                    resetAction: () => audio.setBassBoost(0.0),
                  ),
                  _buildSliderTile(
                    context,
                    icon: Icons.music_note_rounded,
                    label: 'Treble boost',
                    value: audio.trebleBoost,
                    onChanged: audio.setTrebleBoost,
                    resetAction: () => audio.setTrebleBoost(0.0),
                  ),
                  _buildSliderTile(
                    context,
                    icon: Icons.waves_rounded,
                    label: 'Reverb',
                    value: audio.reverbLevel,
                    onChanged: audio.setReverbLevel,
                    resetAction: () => audio.setReverbLevel(0.0),
                  ),
                  _buildSliderTile(
                    context,
                    icon: Icons.speed_rounded,
                    label: 'Tempo',
                    value: audio.tempoControl,
                    min: 0.5,
                    max: 2.0,
                    onChanged: audio.setTempoControl,
                    resetAction: () => audio.setTempoControl(1.0),
                    valueLabel: '${(audio.tempoControl * 100).toInt()}%',
                  ),
                ],
              );
            },
          ),
        ],
      ),
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
                  color:
                      enabled ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
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
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              inactiveTrackColor: scheme.surfaceContainerHighest,
            ),
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
