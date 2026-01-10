import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../services/custom_equalizer.dart';

class EqualizerWidget extends StatelessWidget {
  const EqualizerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.equalizer,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Equalizer',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                    ),
                  ],
                ),
                Consumer<AudioProvider>(
                  builder: (context, audio, child) {
                    return Switch(
                      value: audio.equalizerEnabled,
                      onChanged: audio.setEqualizerEnabled,
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildEqualizer(context),
                  const SizedBox(height: 32),
                  _buildVolumeControl(context),
                  const SizedBox(height: 32),
                  _buildPresets(context),
                  const SizedBox(height: 32),
                  _buildAudioEffects(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizer(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: CustomEqualizer.getCenterBandFreqs(),
      builder: (context, snapshot) {
        final deviceFreqs = snapshot.data ?? [];
        // Default to 10 bands if device has less or none
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.surround_sound,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bands',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;
                      final sliderHeight = isCompact ? 140.0 : 180.0;
                      final trackWidth = isCompact ? 3.0 : 4.0;

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
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.08),
                                        Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.25),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: trackWidth,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: isCompact ? 6 : 7,
                                          pressedElevation: 4,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 16),
                                        activeTrackColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        inactiveTrackColor: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.4),
                                        thumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      child: Slider(
                                        value: value,
                                        min: -12,
                                        max: 12,
                                        divisions: 24,
                                        label: '${value.toStringAsFixed(1)} dB',
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+12 dB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      FilledButton.tonal(
                        onPressed: audio.equalizerEnabled
                            ? audio.resetEqualizer
                            : null,
                        child: const Text('Reset'),
                      ),
                      Text(
                        '-12 dB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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

          return _buildMaterialSliderTile(
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
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    collapsedIconColor: colorScheme.onSurfaceVariant,
                    iconColor: colorScheme.primary,
                    title: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withOpacity(0.12),
                          ),
                          child: Icon(
                            Icons.library_music,
                            size: 22,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Presets',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (audio.equalizerEnabled)
                                Text(
                                  '${presets.length} available',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (!audio.equalizerEnabled)
                                Text(
                                  'Enable the equalizer to apply presets',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((preset) {
                          return FilterChip(
                            label: Text(preset),
                            selected: false,
                            onSelected: audio.equalizerEnabled
                                ? (selected) async {
                                    if (selected) {
                                      await audio.applyEqualizerPreset(preset);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Applied preset: $preset'),
                                            duration:
                                                const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
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
          Row(
            children: [
              Icon(
                Icons.tune,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Audio Effects',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<AudioProvider>(
            builder: (context, audio, child) {
              return Column(
                children: [
                  _buildEffectSlider(
                    context,
                    icon: Icons.volume_up,
                    label: 'Bass Boost',
                    value: audio.bassBoost,
                    onChanged: audio.setBassBoost,
                    resetAction: () => audio.setBassBoost(0.0),
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    icon: Icons.volume_down,
                    label: 'Treble Boost',
                    value: audio.trebleBoost,
                    onChanged: audio.setTrebleBoost,
                    resetAction: () => audio.setTrebleBoost(0.0),
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    icon: Icons.replay,
                    label: 'Reverb',
                    value: audio.reverbLevel,
                    onChanged: audio.setReverbLevel,
                    resetAction: () => audio.setReverbLevel(0.0),
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    icon: Icons.speed,
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

  Widget _buildEffectSlider(
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
    return _buildMaterialSliderTile(
      context,
      icon: icon,
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      valueLabel: valueLabel,
      onChanged: onChanged,
      resetAction: resetAction,
      enabled: enabled,
    );
  }

  Widget _buildMaterialSliderTile(
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
    final clampedValue = value.clamp(min, max).toDouble();
    final showReset = resetAction != null;
    final effectiveValueLabel = valueLabel ?? clampedValue.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withOpacity(enabled ? 0.15 : 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withOpacity(enabled ? 1 : 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  effectiveValueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (showReset)
                IconButton(
                  onPressed: enabled ? resetAction : null,
                  icon: Icon(
                    Icons.refresh,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Reset',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  theme.colorScheme.surfaceVariant.withOpacity(0.5),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withOpacity(0.12),
              valueIndicatorColor: theme.colorScheme.primaryContainer,
              valueIndicatorTextStyle: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
              showValueIndicator: ShowValueIndicator.always,
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
