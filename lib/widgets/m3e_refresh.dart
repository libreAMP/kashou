import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'loading_indicator.dart';

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

class _M3ERefreshState extends State<M3ERefresh> {
  static const _trigger = 72.0;

  double _offset = 0;
  bool _busy = false;
  bool _armed = false;
  bool _dragging = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _armed = false;
      _dragging = false;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _offset = 0;
        });
      }
    }
  }

  bool _onNotification(ScrollNotification n) {
    if (_busy) return false;

    if (n is ScrollStartNotification) {
      if (n.dragDetails != null) _dragging = true;
    }

    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) _dragging = true;
    }

    if (n.metrics.axisDirection == AxisDirection.down) {
      if (n.metrics.pixels < 0) {
        _offset = -n.metrics.pixels;
      } else if (n is OverscrollNotification && n.overscroll < 0) {
        _offset = (_offset - n.overscroll).clamp(0.0, 150.0);
      } else if (n.metrics.pixels == 0 &&
          n is ScrollUpdateNotification &&
          n.dragDetails == null) {
        _offset = 0;
      }
    }

    if (_dragging && _offset >= _trigger) {
      _armed = true;
    }

    final isRelease = (n is ScrollUpdateNotification && n.dragDetails == null) ||
        n is ScrollEndNotification ||
        (n is UserScrollNotification && n.direction == ScrollDirection.idle);

    if (isRelease) {
      if (_dragging) _dragging = false;
      if (_armed) {
        _run();
      } else if (_offset > 0 && n is ScrollEndNotification) {
        setState(() => _offset = 0);
      }
    } else {
      setState(() {});
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (_offset / _trigger).clamp(0.0, 1.0);
    final visible = _busy || progress > 0.05;

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
        if (visible)
          Positioned(
            top: _busy ? 16 : (10 + progress * 16),
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: (_busy || progress > 0.2) ? 1.0 : progress * 5,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    scale:
                        _busy ? 1.0 : (0.5 + 0.5 * progress).clamp(0.0, 1.0),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const KashouLoader(size: 26),
                    ),
                  ),
                ),
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
