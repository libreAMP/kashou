import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _pad = 14.0;

class EqBand extends StatefulWidget {
  const EqBand({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.max = 12,
  });

  final double value;
  final String label;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  State<EqBand> createState() => _EqBandState();
}

class _EqBandState extends State<EqBand> {
  bool _drag = false;

  double _y(double h, double v) => h / 2 - v / widget.max * (h / 2 - _pad);

  void _set(double dy, double h) {
    final v = ((h / 2 - dy) / (h / 2 - _pad) * widget.max)
        .roundToDouble()
        .clamp(-widget.max, widget.max)
        .toDouble();
    if (v != widget.value) widget.onChanged!(v);
  }

  void _step(double by) => widget.onChanged!(
      (widget.value + by).clamp(-widget.max, widget.max).toDouble());

  void _end() => setState(() => _drag = false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = widget.onChanged != null;
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final v = widget.value;
        return Semantics(
          slider: true,
          enabled: on,
          label: widget.label,
          value: '${v.round()} dB',
          increasedValue: '${(v + 1).round()} dB',
          decreasedValue: '${(v - 1).round()} dB',
          onIncrease: on ? () => _step(1) : null,
          onDecrease: on ? () => _step(-1) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: on ? (d) => _set(d.localPosition.dy, h) : null,
            onVerticalDragStart:
                on ? (_) => setState(() => _drag = true) : null,
            onVerticalDragUpdate:
                on ? (d) => _set(d.localPosition.dy, h) : null,
            onVerticalDragEnd: on ? (_) => _end() : null,
            onVerticalDragCancel: on ? _end : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _drag ? 1 : 0),
                    duration: EMotion.fast,
                    curve: EMotion.emphasized,
                    builder: (context, grow, _) =>
                        TweenAnimationBuilder<double>(
                      tween: Tween(end: v),
                      duration: _drag ? Duration.zero : EMotion.medium,
                      curve: EMotion.standard,
                      builder: (context, shown, _) => CustomPaint(
                        painter: _BandPainter(
                          value: shown,
                          max: widget.max,
                          grow: grow,
                          scheme: scheme,
                          enabled: on,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_drag)
                  Positioned(
                    left: -8,
                    right: -8,
                    top: _y(h, v) - 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${v > 0 ? '+' : ''}${v.round()}',
                          style: text.labelMedium?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.value,
    required this.max,
    required this.grow,
    required this.scheme,
    required this.enabled,
  });

  final double value;
  final double max;
  final double grow;
  final ColorScheme scheme;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = 24 + 10 * grow;
    final mid = size.height / 2;
    final y = mid - value / max * (mid - _pad);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width / 2, mid), width: w, height: size.height),
      Radius.circular(w / 2),
    );
    canvas.drawRRect(pill, Paint()..color = scheme.surfaceContainerHighest);

    final up = value >= 0;
    final fill = enabled
        ? (up ? scheme.primary : scheme.secondary)
        : scheme.onSurface.withValues(alpha: 0.18);
    canvas.save();
    canvas.clipRRect(pill);
    canvas.drawRect(
      Rect.fromLTRB(pill.left, up ? y : mid, pill.right, up ? mid : y),
      Paint()..color = fill,
    );
    canvas.restore();

    if (enabled) {
      final flat = value.abs() <= 0.5;
      final tip = flat ? mid : (up ? y + 9 : y - 9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width / 2, tip),
              width: flat ? w * 0.7 : w * 0.5,
              height: flat ? 6 : 4),
          const Radius.circular(3),
        ),
        Paint()
          ..color = flat
              ? scheme.primary
              : (up ? scheme.onPrimary : scheme.onSecondary),
      );
    }
  }

  @override
  bool shouldRepaint(_BandPainter o) =>
      o.value != value ||
      o.grow != grow ||
      o.enabled != enabled ||
      o.scheme != scheme;
}

class _ListTween extends Tween<List<double>> {
  _ListTween({super.end});

  @override
  List<double> lerp(double t) => [
        for (var i = 0; i < end!.length; i++)
          lerpDouble(begin == null || i >= begin!.length ? end![i] : begin![i],
              end![i], t)!,
      ];
}

class EqCurve extends StatelessWidget {
  const EqCurve({
    super.key,
    required this.bands,
    required this.color,
    this.enabled = true,
    this.max = 12,
  });

  final List<double> bands;
  final Color color;
  final bool enabled;
  final double max;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<List<double>>(
      tween: _ListTween(end: bands),
      duration: EMotion.medium,
      curve: EMotion.standard,
      builder: (context, shown, _) => CustomPaint(
        size: Size.infinite,
        painter: _CurvePainter(
          bands: shown,
          max: max,
          color: enabled ? color : color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.bands, required this.max, required this.color});

  final List<double> bands;
  final double max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;
    final mid = size.height / 2;
    final step = size.width / bands.length;
    final pts = [
      for (var i = 0; i < bands.length; i++)
        Offset(step * (i + 0.5), mid - bands[i] / max * (mid - 6)),
    ];

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );

    final line = Path()
      ..moveTo(0, pts.first.dy)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    line.lineTo(size.width, pts.last.dy);

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter o) =>
      o.color != color || o.max != max || o.bands != bands;
}
