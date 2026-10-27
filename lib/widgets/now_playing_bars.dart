import 'dart:math' as math;

import 'package:flutter/material.dart';

class NowPlayingBars extends StatefulWidget {
  const NowPlayingBars({
    super.key,
    this.playing = true,
    this.color,
    this.size = 18,
  });

  final bool playing;
  final Color? color;
  final double size;

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(NowPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final size = Size.square(widget.size);
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      return CustomPaint(
        size: size,
        painter: _BarsPainter(0, color, playing: false),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: size,
        painter: _BarsPainter(
          _controller.value,
          color,
          playing: widget.playing,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.t, this.color, {required this.playing});

  final double t;
  final Color color;
  final bool playing;

  static const _levels = [0.45, 0.9, 0.6];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width * 0.16;
    final gap = (size.width - barWidth * 3) / 2;
    for (var i = 0; i < 3; i++) {
      final wave =
          playing ? 0.5 + 0.5 * math.sin((t + i * 0.16) * math.pi * 2) : 0.0;
      final level = (playing ? _levels[i] * (0.55 + 0.7 * wave) : _levels[i])
          .clamp(0.18, 1.0);
      final height = size.height * level;
      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, (size.height - height) / 2, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.color != color || old.playing != playing;
}
