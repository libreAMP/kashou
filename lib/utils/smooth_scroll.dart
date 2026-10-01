import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class KashouScrollBehavior extends MaterialScrollBehavior {
  const KashouScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
                PointerDeviceKind.mouse,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final scrollbar = super.buildScrollbar(context, child, details);
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DesktopSmoothScrollWrapper(
        controller: details.controller,
        direction: details.direction,
        child: scrollbar,
      );
    }
    return scrollbar;
  }
}

class DesktopSmoothScrollWrapper extends SingleChildRenderObjectWidget {
  const DesktopSmoothScrollWrapper({
    super.key,
    required super.child,
    required this.controller,
    required this.direction,
  });

  final ScrollController? controller;
  final AxisDirection direction;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDesktopSmoothScroll(
      controller: controller,
      direction: direction,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderDesktopSmoothScroll renderObject,
  ) {
    renderObject
      ..controller = controller
      ..direction = direction;
  }
}

class RenderDesktopSmoothScroll extends RenderProxyBox {
  RenderDesktopSmoothScroll({
    required ScrollController? controller,
    required AxisDirection direction,
  })  : _controller = controller,
        _direction = direction;

  ScrollController? _controller;
  AxisDirection _direction;

  double _targetOffset = 0.0;
  bool _isAnimating = false;

  // a wheel notch covers a fraction of a trackpad flick
  static const double _mouseWheelScale = 6.5;
  static const Duration _settle = Duration(milliseconds: 130);

  set controller(ScrollController? value) {
    if (_controller == value) return;
    _controller = value;
    _isAnimating = false;
  }

  set direction(AxisDirection value) {
    _direction = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;

    final c = _controller;
    if (c == null || !c.hasClients) {
      return hitTestChildren(result, position: position) ||
          hitTestSelf(position);
    }

    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _isAnimating = false;
    } else if (event is PointerScrollEvent) {
      final c = _controller;
      if (c == null || !c.hasClients) return;

      final position = c.position;
      final isVertical =
          _direction == AxisDirection.down || _direction == AxisDirection.up;
      final rawDelta = isVertical ? event.scrollDelta.dy : event.scrollDelta.dx;
      final reversed =
          _direction == AxisDirection.up || _direction == AxisDirection.left;
      var delta = reversed ? -rawDelta : rawDelta;
      if (event.kind == PointerDeviceKind.mouse) delta *= _mouseWheelScale;

      if (delta == 0.0) return;

      final minExt = position.minScrollExtent;
      final maxExt = position.maxScrollExtent;
      final currentPixels = c.offset;

      if (delta < 0 && currentPixels <= minExt) return;
      if (delta > 0 && currentPixels >= maxExt) return;

      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        if (!c.hasClients) return;

        if (event.kind == PointerDeviceKind.trackpad) {
          _isAnimating = false;
          c.jumpTo((c.offset + delta).clamp(minExt, maxExt));
          return;
        }

        // held wheel retargets instead of restarting
        final base = _isAnimating ? _targetOffset : c.offset;
        final next = (base + delta).clamp(minExt, maxExt);
        _targetOffset = next;
        _isAnimating = true;
        c
            .animateTo(next, duration: _settle, curve: Curves.easeOutQuad)
            .whenComplete(() => _isAnimating = false);
      });
    }
    super.handleEvent(event, entry);
  }
}
