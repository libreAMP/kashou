import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';

class EqualizerWidget extends StatelessWidget {
  const EqualizerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Equalizer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Consumer<AudioProvider>(
                  builder: (context, audio, child) {
                    return Switch(
                      value: audio.equalizerEnabled,
                      onChanged: audio.setEqualizerEnabled,
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
                  const SizedBox(height: 24),
                  _buildPresets(context),
                  const SizedBox(height: 24),
                  _buildAudioEffects(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizer(BuildContext context) {
    final frequencies = [
      '31',
      '62',
      '125',
      '250',
      '500',
      '1k',
      '2k',
      '4k',
      '8k',
      '16k',
    ];

    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
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
                            height: 40,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                              ),
                              child: Slider(
                                value: audio.equalizerBands[index],
                                min: -12,
                                max: 12,
                                onChanged: audio.equalizerEnabled
                                    ? (value) =>
                                          audio.setEqualizerBand(index, value)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          frequencies[index],
                          style: Theme.of(context).textTheme.bodySmall,
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
                    '+12dB',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: audio.equalizerEnabled
                        ? audio.resetEqualizer
                        : null,
                    child: const Text('Reset'),
                  ),
                  Text(
                    '-12dB',
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
  }

  Widget _buildPresets(BuildContext context) {
    final presets = [
      'Flat',
      'Rock',
      'Pop',
      'Jazz',
      'Classical',
      'Electronic',
      'Hip Hop',
      'Acoustic',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Presets',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(presets[index]),
                  selected: false,
                  onSelected: (selected) {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudioEffects(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Effects',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Consumer<AudioProvider>(
            builder: (context, audio, child) {
              return Column(
                children: [
                  _buildEffectSlider(
                    context,
                    label: 'Bass Boost',
                    value: audio.bassBoost,
                    onChanged: audio.setBassBoost,
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    label: 'Treble Boost',
                    value: audio.trebleBoost,
                    onChanged: audio.setTrebleBoost,
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    label: 'Reverb',
                    value: audio.reverbLevel,
                    onChanged: audio.setReverbLevel,
                  ),
                  const SizedBox(height: 16),
                  _buildEffectSlider(
                    context,
                    label: 'Tempo',
                    value: audio.tempoControl,
                    min: 0.5,
                    max: 2.0,
                    onChanged: audio.setTempoControl,
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
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
    String? valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              valueLabel ?? value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
