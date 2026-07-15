import 'dart:math';

import 'package:flutter/material.dart';

// wave collapses flat while paused or scrubbing
class SquigglySlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final bool animate;

  const SquigglySlider({
    super.key,
    required this.value,
    required this.max,
    this.onChanged,
    this.animate = false,
  });

  @override
  State<SquigglySlider> createState() => _SquigglySliderState();
}

class _SquigglySliderState extends State<SquigglySlider>
    with TickerProviderStateMixin {
  late final AnimationController _phase;
  late final AnimationController _amplitude;
  double? _dragValue;

  bool get _wavy => widget.animate && _dragValue == null;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _amplitude = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.animate ? 1 : 0,
    );
    _sync();
  }

  void _sync() {
    if (_wavy) {
      if (!_phase.isAnimating) _phase.repeat();
      _amplitude.forward();
    } else {
      _amplitude.reverse().whenComplete(() {
        if (!_wavy && _phase.isAnimating) _phase.stop();
      });
    }
  }

  @override
  void didUpdateWidget(SquigglySlider old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _phase.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  void _seekTo(Offset local, double width) {
    if (widget.onChanged == null) return;
    final f = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = f * widget.max);
    _sync();
  }

  void _commit() {
    if (_dragValue != null && widget.onChanged != null) {
      widget.onChanged!(_dragValue!);
    }
    setState(() => _dragValue = null);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = widget.max <= 0 ? 1.0 : widget.max;
    final value = (_dragValue ?? widget.value).clamp(0.0, max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _seekTo(d.localPosition, width),
          onHorizontalDragEnd: (_) => _commit(),
          onTapDown: (d) => _seekTo(d.localPosition, width),
          onTapUp: (_) => _commit(),
          child: RepaintBoundary(
            child: SizedBox(
              height: 44,
              child: AnimatedBuilder(
                animation: Listenable.merge([_phase, _amplitude]),
                builder: (context, _) => CustomPaint(
                  size: Size(width, 44),
                  painter: _SquigglyPainter(
                    fraction: value / max,
                    phase: _phase.value * 2 * pi,
                    amplitude: Curves.easeInOut.transform(_amplitude.value),
                    waveColor: scheme.primary,
                    trackColor: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SquigglyPainter extends CustomPainter {
  final double fraction;
  final double phase;
  final double amplitude;
  final Color waveColor;
  final Color trackColor;

  static const _maxAmplitude = 5.0;
  static const _wavelength = 42.0;
  static const _stroke = 4.6;
  static const _handleGap = 8.0;

  _SquigglyPainter({
    required this.fraction,
    required this.phase,
    required this.amplitude,
    required this.waveColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final splitX = size.width * fraction;

    final wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final playedEnd = splitX - _handleGap;
    if (playedEnd > 0) {
      if (amplitude < 0.02) {
        canvas.drawLine(Offset(0, midY), Offset(playedEnd, midY), wavePaint);
      } else {
        final path = Path()..moveTo(0, midY);
        for (double x = 0; x <= playedEnd; x += 2) {
          // wave grows in from the left edge and settles flat at the handle
          final edgeIn = (x / _wavelength).clamp(0.0, 1.0);
          final settle = ((playedEnd - x) / _wavelength).clamp(0.0, 1.0);
          final y = midY +
              sin(x / _wavelength * 2 * pi - phase) *
                  _maxAmplitude *
                  amplitude *
                  edgeIn *
                  settle;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, wavePaint);
      }
    }

    final remainStart = splitX + _handleGap;
    if (remainStart < size.width - 4) {
      canvas.drawLine(
        Offset(remainStart, midY),
        Offset(size.width - 4, midY),
        Paint()
          ..color = trackColor
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
        Offset(size.width - 2, midY), 2.4, Paint()..color = trackColor);

    final handle = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(splitX, midY), width: 5, height: 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(handle, Paint()..color = waveColor);
  }

  @override
  bool shouldRepaint(_SquigglyPainter old) =>
      old.fraction != fraction ||
      old.phase != phase ||
      old.amplitude != amplitude;
}
