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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
        final frequencies = deviceFreqs.length >= 10 ? deviceFreqs.take(10).toList() : 
          [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000].take(10).toList();
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(10, (index) {
                      return Expanded(
                        child: Column(
                          children: [
                            RotatedBox(
                              quarterTurns: 3,
                              child: SizedBox(
                                height: 120,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                      pressedElevation: 4,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                    activeTrackColor: Theme.of(context).colorScheme.primary,
                                    inactiveTrackColor: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                    thumbColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Slider(
                                      value: index < audio.equalizerBands.length ? audio.equalizerBands[index] : 0.0,
                                      min: -12,
                                      max: 12,
                                      divisions: 24,
                                      onChanged: audio.equalizerEnabled
                                          ? (value) => audio.setEqualizerBand(index, value)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              freqLabels[index],
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+12 dB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: audio.equalizerEnabled ? audio.resetEqualizer : null,
                        child: const Text('Reset'),
                      ),
                      Text(
                        '-12 dB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.library_music,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Presets',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      final cleanPreset = preset.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
                      return FilterChip(
                        label: Text(cleanPreset),
                        selected: false,
                        onSelected: audio.equalizerEnabled ? (selected) async {
                          try {
                            await CustomEqualizer.setPreset(preset);
                            audio.resetEqualizer();
                          } catch (e) {
                          }
                        } : null,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
    String? valueLabel,
    VoidCallback? resetAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (resetAction != null)
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: resetAction,
                      tooltip: 'Reset',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  Text(
                    valueLabel ?? value.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              thumbColor: Theme.of(context).colorScheme.primary,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
