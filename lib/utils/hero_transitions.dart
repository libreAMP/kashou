import 'package:flutter/material.dart';

RectTween albumArtRectTween(Rect? begin, Rect? end) {
  return MaterialRectArcTween(begin: begin, end: end);
}

Widget albumArtFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final targetWidget = flightDirection == HeroFlightDirection.push
      ? toHeroContext.widget
      : fromHeroContext.widget;

  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.easeInOut,
  );

  return AnimatedBuilder(
    animation: curvedAnimation,
    child: targetWidget,
    builder: (context, child) {
      final scale = 0.96 + (curvedAnimation.value * 0.04);
      return Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: child,
      );
    },
  );
}
