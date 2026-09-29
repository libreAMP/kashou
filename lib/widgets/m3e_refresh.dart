import 'dart:math' as math;

import 'package:flutter/material.dart';

class M3ERefresh extends StatefulWidget {
  const M3ERefresh({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.controller,
    this.physics,
    this.padding,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  State<M3ERefresh> createState() => _M3ERefreshState();
}

class _M3ERefreshState extends State<M3ERefresh>
    with SingleTickerProviderStateMixin {
  static const _trigger = 64.0;
  static const _maxPull = 150.0;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _pull = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double _offset = 0;
  bool _busy = false;

  @override
  void dispose() {
    _spin.dispose();
    _pull.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _offset = _maxPull;
    });
    await _pull.forward();
    if (!mounted) return;
    _spin.repeat();
    await widget.onRefresh();
    if (!mounted) return;
    _spin.stop();
    _spin.value = 0;
    setState(() {
      _busy = false;
      _offset = 0;
    });
    _pull.reverse();
  }

  bool _onNotification(ScrollNotification n) {
    if (_busy) return false;
    if (n is OverscrollNotification) {
      _offset = (_offset + n.overscroll * 0.6).clamp(0.0, _maxPull);
      _pull.value = (_offset / _maxPull).clamp(0.0, 1.0);
      return true;
    }
    if (n is ScrollEndNotification && _offset > 0) {
      if (_offset >= _trigger) {
        _run();
      } else {
        setState(() => _offset = 0);
        _pull.reverse();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: CustomScrollView(
            controller: widget.controller,
            physics: widget.physics ??
                const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
            slivers: [
              if (widget.padding != null)
                SliverPadding(padding: widget.padding!, sliver: _body)
              else
                _body,
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pull, _spin]),
              builder: (context, _) {
                final t = _pull.value;
                if (t < 0.01) return const SizedBox.shrink();
                return Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 14 + t * 8),
                    child: CustomPaint(
                      size: const Size.square(28),
                      painter: _RingPainter(
                        progress: t,
                        angle: _spin.value * 2 * math.pi,
                        spinning: _busy,
                        color: scheme.primary,
                        track: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget get _body => SliverList(
        delegate: SliverChildListDelegate(widget.slivers),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double angle;
  final bool spinning;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.angle,
    required this.spinning,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 2;

    final dot = Paint()..color = color;
    if (!spinning) {
      canvas.drawCircle(center, r * 0.35 * progress, dot);
      if (progress < 0.2) return;
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, r, ring);

    final lead = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = spinning ? 0.45 * math.pi : progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      spinning ? angle : -math.pi / 2,
      sweep,
      false,
      lead,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.angle != angle ||
      old.spinning != spinning;
}
